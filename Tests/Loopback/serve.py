#!/usr/bin/env python3
"""Deterministic, loopback-only HTTP fixture for the iOS M2 XCTest branches."""

from argparse import ArgumentParser
from collections import Counter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import re
import socket
from threading import Event, Lock
from urllib.parse import parse_qs, urlsplit


MEDIA = bytes(range(256)) * (3 * 4096)
TITLE = "受控回环书"
AUTHOR = "测试作者"
CHAPTERS = ("第一章", "第二章", "第三章", "第四章")
CONTENTS = (
    "墨纸青松，受控回环正文。中文𠀀与Café都在这一段，供阅读位置及换源核验。"
    "这一段是固定输入，用来核验多层书源检测、真实正文处理、本地缓存读回及不同版本之间的阅读位置。",
    "第二章回环正文，章节下载完成后应当可从 Core 本地缓存逐字读取。",
    "第三章回环正文，仅在启用网络时由受控服务器返回。",
    "第四章回环正文，用于核验独立进程恢复原下载操作。",
    "第五章回环正文，用于核验保留旧目录坐标的尾部更新。",
)


class Fixture:
    def __init__(self):
        self.lock = Lock()
        self.counters = Counter()
        self.modes = {}
        self.gates = {}
        self.failures = []

    def arrive(self, path, default="ok"):
        with self.lock:
            self.counters[path] += 1
            mode = self.modes.get(path, default)
            if mode == "hold":
                gate = self.gates.setdefault(path, Event())
            else:
                gate = None
            return mode, gate

    def configure(self, path, mode):
        with self.lock:
            if old := self.gates.pop(path, None):
                old.set()
            self.modes[path] = mode
            if mode == "hold":
                self.gates[path] = Event()

    def release(self, path):
        with self.lock:
            self.modes[path] = "ok"
            if gate := self.gates.pop(path, None):
                gate.set()

    def record_failure(self, message):
        with self.lock:
            self.failures.append(message)

    def state(self):
        with self.lock:
            return {
                "counters": dict(self.counters),
                "holds": sorted(self.gates),
                "failures": list(self.failures),
            }


def source_rules(base, name="M2 回环来源", group="M2", login=True):
    rules = {
        "bookSourceUrl": base,
        "bookSourceName": name,
        "bookSourceGroup": group,
        "bookSourceType": 0,
        "enabled": True,
        "searchUrl": base + "/search?q={{key}}",
        "ruleSearch": {
            "bookList": "ul.results li.book",
            "name": "span.name@text",
            "author": "span.author@text",
            "bookUrl": "a.detail@href",
        },
        "ruleBookInfo": {"name": "h1@text", "author": "p.author@text", "tocUrl": "a.toc@href"},
        "ruleToc": {"chapterList": "ol.toc li", "chapterName": "a@text", "chapterUrl": "a@href"},
        "ruleContent": {"content": "div.content@text"},
    }
    if login:
        rules["loginUrl"] = base + "/login"
    return rules


