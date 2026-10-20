#!/usr/bin/env python3
"""Synchronize the pinned Swift binding and bind local XCFramework bytes to it."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "scripts/core-dependency.json"
CONFIG = json.loads(CONFIG_PATH.read_text())
FRAMEWORK = ROOT / ".build/ReaderCore.xcframework"
RECEIPT = ROOT / ".build/core-build.json"
BUILD_INPUTS = [
    "Cargo.toml", "Cargo.lock", "rust-toolchain.toml", ".cargo", "crates",
    "third_party", "protocol", "include", "bindings/ios", "tools/reader-cli/Cargo.toml",
    "scripts/build-ios-xcframework.sh", "scripts/lib/build-env.sh",
]


def git(repo, *arguments):
    return subprocess.check_output(
        ["git", "--no-optional-locks", "-C", str(repo), *arguments], stderr=subprocess.PIPE
    )


def core_repo():
    repo = Path(os.environ.get("READER_CORE_ROOT", ROOT.parent / "Reader-Core")).resolve()
    actual = git(repo, "rev-parse", CONFIG["commit"] + "^{commit}").decode().strip()
    if actual != CONFIG["commit"]:
        raise RuntimeError("Core dependency must resolve to the exact configured commit")
    return repo


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_if_changed(path, data):
    if not path.exists() or path.read_bytes() != data:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def sync_binding():
    repo = core_repo()
    for item in CONFIG["files"]:
        data = git(repo, "show", CONFIG["commit"] + ":" + item["source"])
        if digest(data) != item["sha256"]:
            raise RuntimeError("Pinned Core binding hash differs from core-dependency.json")
        write_if_changed(ROOT / item["destination"], data)
    write_if_changed(
        ROOT / "Vendor/ReaderCoreClient/SOURCE.json",
        (json.dumps(CONFIG, ensure_ascii=False, indent=2) + "\n").encode(),
    )


def check_binding():
    for item in CONFIG["files"]:
        path = ROOT / item["destination"]
        if not path.is_file() or digest(path.read_bytes()) != item["sha256"]:
            raise RuntimeError("Swift binding is missing or changed; run scripts/generate-project.sh")


def check_source(repo):
    changed = git(repo, "diff", "--name-only", CONFIG["commit"], "--", *BUILD_INPUTS)
    untracked = git(repo, "ls-files", "--others", "--exclude-standard", "--", *BUILD_INPUTS)
    if changed.strip() or untracked.strip():
        details = (changed + untracked).decode().strip()
        raise RuntimeError("Core build inputs differ from the pinned dependency:\n" + details)


def snapshot():
    source = core_repo()
    destination = ROOT / ".build/core-source" / CONFIG["commit"]
    if not destination.exists():
        destination.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["git", "clone", "--quiet", "--shared", "--no-checkout", str(source), str(destination)],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(destination), "checkout", "--quiet", "--detach", CONFIG["commit"]],
            check=True,
        )
    if git(destination, "rev-parse", "HEAD").decode().strip() != CONFIG["commit"]:
        raise RuntimeError("The private Core build snapshot has changed HEAD")
    check_source(destination)
    return destination


def framework_files():
    if not (FRAMEWORK / "Info.plist").is_file():
        raise RuntimeError("ReaderCore.xcframework is missing; run scripts/build-core.sh")
    return {
        path.relative_to(FRAMEWORK).as_posix(): digest(path.read_bytes())
        for path in sorted(FRAMEWORK.rglob("*")) if path.is_file()
    }


def version_tuple(value):
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", value or ""):
        raise RuntimeError("A numeric iOS deployment target is required")
    return tuple((list(map(int, value.split("."))) + [0, 0])[:3])


def deployment_audit(target):
    required = CONFIG["minimumDeploymentTarget"]
    if target is None or version_tuple(target) != version_tuple(required):
        raise RuntimeError("Explicit deployment target " + required + " is required for this App")
    info = plistlib.loads((FRAMEWORK / "Info.plist").read_bytes())
    slices = []
    for library in info.get("AvailableLibraries", []):
        identifier = library["LibraryIdentifier"]
        variant = library.get("SupportedPlatformVariant")
        if library.get("SupportedPlatform") != "ios" or variant not in (None, "simulator"):
            raise RuntimeError("Unexpected Core XCFramework platform")
        archive = FRAMEWORK / identifier / library["LibraryPath"]
        output = subprocess.check_output(["xcrun", "otool", "-l", str(archive)], text=True)
        versions = {}
        expected_platform = "7" if variant == "simulator" else "2"
        for command in re.split(r"\nLoad command \d+\n", output):
            if re.search(r"^\s*cmd LC_BUILD_VERSION\s*$", command, re.M):
                platform = re.search(r"^\s*platform\s+(\S+)\s*$", command, re.M)
                minimum = re.search(r"^\s*minos\s+([0-9.]+)\s*$", command, re.M)
                if platform is None or minimum is None or platform.group(1) != expected_platform:
                    raise RuntimeError("Unexpected Mach-O platform in " + identifier)
                minimum = minimum.group(1)
            elif re.search(r"^\s*cmd LC_VERSION_MIN_IPHONEOS\s*$", command, re.M):
                minimum = re.search(r"^\s*version\s+([0-9.]+)\s*$", command, re.M)
                if minimum is None:
                    raise RuntimeError("Missing Mach-O deployment version in " + identifier)
                minimum = minimum.group(1)
            else:
                continue
            if version_tuple(minimum) > version_tuple(required):
                raise RuntimeError("Core object requires iOS " + minimum + "; rebuild for " + required)
            versions[minimum] = versions.get(minimum, 0) + 1
        if not versions:
            raise RuntimeError("No Mach-O deployment metadata found in " + identifier)
        slices.append({"identifier": identifier, "platform": expected_platform,
                       "versionedObjectCount": sum(versions.values()), "minimumVersions": versions})
    if not slices:
        raise RuntimeError("No iOS slices in Core XCFramework")
    return {"inspectionTool": "xcrun otool -l", "slices": slices}


def record_framework(source, deployment_target):
    check_binding()
    check_source(source)
    document = {
        "schemaVersion": 2,
        "dependencyCommit": CONFIG["commit"],
        "bindingSha256": CONFIG["files"][0]["sha256"],
        "buildSource": str(source.resolve()),
        "buildSourceHead": git(source, "rev-parse", "HEAD").decode().strip(),
        "buildSourceDirty": bool(git(source, "status", "--porcelain").strip()),
        "deploymentTarget": CONFIG["minimumDeploymentTarget"],
        "deploymentAudit": deployment_audit(deployment_target),
        "files": framework_files(),
        "tests": "NOT_RUN",
    }
    write_if_changed(RECEIPT, (json.dumps(document, indent=2) + "\n").encode())


def verify_framework():
    check_binding()
    if not RECEIPT.is_file():
        raise RuntimeError("XCFramework source receipt is missing; complete scripts/build-core.sh first")
    document = json.loads(RECEIPT.read_text())
    if (
        document.get("schemaVersion") != 2
        or document.get("dependencyCommit") != CONFIG["commit"]
        or document.get("bindingSha256") != CONFIG["files"][0]["sha256"]
        or document.get("deploymentTarget") != CONFIG["minimumDeploymentTarget"]
        or document.get("files") != framework_files()
    ):
        raise RuntimeError("XCFramework bytes or Core dependency changed; rebuild this dependency")
    if document.get("deploymentAudit") != deployment_audit(CONFIG["minimumDeploymentTarget"]):
        raise RuntimeError("XCFramework Mach-O deployment metadata changed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["sync", "snapshot", "record-framework", "verify-framework"])
    parser.add_argument("--source", type=Path, help="Actual Core checkout used for this completed build")
    parser.add_argument("--deployment-target", default=os.environ.get("IPHONEOS_DEPLOYMENT_TARGET"),
                        help="Actual build deployment input; required by record-framework")
    args = parser.parse_args()
    if args.action == "sync":
        sync_binding()
    elif args.action == "snapshot":
        print(snapshot())
    elif args.action == "record-framework":
        if args.source is None:
            parser.error("record-framework requires --source pointing to the actual build checkout")
        record_framework(args.source.resolve(), args.deployment_target)
    else:
        verify_framework()


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
