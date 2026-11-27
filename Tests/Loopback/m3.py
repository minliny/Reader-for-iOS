"""Loopback-only M3 image and audio fixtures. No binary media ships with the app."""

from functools import lru_cache
import io
import math
import re
import struct
import wave
import zlib


def route(handler, path, query):
    if path == "/m3/manga/toc":
        handler.html("<ol><li><a href='/m3/manga/chapter'>图页章</a></li></ol>")
    elif path == "/m3/manga/chapter":
        handler.html("".join(f"<img src='/m3/manga/{page}.png'>" for page in ("small", "long", "budget")))
    elif path == "/m3/manga/small.png":
        handler.reply(200, png(80, 160, 5), "image/png")
    elif path == "/m3/manga/long.png":
        handler.reply(200, png(96, 22000, 0), "image/png")
    elif path == "/m3/manga/budget.png":
        handler.reply(200, png(1200, 20000, 5), "image/png")
    elif path == "/m3/speech/toc":
        handler.html("<ol><li><a href='/m3/speech/chapter'>朗读章</a></li></ol>")
    elif path == "/m3/speech/chapter":
        handler.html("<div>甲𠀀é。乙🙂！</div>")
    elif path == "/m3/speech/audio.wav":
        if query.get("q") == ["Audio fixture."] and query.get("rate") == ["1.25"]:
            handler.reply(200, tone(), "audio/wav")
        else:
            handler.server.fixture.record_failure("Unexpected M3 TTS request projection")
            handler.reply(422, "Unexpected M3 TTS request projection")
    else:
        return product(handler, path, query)
    return True


def product(handler, path, query):
    match = re.fullmatch(r"/m3/product/([a-z0-9]{12})/(manga|text)/(primary|other)/(.+)", path)
    if not match:
        return False
    suite, kind, source, action = match.groups()
    is_manga = kind == "manga"
    root = f"/m3/product/{suite}/{kind}"
    canonical = f"{root}/{source}"
    origin = "http://127.0.0.1:18765"
    title = f"回环{'漫画' if is_manga else '小说'} {suite}"
    author = "验证作者"
    if action == "import":
        package = []
        for name in ["primary", "other"] if is_manga else ["primary"]:
            base = origin + root + "/" + name
            package.append({
                "bookSourceUrl": base,
                "bookSourceName": f"回环{'漫画' if is_manga else '朗读'} {name} {suite}",
                "bookSourceType": 2 if is_manga else 0,
                "enabled": True,
                "searchUrl": base + "/search?q={{key}}",
                "ruleSearch": {"bookList": "ul li", "name": "span.name@text",
                               "author": "span.author@text", "bookUrl": "a@href"},
                "ruleBookInfo": {"name": "h1@text", "author": "p.author@text", "tocUrl": "a.toc@href"},
                "ruleToc": {"chapterList": "ol li", "chapterName": "a@text", "chapterUrl": "a@href"},
                "ruleContent": {"content": "tag.img@src" if is_manga else "div.content@text"},
            })
        handler.json(package)
    elif action == "search":
        term = query.get("q", [""])[0]
        if term not in (suite, title):
            handler.html("<ul></ul>")
        else:
            handler.html(f"<ul><li><span class=name>{title}</span><span class=author>{author}</span>"
                         f"<a href='{canonical}/detail'>详情</a></li></ul>")
    elif action == "detail":
        handler.html(f"<h1>{title}</h1><p class=author>{author}</p><a class=toc href='{canonical}/toc'>目录</a>")
    elif action == "toc":
        labels = ["第一话 · 晚钟", "第二话 · 夜渡"] if is_manga else ["晚灯照长街"]
        rows = "".join(f"<li><a href='{canonical}/chapter/{index}'>{label}</a></li>" for index, label in enumerate(labels))
        handler.html(f"<ol>{rows}</ol>")
    elif action == "chapter/0" and is_manga:
        handler.html("".join(f"<img src='{canonical}/{page}.png'>" for page in ("small", "long", "last")))
    elif action == "chapter/1" and is_manga:
        handler.html(f"<img src='{canonical}/last.png'>")
    elif action == "chapter/0":
        line = "路灯把落叶照成柔软的金色，桥边的店家正在收起门口的椅子。"
        handler.html("<div class=content>" + "傍晚的时候，晚风穿过安静的街巷。".join([line] * 18) + "</div>")
    elif action == "long.png":
        handler.reply(200, png(96, 22000, 0), "image/png")
    elif action in {"small.png", "last.png"}:
        handler.reply(200, png(160, 300, 5), "image/png")
    else:
        return False
    return True


@lru_cache(maxsize=3)
def png(width, height, level):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    compressor = zlib.compressobj(level)
    blue = b"\0" + b"\x20\x4c\x9e" * width
    red = b"\0" + b"\xb0\x27\x52" * width
    body = bytearray()
    for index in range(height):
        body.extend(compressor.compress(blue if index < height // 2 else red))
    body.extend(compressor.flush())
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", body) + chunk(b"IEND", b"")


@lru_cache(maxsize=1)
def tone():
    payload = io.BytesIO()
    rate = 16000
    frames = 2 * rate
    with wave.open(payload, "wb") as audio:
        audio.setparams((1, 2, rate, frames, "NONE", "not compressed"))
        audio.writeframes(struct.pack(f"<{frames}h", *[int(1200 * math.sin(2 * math.pi * 330 * i / rate))
                                                        for i in range(frames)]))
    return payload.getvalue()