class Handler(BaseHTTPRequestHandler):
    server_version = "ReaderM2Fixture/1"

    def log_message(self, _, *_args):
        pass

    def do_GET(self):
        self.route()

    def do_POST(self):
        self.route()

    def reply(self, status, body, content_type="text/plain; charset=utf-8", **headers):
        raw = body.encode() if isinstance(body, str) else body
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(raw)))
        for key, value in headers.items():
            self.send_header(key.replace("_", "-"), str(value))
        self.end_headers()
        try:
            self.wfile.write(raw)
        except (BrokenPipeError, ConnectionResetError):
            # An explicit transport cancellation closes the held client socket.
            pass

    def json(self, payload):
        self.reply(200, json.dumps(payload, ensure_ascii=False), "application/json")

    def html(self, body):
        self.reply(200, "<!doctype html><meta charset=utf-8>" + body, "text/html; charset=utf-8")

    def route(self):
        url = urlsplit(self.path)
        path = url.path
        query = parse_qs(url.query, keep_blank_values=True)
        fixture = self.server.fixture
        if path.startswith("/control/"):
            self.control(path, query)
            return
        held = ("/host/hold", "/host/media-hold", "/host/document-hold", "/host/web-hold")
        default = "hold" if path in held else "ok"
        mode, gate = fixture.arrive(path, default)
        print(f"HTTP {self.command} {path} mode={mode}", flush=True)
        if gate is not None and not gate.wait(timeout=90):
            message = f"unreleased fixture gate: {path}"
            fixture.record_failure(message)
            self.reply(504, message)
            return
        if mode == "offline":
            self.reply(503, "intentional fixture outage")
            return
        if mode == "disconnect":
            self.close_connection = True
            self.connection.shutdown(socket.SHUT_RDWR)
            return
        if mode == "package2" and path.endswith("/package/1"):
            path = path[:-1] + "2"
        if path.startswith("/host/"):
            self.host(path, query)
            return
        if self.books(path, mode):
            return
        self.reply(404, "unknown fixture route")

    def control(self, path, query):
        fixture = self.server.fixture
        if path == "/control/state" and self.command == "GET":
            self.json(fixture.state())
            return
        target = query.get("path", [None])[0]
        if self.command != "POST" or not target or not target.startswith(("/host/", "/books/")):
            self.reply(400, "invalid fixture control")
            return
        if path == "/control/release":
            fixture.release(target)
        elif path == "/control/configure":
            mode = query.get("mode", [None])[0]
            if mode not in ("ok", "hold", "offline", "disconnect", "package2", "toc2", "tocRewrite"):
                self.reply(400, "invalid fixture mode")
                return
            fixture.configure(target, mode)
        else:
            self.reply(404, "unknown fixture control")
            return
        self.json(fixture.state())

    def host(self, path, query):
        if path == "/host/echo":
            size = int(self.headers.get("Content-Length", "0"))
            encoded = self.rfile.read(min(size, 64))
            cookie = self.headers.get("Cookie", "")
            if self.command != "POST" or size != 4 or encoded != bytes.fromhex("d6d0cec4"):
                self.server.fixture.record_failure("POST GBK wire bytes disagreed")
                self.reply(422, "incorrect Core GBK bytes")
                return
            print(f"HTTP GBK {encoded.hex()} cookiePresent={bool(cookie)}", flush=True)
            self.reply(200, "ACK " + encoded.decode("gbk"), X_Reader_Request_Cookie=cookie)
        elif path == "/host/unavailable":
            self.reply(503, "intentional fixture outage")
        elif path == "/host/hold":
            self.reply(200, "released")
        elif path in ("/host/document", "/host/document-hold", "/host/web-hold"):
            self.html("<title>M2 loopback document</title><p>Real WebKit loopback fixture.</p>")
        elif path == "/host/redirect":
            self.reply(302, "", Location="/host/document")
        elif path == "/host/cookie":
            headers = {}
            if value := query.get("set", [""])[0]:
                if not re.fullmatch(r"[A-Za-z0-9_=-]{1,100}", value):
                    self.reply(400, "invalid fixture cookie")
                    return
                headers["Set_Cookie"] = value + "; Path=/; Max-Age=3600"
            self.reply(200, self.headers.get("Cookie", ""), **headers)
        elif path in ("/host/media", "/host/media-hold"):
            match = re.fullmatch(r"bytes=(\d+)-(\d*)", self.headers.get("Range", ""))
            if match:
                start = int(match[1])
                end = min(int(match[2]), len(MEDIA) - 1) if match[2] else len(MEDIA) - 1
                if start > end:
                    self.reply(416, "", Content_Range=f"bytes */{len(MEDIA)}")
                else:
                    print(f"HTTP MEDIA bytes={start}-{end}/{len(MEDIA)}", flush=True)
                    self.reply(206, MEDIA[start:end + 1], "application/octet-stream",
                               Content_Range=f"bytes {start}-{end}/{len(MEDIA)}", Accept_Ranges="bytes")
            elif self.headers.get("Range"):
                self.reply(416, "", Content_Range=f"bytes */{len(MEDIA)}")
            else:
                self.reply(200, MEDIA, "application/octet-stream", Accept_Ranges="bytes")
        else:
            self.reply(404, "unknown Host fixture route")

    def books(self, path, mode):
        match = re.fullmatch(r"/books/([a-z]+)/([a-z]+)/(search|detail|toc|chapter/[1-5]|login|rules|import|package/[12])", path)
        if not match:
            return False
        suite, edition, route = match.groups()
        root = f"/books/{suite}/{edition}"
        if route == "search":
            self.html(f'<ul class="results"><li class="book"><span class="name">{TITLE}</span>'
                      f'<span class="author">{AUTHOR}</span><a class="detail" href="{root}/detail">详情</a></li></ul>')
        elif route == "detail":
            self.html(f'<h1>{TITLE}</h1><p class="author">{AUTHOR}</p><a class="toc" href="{root}/toc">目录</a>')
        elif route == "toc":
            titles = CHAPTERS
            if mode == "toc2":
                titles = (*CHAPTERS, "第五章")
            elif mode == "tocRewrite":
                titles = (*CHAPTERS[:-1], "第四章（被改写）")
            entries = "".join(f'<li><a href="{root}/chapter/{index}">{title}</a></li>'
                              for index, title in enumerate(titles, start=1))
            self.html(f'<ol class="toc">{entries}</ol>')
        elif route.startswith("chapter/"):
            text = CONTENTS[int(route[-1]) - 1]
            self.html(f'<div class="content">{text}</div>')
        elif route == "login":
            self.html("<title>M2 Source Login</title><p>Controlled test page</p>")
        elif route == "rules":
            base = f"http://127.0.0.1:{self.server.server_port}{root}"
            self.json(source_rules(base, name=f"回环来源 {edition}"))
        elif route == "import" and edition == "primary":
            origin = f"http://127.0.0.1:{self.server.server_port}"
            self.json([source_rules(origin + f"/books/{suite}/{item}", name=f"回环来源 {item}")
                       for item in ("primary", "other")])
        elif route.startswith("package/"):
            origin = f"http://127.0.0.1:{self.server.server_port}"
            version = route[-1]
            package = [source_rules(origin + root, name=f"回环订阅 v{version}", group=f"v{version}", login=False)]
            if version == "2":
                package.append(source_rules(origin + f"/books/{suite}/addition", name="新增来源", login=False))
            self.json(package)
        return True


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=18765)
    args = parser.parse_args()
    with ThreadingHTTPServer(("127.0.0.1", args.port), Handler) as server:
        server.fixture = Fixture()
        print(f"M2_FIXTURE_READY http://127.0.0.1:{server.server_port}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
