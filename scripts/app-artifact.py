#!/usr/bin/env python3
"""Capture fixed build inputs and publish a source-bound simulator App artifact."""

import argparse
import errno
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
LATEST = ROOT / ".build/app-build.json"
CORE_RECEIPT = ROOT / ".build/core-build.json"


def build_path(kind):
    return Path(subprocess.check_output(
        ["python3", str(ROOT / "scripts/build-paths.py"), "--kind", kind], text=True).strip())


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def json_hash(value):
    return sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())


def files_under(path):
    return {file.relative_to(path).as_posix(): sha256(file.read_bytes())
            for file in sorted(path.rglob("*")) if file.is_file()}


def inputs():
    result = {}
    for directory in ("Sources", "Resources", "Configuration", "Vendor"):
        for name, digest in files_under(ROOT / directory).items():
            result[directory + "/" + name] = digest
    for name in ("project.yml", "Reader.xcodeproj/project.pbxproj",
                 "Reader.xcodeproj/xcshareddata/xcschemes/Reader.xcscheme",
                 "Reader.xcodeproj/project.xcworkspace/contents.xcworkspacedata", ".build/core-build.json",
                 "scripts/core-dependency.json", "scripts/build.sh", "scripts/app-artifact.py"):
        result[name] = sha256((ROOT / name).read_bytes())
    for name in ("scripts/verify-simulator-identity.py", "scripts/build-paths.py"):
        result[name] = sha256((ROOT / name).read_bytes())
    return result


def run_directory(run_id):
    if str(uuid.UUID(run_id)) != run_id:
        raise RuntimeError("Expected a canonical artifact run UUID")
    return build_path("artifacts") / run_id


def build_app_path(configuration, run_id):
    return build_path("app-derived") / run_id / "Build/Products" / (configuration + "-iphonesimulator") / "Reader.app"


def check_app(app):
    if any(path.name.endswith(".xctest") for path in app.rglob("*")):
        raise RuntimeError("A delivery App must not contain a test bundle; rebuild in the dedicated AppDerivedData lane")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if (info.get("CFBundleIdentifier") != "io.reader.minliny"
            or "iPhoneSimulator" not in info.get("CFBundleSupportedPlatforms", [])
            or info.get("MinimumOSVersion") not in ("17.0", "17.0.0")):
        raise RuntimeError("Expected io.reader.minliny simulator App with minimum iOS 17.0")
    architectures = subprocess.check_output(
        ["xcrun", "lipo", "-archs", str(app / info["CFBundleExecutable"])], text=True).split()
    if architectures != ["arm64"]:
        raise RuntimeError("This simulator lane supports arm64 only")
    return files_under(app)


def verify_simulator_identity(app, helper):
    return json.loads(subprocess.check_output(
        ["python3", str(helper), "--app", str(app)], text=True))


def prepare_copied_signature(app):
    # FileProvider metadata is not part of the App's bytes, but FinderInfo is
    # forbidden by codesign. Touch only this unpublished generated copy.
    for path in (app, *app.rglob("*")):
        if path.is_symlink():
            continue
        try:
            os.removexattr(path, "com.apple.FinderInfo", follow_symlinks=False)
        except OSError as error:
            if error.errno not in (errno.ENOATTR, errno.ENODATA):
                raise


def git_identity():
    def git(*values):
        return subprocess.check_output(
            ["git", "--no-optional-locks", "-C", str(ROOT), *values], text=True).strip()
    return {"commit": git("rev-parse", "HEAD"), "dirty": bool(git("status", "--porcelain"))}


def capture(configuration):
    run_id = str(uuid.uuid4())
    directory = run_directory(run_id)
    directory.mkdir(parents=True, exist_ok=False)
    captured = inputs()
    snapshot = directory / "inputs"
    for name in captured:
        destination = snapshot / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, destination)
    if files_under(snapshot) != captured or inputs() != captured:
        raise RuntimeError("Inputs changed while capturing this App build")
    document = {"schemaVersion": 2, "runId": run_id, "configuration": configuration,
                "gitIdentity": git_identity(), "files": captured}
    (directory / "capture.json").write_text(json.dumps(document, indent=2) + "\n")
    return run_id


def make_read_only(directory):
    for path in sorted(directory.rglob("*"), reverse=True):
        path.chmod(stat.S_IMODE(path.stat().st_mode) & ~0o222)
    directory.chmod(stat.S_IMODE(directory.stat().st_mode) & ~0o222)


def atomic_latest(data):
    LATEST.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=LATEST.parent, prefix=".app-build-", delete=False) as file:
        temporary = Path(file.name)
        file.write(data)
    try:
        os.replace(temporary, LATEST)
    finally:
        temporary.unlink(missing_ok=True)


