#!/usr/bin/env python3
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
receipt = json.loads((root / "Scripts/input-receipt.json").read_text())
synced = receipt["files"]
graph = {
    "ReaderCoreBridge": {"ReaderCore"},
    "ReaderHost": {"ReaderCoreBridge"},
    "ReaderDesign": set(),
    "ReaderApp": {"ReaderCoreBridge", "ReaderHost", "ReaderDesign"},
    "ReaderAppTests": {"ReaderCoreBridge", "ReaderHost", "ReaderApp"},
}
swift_import = re.compile(r"^(?:@testable )?import (Reader\w+)\s*$", re.MULTILINE)
actual = dict.fromkeys(graph)
maxima = {"authored": (0, ""), "pinned": (0, "")}
for group, base in [(group, root / "Sources" / group) for group in graph if group != "ReaderAppTests"] + [
    ("ReaderAppTests", root / "Tests")
]:
    imports = set()
    for file in base.rglob("*.swift"):
        imports.update(swift_import.findall(file.read_text()))
    assert imports <= graph[group], (group, imports - graph[group])
    actual[group] = sorted(imports)

folders = ["Sources", "Scripts", "Tests", "Resources"]
inputs = [f for name in folders for f in (root / name).rglob("*") if f.is_file()]
inputs += [root / "project.yml", root / "README.md"]
for file in inputs:
    if file.suffix == ".epub":
        continue
    ref = str(file.relative_to(root))
    count = len(file.read_bytes().splitlines())
    if ref not in synced:
        assert count <= 800, (ref, count)
    kind = "pinned" if ref in synced else "authored"
    maxima[kind] = max(maxima[kind], (count, ref))
assert all(path.startswith("Tests/Fixtures/") for path in synced if Path(path).suffix == ".epub")
print(json.dumps({"imports": actual, "maxLines": maxima, "scope": folders, "archCheck": "PASS"}, indent=2))
