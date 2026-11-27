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
load = subprocess.check_output(["xcrun", "otool", "-l", str(archive)], text=True)
platforms = sorted(set(re.findall(r"^\s+platform (\S+)", load, re.MULTILINE)))
minimums = sorted(set(re.findall(r"^\s+minos (\S+)", load, re.MULTILINE)))
if platforms not in (["IOSSIMULATOR"], ["7"]) or not minimums or any(
    tuple(map(int, version.split(".")))[:2] > (17, 0) for version in minimums
):
    raise SystemExit(f"unexpected platform/deployment versions {platforms} {minimums}")
core = json.loads((project / "Scripts/pins.json").read_text())["core"]
identity = json.loads((build / "core-build-identity.json").read_text())
if identity["gitCommit"] != core or identity["gitDirty"]:
    raise SystemExit(f"unexpected embedded Core identity {identity}")
receipt = {
    "core": core,
    "identity": identity,
    "CoreInputFingerprint": json.loads((build / "core-inputs.json").read_text())["fingerprint"],
    "sourceArchiveSHA256": (build / "core-source.sha256").read_text().strip(),
    "platforms": platforms,
    "minimumVersions": minimums,
    "files": {
        str(path.relative_to(framework)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(framework.rglob("*")) if path.is_file()
    },
}
(build / "framework-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
