#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

project = Path(__file__).resolve().parent.parent
workspace = project.parent.parent
pin = json.loads((project / "Scripts/pins.json").read_text())


def object_bytes(repo, role, path):
    return subprocess.check_output(
        ["git", "-C", str(workspace / repo), "show", f"{pin[role]}:{path}"]
    )


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    args = argparse.ArgumentParser()
    mode = args.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    check = args.parse_args().check
    ui_repo = "Reader-UI"
    manifest_bytes = object_bytes(ui_repo, "ui", "reader_ebook_runtime/manifest.json")
    manifest = json.loads(manifest_bytes)
    if manifest["harmonyCommit"] != pin["harmony"]:
        raise SystemExit("Reader-UI manifest HarmonyOS pin mismatch")
    paths = {}
    core_path = "bindings/ios/Sources/ReaderCoreClient/Generated/ReaderProtocolModels.swift"
    paths["Sources/ReaderCoreBridge/Generated/ReaderProtocolModels.swift"] = (
        "Reader-Core", "core", core_path, None
    )
    for path, expected in manifest["generatedDesign"].items():
        if path.startswith("theme/generated/ios/"):
            paths["Sources/ReaderDesign/Generated/" + Path(path).name] = (
                ui_repo, "ui", path, expected
            )
    if len(manifest["productionResources"]) != 3:
        raise SystemExit("Unexpected production resource manifest")
    for path, expected in manifest["productionResources"].items():
        paths["Resources/" + path] = (ui_repo, "ui", path, expected)
    for path, expected in manifest["testResources"].items():
        paths["Tests/Fixtures/" + Path(path).name] = (ui_repo, "ui", path, expected)

    for name in ("local-reading.txt", "reading-lifecycle.json", "scalar-selection.json"):
        source = f"protocol/fixtures/m1/{name}"
        paths[f"Tests/Fixtures/{name}"] = ("Reader-Core", "core", source, None)

    # The iOS asset compiler consumes the authoritative SVG bytes. Font licensing
    # follows the two Noto faces into ReaderDesign's resource bundle.
    for name in ("reader_control_header_chevron", "settings_gen_navigation"):
        source = f"theme/icons/{name}.svg"
        paths[f"Resources/reader_design/Icons.xcassets/{name}.imageset/{name}.svg"] = (
            ui_repo, "ui", source, manifest["designInputs"][source]
        )
    for name in ("NotoSansSC-VF.otf", "NotoSerifSC-Regular.ttf", "OFL.txt"):
        paths[f"Resources/reader_design/Fonts/{name}"] = (ui_repo, "ui", f"fonts/{name}", None)
    # The pinned libmobi NCX sample is the readable, synthetic upstream book
    # exercised by Core's existing integration tests, scoped here to XCTest.
    paths["Tests/Fixtures/sample-ncx.mobi"] = (
        "Reader-Core", "core", "third_party/libmobi-0.12/tests/samples/sample-ncx.mobi", None
    )

    library_fixture = "crates/reader-storage/tests/fixtures/library47-schema.sql"

    stale = []
    authority = {
        path: sha(object_bytes("Reader-Core", "core", path))
        for path in (
            "protocol/reader-command.schema.json", "protocol/reader-event.schema.json",
            "protocol/reader-runtime-config.schema.json", "include/reader_core.h",
        )
    }
    for path, expected in (manifest["designInputs"] | manifest["toolInputs"]).items():
        if sha(object_bytes(ui_repo, "ui", path)) != expected:
            raise SystemExit(f"authority SHA-256 mismatch: {path}")
        authority[path] = expected
    harmony = object_bytes("Reader-for-HarmonyOS", "harmony", "scripts/core-dependency.json")
    receipt = {
        "pins": pin,
        "harmonyPairedCore": json.loads(harmony)["coreCommit"],
        "harmonyDependencySHA256": sha(harmony),
        "uiManifestSHA256": sha(manifest_bytes),
        "authoritySHA256": authority,
        "files": {},
    }
    inputs = {
        destination: (source, object_bytes(repo, role, source), expected)
        for destination, (repo, role, source, expected) in paths.items()
    }
    # Keep each test-only text input under the repository's 800-line limit.
    schema = object_bytes("Reader-Core", "core", library_fixture)
    receipt["authoritySHA256"][library_fixture] = sha(schema)
    lines = schema.splitlines(keepends=True)
    for index, start in enumerate(range(0, len(lines), 600), 1):
        destination = f"Tests/Fixtures/library47-schema-{index}.sqlpart"
        inputs[destination] = (library_fixture, b"".join(lines[start:start + 600]), None)
    for destination, (source, content, expected) in sorted(inputs.items()):
        digest = sha(content)
        if expected is not None and digest != expected:
            raise SystemExit(f"authority SHA-256 mismatch: {source}")
        target = project / destination
        if not target.is_file() or target.read_bytes() != content:
            stale.append(destination)
            if not check:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
        receipt["files"][destination] = {"source": source, "sha256": digest}

    for directory in ("Resources/reader_ebook_runtime", "Resources/reader_design/Fonts", "Tests/Fixtures"):
        actual = {str(path.relative_to(project))
                  for path in (project / directory).rglob("*") if path.is_file()}
        extra = actual - inputs.keys()
        if extra:
            raise SystemExit(f"Unexpected files: {sorted(extra)}")

    target = project / "Scripts/input-receipt.json"
    data = (json.dumps(receipt, ensure_ascii=False, indent=2) + "\n").encode()
    if not target.is_file() or target.read_bytes() != data:
        stale.append("Scripts/input-receipt.json")
        if not check:
            target.write_bytes(data)
    print(data.decode(), end="")
    print(f"{len(inputs)} pinned inputs; {len(stale) if check else 0} stale")
    if check and stale:
        print("\n".join(stale), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
