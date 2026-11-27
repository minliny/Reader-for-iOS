import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

project = Path(sys.argv[1])
build = project / ".build"
framework = build / "ReaderCore.xcframework"
archive = framework / "ios-arm64-simulator" / "libreader_core.a"
core = json.loads((project / "Scripts/pins.json").read_text())["core"]
receipt_path = build / "framework-receipt.json"
identity = json.loads((build / "core-build-identity.json").read_text())
if identity["gitCommit"] != core or identity["gitDirty"]:
    raise SystemExit(f"unexpected embedded Core identity {identity}")
input_fingerprint = json.loads((build / "core-inputs.json").read_text())["fingerprint"]
source_sha = (build / "core-source.sha256").read_text().strip()
files = {
    str(path.relative_to(framework)): hashlib.sha256(path.read_bytes()).hexdigest()
    for path in sorted(framework.rglob("*")) if path.is_file()
}
if sys.argv[2:] == ["--check"]:
    saved = json.loads(receipt_path.read_bytes())
    if (not archive.is_file() or saved["core"] != core or saved["identity"] != identity
            or saved["CoreInputFingerprint"] != input_fingerprint
            or saved["sourceArchiveSHA256"] != source_sha or saved["files"] != files):
        raise SystemExit(f"XCFramework receipt mismatches the pinned build {core}")
    print(f"XCFramework input and file SHA-256 match the receipt for {core}")
    sys.exit(0)
if sys.argv[2:]:
    raise SystemExit("usage: framework-receipt.py <project> [--check]")

load = subprocess.check_output(["xcrun", "otool", "-l", str(archive)], text=True)
platforms = sorted(set(re.findall(r"^\s+platform (\S+)", load, re.MULTILINE)))
minimums = sorted(set(re.findall(r"^\s+minos (\S+)", load, re.MULTILINE)))
if platforms not in (["IOSSIMULATOR"], ["7"]) or not minimums or any(
    tuple(map(int, version.split(".")))[:2] > (17, 0) for version in minimums
):
    raise SystemExit(f"unexpected platform/deployment versions {platforms} {minimums}")
receipt = {
    "core": core,
    "identity": identity,
    "CoreInputFingerprint": input_fingerprint,
    "sourceArchiveSHA256": source_sha,
    "platforms": platforms,
    "minimumVersions": minimums,
    "files": files,
}
receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