def record(configuration, run_id):
    directory = run_directory(run_id)
    capture_document = json.loads((directory / "capture.json").read_text())
    if capture_document.get("configuration") != configuration or capture_document.get("runId") != run_id:
        raise RuntimeError("App capture does not belong to this build")
    captured = capture_document["files"]
    if captured != inputs() or captured != files_under(directory / "inputs"):
        raise RuntimeError("App inputs changed during compilation; finish source changes before rebuilding")
    source = build_app_path(configuration, run_id)
    source_files = check_app(source)
    helper = directory / "inputs/scripts/verify-simulator-identity.py"
    source_identity = verify_simulator_identity(source, helper)
    artifact = directory / "Reader.app"
    shutil.copytree(source, artifact)
    prepare_copied_signature(artifact)
    copied_identity = verify_simulator_identity(artifact, helper)
    if source_identity != copied_identity:
        raise RuntimeError("Simulator identity changed while copying the artifact")
    copied_files = check_app(artifact)
    if copied_files != source_files or files_under(source) != source_files:
        raise RuntimeError("App changed while copying its delivery artifact")
    if inputs() != captured:
        raise RuntimeError("App inputs changed while publishing the artifact")
    core_bytes = (directory / "inputs/.build/core-build.json").read_bytes()
    shutil.copy2(directory / "inputs/.build/core-build.json", directory / "core-build.json")
    identity = capture_document["gitIdentity"]
    document = {"schemaVersion": 2, "artifactRunId": run_id, "configuration": configuration,
                "bundleIdentifier": "io.reader.minliny", "architecture": "arm64",
                "minimumDeploymentTarget": "17.0", "appPath": str(artifact),
                "inputSnapshotPath": str(directory / "inputs"),
                "gitCommit": identity["commit"], "gitDirty": identity["dirty"],
                "buildEndGitIdentity": git_identity(),
                "inputFingerprint": json_hash(captured), "inputs": captured,
                "coreReceiptSha256": sha256(core_bytes), "coreBuild": json.loads(core_bytes),
                "simulatorIdentity": copied_identity,
                "appFiles": copied_files}
    data = (json.dumps(document, indent=2) + "\n").encode()
    (directory / "manifest.json").write_bytes(data)
    make_read_only(directory)
    atomic_latest(data)
    return artifact


def load_and_verify(receipt_path):
    # Read the selected receipt once. A concurrent build may replace LATEST, but
    # cannot redirect the already selected immutable run or its artifact bytes.
    receipt_bytes = Path(receipt_path).read_bytes()
    document = json.loads(receipt_bytes)
    if document.get("schemaVersion") != 2:
        raise RuntimeError("Rebuild the App to publish an immutable artifact receipt")
    run_id = document["artifactRunId"]
    if str(uuid.UUID(run_id)) != run_id:
        raise RuntimeError("Invalid immutable artifact run identity")
    directory = Path(document["appPath"]).parent
    # Earlier unsigned Simulator artifacts remain historical evidence at
    # their original location. New builds live outside FileProvider.
    if directory not in (run_directory(run_id), ROOT / ".build/app-artifacts" / run_id):
        raise RuntimeError("Unexpected immutable artifact directory")
    app = directory / "Reader.app"
    if ((directory / "manifest.json").read_bytes() != receipt_bytes
            or document.get("appPath") != str(app)
            or document.get("inputSnapshotPath") != str(directory / "inputs")
            or document.get("inputFingerprint") != json_hash(document.get("inputs"))
            or document.get("inputs") != files_under(directory / "inputs")
            or document.get("appFiles") != check_app(app)):
        raise RuntimeError("Immutable App artifact or its captured inputs changed")
    core_bytes = (directory / "core-build.json").read_bytes()
    if "simulatorIdentity" in document:
        actual_identity = verify_simulator_identity(app, directory / "inputs/scripts/verify-simulator-identity.py")
        if actual_identity != document["simulatorIdentity"]:
            raise RuntimeError("Immutable Simulator identity changed")
    core = json.loads(core_bytes)
    dependency = json.loads((directory / "inputs/scripts/core-dependency.json").read_text())
    if (document.get("coreReceiptSha256") != sha256(core_bytes)
            or document["inputs"].get(".build/core-build.json") != sha256(core_bytes)
            or document.get("coreBuild") != core
            or core.get("schemaVersion") != 2
            or core.get("dependencyCommit") != dependency["commit"]
            or core.get("deploymentTarget") != "17.0"):
        raise RuntimeError("The immutable App is not paired with its captured Core build")
    return document, receipt_bytes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["capture", "record", "verify"])
    parser.add_argument("--configuration", choices=["Debug", "Release"], default="Debug")
    parser.add_argument("--run-id", help="Run returned by capture; required for record")
    parser.add_argument("--receipt", type=Path, default=LATEST)
    args = parser.parse_args()
    if args.action == "capture":
        print(capture(args.configuration))
    elif args.action == "record":
        if args.run_id is None:
            parser.error("record requires --run-id returned by capture")
        print("Immutable App artifact: " + str(record(args.configuration, args.run_id)))
    else:
        document, _ = load_and_verify(args.receipt)
        if document.get("configuration") != args.configuration:
            raise RuntimeError("The selected artifact has a different build configuration")
        print("Verified immutable App artifact: " + document["appPath"])


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
