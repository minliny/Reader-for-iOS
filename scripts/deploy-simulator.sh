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
      echo 'Overwrites only the named, already booted simulator App and preserves its data container.'
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
before = apps().get(bundle)
before_data = simctl("get_app_container", udid, bundle, "data").decode().strip() if before else None
receipt = {
    "schemaVersion": 2, "targetUDID": udid, "targetName": matches[0]["name"],
    "appPath": str(app), "bundleIdentifier": bundle,
    "appReceiptSha256": hashlib.sha256(receipt_bytes).hexdigest(),
    "appBuild": document, "coreBuild": document["coreBuild"],
    "installedBefore": package_metadata(before) if before else None,
    "installedAfter": None, "dataContainerBefore": before_data, "dataContainerAfter": None,
    "dataContainerPreserved": None, "install": "NOT_RUN",
    "postInstallVerification": "NOT_RUN", "launch": "NOT_RUN",
}
failure = None
try:
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
        preserved = after is not None and (before_data is None or before_data == after_data)
        receipt["installedAfter"] = package_metadata(after) if after else None
        receipt["dataContainerAfter"] = after_data
        receipt["dataContainerPreserved"] = preserved
        receipt["postInstallVerification"] = "PASS" if preserved else "FAIL"
        if not preserved:
            failure = "Installation did not retain the expected package/data container; no cleanup was attempted"
        elif launch:
            launch_result = subprocess.run(["xcrun", "simctl", "launch", udid, bundle], capture_output=True, text=True)
            receipt["launch"] = "PASS" if launch_result.returncode == 0 else "FAIL"
            receipt["launchOutput"] = launch_result.stdout.strip()
            receipt["launchError"] = launch_result.stderr.strip()
            if launch_result.returncode != 0:
                failure = "Installation succeeded; requested launch failed"
except (OSError, ValueError, subprocess.CalledProcessError) as error:
    receipt["verificationError"] = str(error)
    if receipt["install"] == "NOT_RUN":
        receipt["install"] = "FAIL"
    elif receipt["postInstallVerification"] == "NOT_RUN":
        receipt["postInstallVerification"] = "FAIL"
    failure = "Deployment failed; no cleanup was attempted: " + str(error)
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
path = root / ".build/deployments" / (stamp + ".json")
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(receipt, indent=2) + "\n")
print("Deployment receipt: " + str(path))
if failure:
    raise SystemExit(failure)
print("Installed " + bundle + " on " + udid + "; data container preserved")
PY
