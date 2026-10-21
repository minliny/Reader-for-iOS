#!/usr/bin/env python3
"""Verify Xcode's actual Simulator entitlement section and ad-hoc signature."""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess


def command(args):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode:
        raise RuntimeError(Path(args[0]).name + ": " + result.stderr.strip())
    return result.stdout


def verify(app, bundle_id):
    app = Path(app).resolve(strict=True)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != bundle_id or "iPhoneSimulator" not in info.get("CFBundleSupportedPlatforms", []):
        raise RuntimeError("Expected the requested Simulator App bundle")
    executable = info.get("CFBundleExecutable")
    if not isinstance(executable, str) or not executable or Path(executable).name != executable:
        raise RuntimeError("Invalid App executable identity")
    binary = app / executable
    # Apple otool parses Mach-O; this adapter reads its reported section bytes.
    # codesign's ordinary entitlement slot alone does not establish the
    # __TEXT,__entitlements that Simulator securityd actually consumes.
    load_commands = command(["xcrun", "otool", "-arch", "arm64", "-l", str(binary)])
    sections = re.findall(r"sectname\s+__entitlements\b(.*?)(?=sectname|Load command|\Z)", load_commands, re.S)
    sections = [section for section in sections if re.search(r"segname\s+__TEXT\b", section)]
    if len(sections) != 1:
        raise RuntimeError("Expected one actual arm64 Simulator entitlement section")
    size = re.search(r"\bsize\s+(0x[0-9a-fA-F]+|[0-9]+)", sections[0])
    offset = re.search(r"\boffset\s+([0-9]+)", sections[0])
    if size is None or offset is None:
        raise RuntimeError("Apple otool did not report the entitlement section bounds")
    size, offset = int(size.group(1), 0), int(offset.group(1))
    if not 0 < size <= 65_536 or offset < 0 or offset + size > binary.stat().st_size:
        raise RuntimeError("Invalid Simulator entitlement section bounds")
    with binary.open("rb") as stream:
        stream.seek(offset)
        raw = stream.read(size)
    entitlements = plistlib.loads(raw.rstrip(b"\0"))
    if not isinstance(entitlements, dict):
        raise RuntimeError("Simulator entitlements are not a property-list dictionary")
    application_id = entitlements.get("application-identifier")
    groups = entitlements.get("keychain-access-groups")
    if (not isinstance(application_id, str) or "$" in application_id
            or not (application_id == bundle_id or application_id.endswith("." + bundle_id))):
        raise RuntimeError("The actual simulated application identifier does not match the App")
    if (not isinstance(groups, list) or not groups or groups[0] != application_id
            or any(not isinstance(group, str) or not group or "$" in group for group in groups)):
        raise RuntimeError("The actual Simulator App lacks its default Keychain access group")
    command(["/usr/bin/codesign", "--verify", "--strict", str(app)])
    return {"status": "PASS", "bundleIdentifier": bundle_id, "architecture": "arm64",
            "simulatedEntitlementsSha256": hashlib.sha256(raw).hexdigest(),
            "keychainAccessGroupCount": len(groups), "signatureVerified": True}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True)
    parser.add_argument("--bundle-id", default="io.reader.minliny")
    arguments = parser.parse_args()
    try:
        print(json.dumps(verify(arguments.app, arguments.bundle_id), sort_keys=True))
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit("Simulator identity verification failed: " + str(error))
