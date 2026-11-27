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
expected = {Path(path).name: facts["sha256"] for path, facts in files.items() if path.startswith("Resources/")}
actual = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in resources.iterdir() if p.is_file()}
assert actual == expected and len(list(resources.iterdir())) == len(expected) == 3
test_names = {Path(path).name for path in files if path.startswith("Tests/Fixtures/")}
for path in app.rglob("*"):
    if test_bundle is not None and (path == test_bundle or test_bundle in path.parents):
        continue
    assert path.name not in test_names and path.suffix not in (".epub", ".xctest"), path
if test_bundle:
    expected_tests = {Path(path).name: facts["sha256"] for path, facts in files.items() if path.startswith("Tests/Fixtures/")}
    actual_tests = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in test_bundle.rglob("*") if p.name in test_names
    }
    assert actual_tests == expected_tests
binary = app / "ReaderApp"
macho = subprocess.check_output(["xcrun", "vtool", "-show-build", str(binary)], text=True)
assert ("IOSSIMULATOR" in macho or "platform 7" in macho) and "minos 17.0" in macho
print(json.dumps({"application": str(app), "bundleId": info["CFBundleIdentifier"], "minOS": info["MinimumOSVersion"],
                  "appExecutableSHA256": hashlib.sha256(binary.read_bytes()).hexdigest(),
                  "coreExecutableSHA256": hashlib.sha256((app / "Frameworks/ReaderCoreBridge.framework/ReaderCoreBridge").read_bytes()).hexdigest(),
                  "productionResources": actual, "testFixtureNames": sorted(test_names) if test_bundle else [],
                  "fixtureIsolation": True}, indent=2))
