"""Loopback-only M3 image and audio fixtures. No binary media ships with the app."""

from functools import lru_cache
import io
import math
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
