#!/usr/bin/env bash
set -euo pipefail
ios_root="$(cd "$(dirname "$0")/.." && pwd)"
udid=''
configuration=Debug
launch=0
while (( $# > 0 )); do
  case "$1" in
    --udid) udid="${2:?--udid requires an explicit simulator UDID}"; shift 2 ;;
    --configuration) configuration="${2:?--configuration requires Debug or Release}"; shift 2 ;;
    --launch) launch=1; shift ;;
    --help)
      echo 'Usage: scripts/deploy-simulator.sh --udid <UDID> [--configuration Debug|Release] [--launch]'
      echo 'Overwrites only the named, already booted simulator App after snapshotting protected data.'
      echo 'Quit the App and stop concurrent data writes before deployment; container paths may migrate.'
      echo 'No build, test, boot, erase or uninstall is invoked.'
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [[ ! "$udid" =~ ^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$ ]]; then
  echo 'An explicit simulator UDID is required.' >&2
  exit 2
fi
case "$configuration" in Debug|Release) ;; *) echo 'Expected Debug or Release.' >&2; exit 2 ;; esac
python3 - "$ios_root" "$udid" "$configuration" "$launch" <<'PY'
import datetime
import hashlib
import json
from pathlib import Path
import runpy
import sqlite3
import subprocess
import sys

root, udid, configuration, launch = Path(sys.argv[1]), sys.argv[2].upper(), sys.argv[3], sys.argv[4] == "1"
bundle = "io.reader.minliny"
artifact = runpy.run_path(str(root / "scripts/app-artifact.py"))
document, receipt_bytes = artifact["load_and_verify"](root / ".build/app-build.json")
if document.get("configuration") != configuration:
    raise SystemExit("The selected immutable artifact has a different build configuration")
app = Path(document["appPath"])
def simctl(*arguments):
    return subprocess.check_output(["xcrun", "simctl", *arguments])
inventory = json.loads(simctl("list", "devices", "available", "--json"))
matches = [device for devices in inventory["devices"].values() for device in devices
           if device["udid"].upper() == udid]
if len(matches) != 1 or matches[0]["state"] != "Booted":
    raise SystemExit("The explicitly named simulator must already be available and Booted")
def apps():
    data = simctl("listapps", udid)
    converted = subprocess.check_output(["plutil", "-convert", "json", "-o", "-", "--", "-"], input=data)
    return json.loads(converted)
def package_metadata(value):
    return {key: value[key] for key in ("CFBundleIdentifier", "CFBundleVersion", "CFBundleShortVersionString") if key in value}
