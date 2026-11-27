#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys

project = Path(__file__).resolve().parent.parent
app = Path(sys.argv[1]).resolve()
test_bundle = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else None
info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["CFBundleIdentifier"] == "io.reader.minliny.rebuild.m1"
assert info["MinimumOSVersion"] == "17.0"
assert info["CFBundleSupportedPlatforms"] == ["iPhoneSimulator"]
files = json.loads((project / "Scripts/input-receipt.json").read_text())["files"]
resources = app / "reader_ebook_runtime"
expected = {Path(path).name: facts["sha256"] for path, facts in files.items()
            if path.startswith("Resources/reader_ebook_runtime/")}
actual = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in resources.iterdir() if p.is_file()}
assert actual == expected and len(list(resources.iterdir())) == len(expected) == 3
design = app / "Frameworks/ReaderDesign.framework"
font_prefix = "Resources/reader_design/Fonts/"
expected_fonts = {Path(path).name: facts["sha256"] for path, facts in files.items()
                  if path.startswith(font_prefix)}
actual_fonts = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                for path in (design / "Fonts").iterdir() if path.is_file()}
assert actual_fonts == expected_fonts and len(actual_fonts) == 3
asset_catalog = design / "Assets.car"
compiled_assets = json.loads(subprocess.check_output(["xcrun", "assetutil", "--info", str(asset_catalog)]))
icon_names = {Path(path).stem for path in files if path.endswith(".svg")}
assert icon_names <= {record.get("Name") for record in compiled_assets}
golden_source = project / "Tests/Goldens/Baselines/manifest.json"
golden_manifest = json.loads(golden_source.read_text())
golden_names = {scene["id"] + ".png" for scene in golden_manifest["scenes"]}
test_names = {Path(path).name for path in files if path.startswith("Tests/Fixtures/")}
for path in app.rglob("*"):
    if test_bundle is not None and (path == test_bundle or test_bundle in path.parents):
        continue
    assert path.name not in test_names | golden_names | {"Baselines", "pins.json", "Loopback", "serve.py"}, path
    assert path.suffix not in (".epub", ".mobi", ".xctest"), path
if test_bundle:
    expected_tests = {Path(path).name: facts["sha256"] for path, facts in files.items() if path.startswith("Tests/Fixtures/")}
    actual_tests = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in test_bundle.rglob("*") if p.name in test_names
    }
    assert actual_tests == expected_tests
    assert (test_bundle / "pins.json").read_bytes() == (project / "Scripts/pins.json").read_bytes()
    assert not any(path.name in {"Loopback", "serve.py"} for path in test_bundle.rglob("*"))
    baselines = test_bundle / "Baselines"
    assert (baselines / "manifest.json").read_bytes() == golden_source.read_bytes()
    for scene in golden_manifest["scenes"]:
        sha = scene.get("pngSHA256")
        if sha:
            assert hashlib.sha256((baselines / (scene["id"] + ".png")).read_bytes()).hexdigest() == sha
binary = app / "ReaderApp"
macho = subprocess.check_output(["xcrun", "vtool", "-show-build", str(binary)], text=True)
assert ("IOSSIMULATOR" in macho or "platform 7" in macho) and "minos 17.0" in macho
print(json.dumps({"application": str(app), "bundleId": info["CFBundleIdentifier"], "minOS": info["MinimumOSVersion"],
                  "appExecutableSHA256": hashlib.sha256(binary.read_bytes()).hexdigest(),
                  "coreExecutableSHA256": hashlib.sha256((app / "Frameworks/ReaderCoreBridge.framework/ReaderCoreBridge").read_bytes()).hexdigest(),
                  "productionResources": actual, "designFonts": actual_fonts, "compiledIcons": sorted(icon_names),
                  "assetCatalogSHA256": hashlib.sha256(asset_catalog.read_bytes()).hexdigest(),
                  "testFixtureNames": sorted(test_names) if test_bundle else [],
                  "testGoldenCount": len(golden_names) if test_bundle else 0,
                  "fixtureIsolation": True}, indent=2))
