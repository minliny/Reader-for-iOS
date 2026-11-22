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



def local_manifest(path):
    document = json.loads(Path(path).read_text())
    if (document.get("schemaVersion") != 1 or document.get("mode") != "local-development"
            or document.get("minimumDeploymentTarget") != CONFIG["minimumDeploymentTarget"]
            or document.get("pinnedBindingCommit") != CONFIG["commit"]
            or document.get("bindingSha256") != CONFIG["files"][0]["sha256"]
            or document.get("sourceSnapshot", {}).get("schemaVersion") != 1):
        raise RuntimeError("Expected an explicit matching local Core input manifest")
    check_binding()
    return document


def local_apple_inputs(source):
    names = ["scripts/build-ios-xcframework.sh", "tools/reader-cli/Cargo.toml"]
    return {name: digest((source / name).read_bytes()) for name in names}



def local_abi_compatibility(source, source_binding):
    pinned_header = git(source, "show", CONFIG["commit"] + ":include/reader_core.h")
    current_header = (source / "include/reader_core.h").read_bytes()
    runtime = (source / "crates/reader-ffi/src/runtime.rs").read_text()
    host = (ROOT / "Sources/ReaderRuntime/ReaderLibraryService.swift").read_text()
    core_version = re.search(r"pub const ABI_VERSION:\s*u32\s*=\s*(\d+)\s*;", runtime)
    required = re.search(r"requiredCoreABIVersion:\s*UInt32\s*=\s*(\d+)", host)
    if core_version is None or required is None or core_version[1] != required[1]:
        raise RuntimeError("Local Core ABI version differs from the actual Host initialization requirement")
    sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
    def declarations(header):
        result = subprocess.run(["xcrun", "clang", "-x", "c", "-std=c11", "-target", "arm64-apple-ios17.0",
                                 "-isysroot", sdk, "-fsyntax-only", "-Xclang", "-ast-dump=json", "-"],
                                input=header, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        tree = json.loads(result.stdout); output = {}
        def c_type(node):
            value = node.get("type", {})
            # Clang's typeAliasDeclId is an address local to one invocation.
            return {key: value[key] for key in ("qualType", "desugaredQualType") if key in value}
        def visit(node):
            name = node.get("name", ""); kind = node.get("kind")
            if name.startswith("rc_"):
                if kind in ("FunctionDecl", "TypedefDecl"):
                    output[kind + ":" + name] = c_type(node)
                elif kind == "RecordDecl" and node.get("completeDefinition"):
                    output[kind + ":" + name] = [(field.get("name"), c_type(field), field.get("isBitfield", False))
                        for field in node.get("inner", []) if field.get("kind") == "FieldDecl"]
                elif kind == "EnumDecl":
                    output[kind + ":" + name] = [(field.get("name"), [item.get("value") for item in field.get("inner", [])
                        if item.get("kind") == "ConstantExpr"]) for field in node.get("inner", []) if field.get("kind") == "EnumConstantDecl"]
            for child in node.get("inner", []): visit(child)
        visit(tree)
        return output
    old = declarations(pinned_header); current = declarations(current_header)
    changed = [name for name, signature in old.items() if current.get(name) != signature]
    if not old or changed:
        raise RuntimeError("Local Core changes existing pinned C declarations: " + ", ".join(changed))
    return {"method": "Clang C AST arm64-apple-ios17.0; all pinned public declarations preserved",
            "hostRequiredABIVersion": int(required[1]), "coreABIVersion": int(core_version[1]),
            "pinnedHeaderSha256": digest(pinned_header), "currentHeaderSha256": digest(current_header),
            "preservedDeclarationCount": len(old), "addedDeclarations": sorted(set(current) - set(old)),
            "coreSourceBindingSha256": source_binding, "hostBindingSha256": CONFIG["files"][0]["sha256"],
            "usedBinding": "fixed Host wrapper; Core source wrapper is separately captured"}

def capture_local(source, manifest):
    # Capture with Core's existing source inventory, retaining actual dirty Git
    # identity. Add the Apple entry script, which the OHOS inventory omits.
    check_binding()
    manifest.parent.mkdir(parents=True, exist_ok=True)
    helper = source / "scripts/build-input-snapshot.mjs"
    import tempfile
    with tempfile.NamedTemporaryFile(dir=manifest.parent, suffix=".json") as temporary:
        subprocess.run(["node", str(helper), "capture", temporary.name], check=True)
        snapshot = json.loads(Path(temporary.name).read_text())
    binding = digest((source / CONFIG["files"][0]["source"]).read_bytes())
    header = digest((source / "include/reader_core.h").read_bytes())
    compatibility = local_abi_compatibility(source, binding)
    document = {"schemaVersion": 1, "mode": "local-development", "sourceRoot": str(source),
                "sourceSnapshot": snapshot, "iosBuildInputs": local_apple_inputs(source),
                "bindingSha256": CONFIG["files"][0]["sha256"], "coreSourceBindingSha256": binding,
                "abiCompatibility": compatibility, "headerSha256": header,
                "moduleMapSha256": digest((source / "bindings/ios/module.modulemap").read_bytes()),
                "pinnedBindingCommit": CONFIG["commit"],
                "minimumDeploymentTarget": CONFIG["minimumDeploymentTarget"]}
    write_if_changed(manifest, (json.dumps(document, indent=2) + "\n").encode())
    return document


def verify_local_source(source, manifest):
    document = local_manifest(manifest)
    if Path(document["sourceRoot"]).resolve() != source:
        raise RuntimeError("Local Core manifest belongs to another checkout")
    import tempfile
    with tempfile.NamedTemporaryFile(dir=manifest.parent, suffix=".json", mode="w+") as temporary:
        json.dump(document["sourceSnapshot"], temporary); temporary.flush()
        subprocess.run(["node", str(source / "scripts/build-input-snapshot.mjs"), "verify", temporary.name], check=True)
    if (document["iosBuildInputs"] != local_apple_inputs(source)
            or digest((source / CONFIG["files"][0]["source"]).read_bytes()) != document["coreSourceBindingSha256"]
            or digest((source / "include/reader_core.h").read_bytes()) != document["headerSha256"]
            or digest((source / "bindings/ios/module.modulemap").read_bytes()) != document["moduleMapSha256"]):
        raise RuntimeError("Local Apple build, binding or header inputs changed during compilation")
    return document


def record_local_framework(source, manifest, deployment_target):
    document = verify_local_source(source, manifest)
    if FRAMEWORK.is_symlink() or ROOT.resolve() not in FRAMEWORK.resolve().parents:
        raise RuntimeError("Local Core output must be independent; unlink a borrowed framework symlink before building")
    if any(path.is_symlink() for path in FRAMEWORK.rglob("*")):
        raise RuntimeError("Local Core framework must not reference external bytes")
    files = framework_files()
    headers = {value for name, value in files.items() if name.endswith("/Headers/reader_core.h")}
    module_maps = {value for name, value in files.items() if name.endswith("/Headers/module.modulemap")}
    if headers != {document["headerSha256"]} or module_maps != {document["moduleMapSha256"]}:
        raise RuntimeError("Framework C header or module map differs from the captured local Core inputs")
    # Copy the exact pre-build manifest into the Host's private input slot. It
    # becomes part of every App input capture, independent of later Core edits.
    captured = ROOT / ".build/core-local-input.json"
    write_if_changed(captured, manifest.read_bytes())
    receipt = {"schemaVersion": 3, "mode": "local-development",
               "pinnedBindingCommit": CONFIG["commit"], "bindingSha256": document["bindingSha256"],
               "coreSourceBindingSha256": document["coreSourceBindingSha256"], "abiCompatibility": document["abiCompatibility"],
               "localManifestSha256": digest(manifest.read_bytes()),
               "sourceFingerprint": document["sourceSnapshot"]["fingerprint"],
               "buildSource": str(source), "buildSourceHead": document["sourceSnapshot"]["gitIdentity"]["gitCommit"],
               "buildSourceDirty": document["sourceSnapshot"]["gitIdentity"]["gitDirty"],
               "deploymentTarget": CONFIG["minimumDeploymentTarget"],
               "deploymentAudit": deployment_audit(deployment_target), "files": files, "tests": "NOT_RUN"}
    write_if_changed(RECEIPT, (json.dumps(receipt, indent=2) + "\n").encode())


def verify_local_framework(manifest):
    document = local_manifest(manifest)
    receipt = json.loads(RECEIPT.read_text())
    captured = ROOT / ".build/core-local-input.json"
    if (FRAMEWORK.is_symlink() or ROOT.resolve() not in FRAMEWORK.resolve().parents
            or any(path.is_symlink() for path in FRAMEWORK.rglob("*"))
            or receipt.get("schemaVersion") != 3 or receipt.get("mode") != "local-development"
            or receipt.get("localManifestSha256") != digest(manifest.read_bytes())
            or captured.read_bytes() != manifest.read_bytes()
            or receipt.get("sourceFingerprint") != document["sourceSnapshot"]["fingerprint"]
            or receipt.get("coreSourceBindingSha256") != document["coreSourceBindingSha256"]
            or receipt.get("abiCompatibility") != document["abiCompatibility"]
            or receipt.get("pinnedBindingCommit") != CONFIG["commit"]
            or receipt.get("bindingSha256") != document["bindingSha256"]
            or receipt.get("deploymentTarget") != CONFIG["minimumDeploymentTarget"]
            or receipt.get("tests") != "NOT_RUN"
            or receipt.get("files") != framework_files()
            or receipt.get("deploymentAudit") != deployment_audit(CONFIG["minimumDeploymentTarget"])):
        raise RuntimeError("Local Core framework or its explicit source manifest changed")
    # No current-source recapture: the sealed Native receipt binds the actual
    # before/after verified source snapshot, not today's mutable Core tree.
    return receipt

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["sync", "snapshot", "capture-local", "verify-local-source", "record-framework", "verify-framework"])
    parser.add_argument("--source", type=Path, help="Actual Core checkout used for this completed build")
    parser.add_argument("--deployment-target", default=os.environ.get("IPHONEOS_DEPLOYMENT_TARGET"),
                        help="Actual build deployment input; required by record-framework")
    parser.add_argument("--local-core-manifest", type=Path,
                        help="Explicit dirty/local development input manifest; never substitutes for the pinned dependency")
    args = parser.parse_args()
    if args.local_core_manifest is not None:
        manifest = args.local_core_manifest.expanduser().resolve()
        if args.action in ("capture-local", "verify-local-source", "record-framework"):
            if args.source is None: parser.error("local source action requires --source")
            source = args.source.expanduser().resolve()
        if args.action == "capture-local": capture_local(source, manifest)
        elif args.action == "verify-local-source": verify_local_source(source, manifest)
        elif args.action == "record-framework": record_local_framework(source, manifest, args.deployment_target)
        elif args.action == "verify-framework": verify_local_framework(manifest)
        elif args.action == "sync": local_manifest(manifest)  # validate; do not rewrite pinned Vendor identity
        else: parser.error("local development cannot use the pinned snapshot action")
        return
    if args.action in ("capture-local", "verify-local-source"):
        parser.error("local source action requires --local-core-manifest")
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
