#!/usr/bin/env python3
"""Validate M2 recording evidence and make the iOS golden contact sheet."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct


project = Path(__file__).resolve().parent.parent
baselines = project / "Tests/Goldens/Baselines"
manifest_path = baselines / "manifest.json"
fingerprint = re.compile(r"[0-9a-f]{64}")


def require(value, message):
    if not value:
        raise SystemExit(message)


def verify_png(directory, scene):
    path = directory / (scene["id"] + ".png")
    data = path.read_bytes()
    require(len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR",
            f"Invalid PNG: {path}")
    size = struct.unpack(">II", data[16:24])
    require(size == (scene["width"], scene["height"]), f"Unexpected viewport: {path} {size}")
    require(hashlib.sha256(data).hexdigest() == scene.get("pngSHA256"), f"PNG digest mismatch: {path}")
    require(fingerprint.fullmatch(scene.get("pixelSHA256") or ""), f"Missing pixel digest: {path}")
    return data


def scene_metadata(scene):
    return {key: value for key, value in scene.items() if key not in ("pixelSHA256", "pngSHA256")}


def accept_m2(recording):
    original = json.loads(manifest_path.read_bytes())
    recorded = json.loads((recording / "manifest.json").read_bytes())
    for key, value in original.items():
        if key != "scenes":
            require(recorded.get(key) == value, f"Recording changed manifest {key}")
    require(recorded.keys() == original.keys(), "Recording changed manifest keys")
    require(len(original["scenes"]) == len(recorded["scenes"]), "Recording changed scene count")
    pins = json.loads((project / "Scripts/pins.json").read_bytes())
    images = {}
    for baseline, output in zip(original["scenes"], recorded["scenes"]):
        scene = baseline["id"]
        if baseline.get("milestone") != "M2":
            require(output == baseline, f"Recording changed M1 scene {scene}")
            verify_png(baselines, baseline)
            continue
        require(baseline["pins"] == pins, f"Stale M2 pins: {scene}")
        require(scene_metadata(output) == scene_metadata(baseline), f"Recording changed M2 metadata for {scene}")
        name = scene + ".png"
        require(name not in images and re.fullmatch(r"m2-[a-z0-9-]+\.png", name), f"Invalid M2 ID: {scene}")
        images[name] = verify_png(recording, output)
    require({path.name for path in recording.iterdir()} == {"manifest.json", *images},
            "Recording must contain exactly the M2 PNGs and one manifest")
    require(len(images) >= 7, "Expected at least seven recorded M2 scenes")

    for name, data in images.items():
        (baselines / name).write_bytes(data)
    manifest_path.write_bytes((recording / "manifest.json").read_bytes())
    print(f"Accepted {len(images)} M2 scenes and preserved 18 M1 PNGs and scene records")


def contact_sheet(output):
    from PIL import Image, ImageDraw, ImageFont, ImageOps

    scenes = json.loads(manifest_path.read_bytes())["scenes"]
    columns = 5
    width, height = 250, 466
    pad = 18
    rows = (len(scenes) + columns - 1) // columns
    heading = 72
    sheet = Image.new("RGB", (columns * width + pad * 2, rows * height + heading + pad), "#f1f2ed")
    draw = ImageDraw.Draw(sheet)
    font_path = "/System/Library/Fonts/Supplemental/Arial.ttf"
    title, subtitle, label, detail = (ImageFont.truetype(font_path, size) for size in (28, 16, 14, 12))
    draw.text((pad, 13), "Reader  /  iOS golden snapshots", font=title, fill="#173b30")
    draw.text((pad, 47), "iPhone 17  /  iOS 26.5  /  M1 + M2", font=subtitle, fill="#445a52")
    for index, scene in enumerate(scenes):
        x = pad + index % columns * width
        y = heading + index // columns * height
        path = baselines / (scene["id"] + ".png")
        verify_png(baselines, scene)
        with Image.open(path) as image:
            size = ImageOps.contain(image.convert("RGB"), (width - pad, height - 52),
                                    Image.Resampling.LANCZOS)
        draw.rounded_rectangle((x, y, x + width - 8, y + height - 9),
                               radius=8, fill="#ffffff", outline="#d1d9d1")
        sheet.paste(size, (x + (width - 8 - size.width) // 2, y + 5))
        label_y = y + height - 43
        draw.text((x + 10, label_y), scene["id"], font=label, fill="#202f28")
        mode = scene.get("milestone", "M1")
        dimensions = f'{scene["width"]} x {scene["height"]}'
        detail_text = f'{mode} / {dimensions} / {scene["theme"]} / {scene["textSize"]}'
        draw.text((x + 10, label_y + 18), detail_text, font=detail, fill="#445a52")
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    print(f"Contact sheet {output} ({len(scenes)} scenes, {sheet.width} × {sheet.height})")


parser = argparse.ArgumentParser(description=__doc__)
actions = parser.add_subparsers(dest="action", required=True)
actions.add_parser("accept-m2").add_argument("recording", type=Path)
actions.add_parser("contact-sheet").add_argument("output", type=Path)
options = parser.parse_args()
if options.action == "accept-m2":
    accept_m2(options.recording)
else:
    contact_sheet(options.output)