def protected_snapshot(container):
    base = Path(container)
    if base.is_symlink() or not base.is_dir():
        raise RuntimeError("Protected data container is unavailable")
    candidates = set()
    for relative in ("Documents", "Library/Application Support"):
        directory = base / relative
        if directory.is_symlink() or (directory.exists() and not directory.is_dir()):
            raise RuntimeError("Unsupported protected data directory: " + relative)
        for path in directory.rglob("*"):
            if path.is_symlink():
                raise RuntimeError("Unsupported protected data symbolic link: " + path.relative_to(base).as_posix())
            if path.is_file():
                candidates.add(path)
    preferences = base / "Library/Preferences" / (bundle + ".plist")
    if preferences.is_symlink():
        raise RuntimeError("Unsupported protected preferences symbolic link")
    if preferences.exists():
        if not preferences.is_file():
            raise RuntimeError("Protected preferences is not a file")
        candidates.add(preferences)
    databases = set()
    for path in candidates:
        with path.open("rb") as file:
            if file.read(16) == b"SQLite format 3\x00":
                databases.add(path)
    sidecars = {Path(str(path) + suffix) for path in databases for suffix in ("-wal", "-shm")}
    files = {}
    for path in sorted(candidates - sidecars):
        relative = path.relative_to(base).as_posix()
        digest = hashlib.sha256()
        if path in databases:
            connection = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True, timeout=5.0)
            try:
                connection.execute("PRAGMA query_only=ON")
                connection.execute("BEGIN")
                for statement in connection.iterdump():
                    digest.update(statement.encode("utf-8"))
                    digest.update(b"\n")
            finally:
                connection.close()
            files[relative] = {"kind": "sqlite-iterdump", "sha256": digest.hexdigest()}
        else:
            size = 0
            with path.open("rb") as file:
                for chunk in iter(lambda: file.read(1024 * 1024), b""):
                    digest.update(chunk)
                    size += len(chunk)
            files[relative] = {"kind": "bytes", "sha256": digest.hexdigest(), "bytes": size}
    fingerprint = hashlib.sha256(json.dumps(files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"schemaVersion": 1, "files": files, "fingerprint": fingerprint,
            "ignoredSQLiteSidecars": sorted(path.relative_to(base).as_posix() for path in candidates & sidecars)}
def compare_protected(before_snapshot, after_snapshot):
    if before_snapshot is None:
        return {"status": "NOT_APPLICABLE", "reason": "first-install", "missing": [], "changed": [],
                "added": sorted(after_snapshot["files"])}
    before_files, after_files = before_snapshot["files"], after_snapshot["files"]
    missing = sorted(set(before_files) - set(after_files))
    changed = sorted(name for name in set(before_files) & set(after_files) if before_files[name] != after_files[name])
    return {"status": "FAIL" if missing or changed else "PASS", "missing": missing, "changed": changed,
            "added": sorted(set(after_files) - set(before_files))}
before = apps().get(bundle)
before_data = simctl("get_app_container", udid, bundle, "data").decode().strip() if before else None
receipt = {
    "schemaVersion": 2, "targetUDID": udid, "targetName": matches[0]["name"],
    "appPath": str(app), "bundleIdentifier": bundle,
    "appReceiptSha256": hashlib.sha256(receipt_bytes).hexdigest(),
    "appBuild": document, "coreBuild": document["coreBuild"],
    "deploymentScriptSha256": hashlib.sha256((root / "scripts/deploy-simulator.sh").read_bytes()).hexdigest(),
    "installedBefore": package_metadata(before) if before else None,
    "installedAfter": None, "dataContainerBefore": before_data, "dataContainerAfter": None,
    "dataContainerMigrated": None, "dataPreservationPolicy": "protected-files-v1",
    "protectedDataBefore": None, "protectedDataAfter": None, "protectedDataComparison": None,
    "protectedDataPreserved": None,
    "preInstallVerification": "NOT_RUN", "install": "NOT_RUN",
    "postInstallVerification": "NOT_RUN", "launch": "NOT_RUN",
}
failure = None
try:
    before_snapshot = protected_snapshot(before_data) if before_data else None
    receipt["protectedDataBefore"] = before_snapshot
    receipt["preInstallVerification"] = "PASS"
    install_result = subprocess.run(["xcrun", "simctl", "install", udid, str(app)], capture_output=True, text=True)
    receipt["install"] = "PASS" if install_result.returncode == 0 else "FAIL"
    receipt["installExitCode"] = install_result.returncode
    receipt["installOutput"] = install_result.stdout.strip()
    receipt["installError"] = install_result.stderr.strip()
    if install_result.returncode != 0:
        failure = "Installation failed; no cleanup was attempted"
    else:
        after = apps().get(bundle)
        after_data = simctl("get_app_container", udid, bundle, "data").decode().strip() if after else None
        receipt["installedAfter"] = package_metadata(after) if after else None
        receipt["dataContainerAfter"] = after_data
        receipt["dataContainerMigrated"] = before_data != after_data if before_data and after_data else None
        after_snapshot = protected_snapshot(after_data) if after_data else None
        receipt["protectedDataAfter"] = after_snapshot
        comparison = compare_protected(before_snapshot, after_snapshot) if after_snapshot is not None else {
            "status": "FAIL", "reason": "missing-installed-data-container", "missing": [], "changed": [], "added": []}
        receipt["protectedDataComparison"] = comparison
        preserved = after is not None and comparison["status"] in ("PASS", "NOT_APPLICABLE")
        receipt["protectedDataPreserved"] = preserved if before_snapshot is not None else None
        receipt["postInstallVerification"] = "PASS" if preserved else "FAIL"
        if not preserved:
            failure = "Installation did not retain the protected data; launch was skipped and no cleanup was attempted"
        elif launch:
            launch_result = subprocess.run(["xcrun", "simctl", "launch", udid, bundle], capture_output=True, text=True)
            receipt["launch"] = "PASS" if launch_result.returncode == 0 else "FAIL"
            receipt["launchOutput"] = launch_result.stdout.strip()
            receipt["launchError"] = launch_result.stderr.strip()
            if launch_result.returncode != 0:
                failure = "Installation succeeded; requested launch failed"
except (OSError, RuntimeError, ValueError, sqlite3.Error, subprocess.CalledProcessError) as error:
    receipt["verificationError"] = str(error)
    if receipt["preInstallVerification"] != "PASS":
        receipt["preInstallVerification"] = "FAIL"
    elif receipt["install"] == "NOT_RUN":
        receipt["install"] = "FAIL"
    elif receipt["postInstallVerification"] == "NOT_RUN":
        receipt["postInstallVerification"] = "FAIL"
        receipt["protectedDataPreserved"] = False
        if receipt["protectedDataComparison"] is None:
            receipt["protectedDataComparison"] = {"status": "FAIL", "reason": "snapshot-unavailable"}
    elif launch and receipt["launch"] == "NOT_RUN":
        receipt["launch"] = "FAIL"
    failure = "Deployment failed; no cleanup was attempted: " + str(error)
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
path = root / ".build/deployments" / (stamp + ".json")
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(receipt, indent=2) + "\n")
print("Deployment receipt: " + str(path))
if failure:
    raise SystemExit(failure)
print("Installed " + bundle + " on " + udid + "; protected data comparison " + receipt["protectedDataComparison"]["status"])
PY
