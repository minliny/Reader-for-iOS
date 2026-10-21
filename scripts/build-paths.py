#!/usr/bin/env python3
"""Resolve canonical iOS build outputs outside the workspace/FileProvider."""

import argparse
import hashlib
import os
from pathlib import Path
import subprocess

IOS_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = IOS_ROOT.parent


def build_root():
    key = hashlib.sha256(str(IOS_ROOT).encode("utf-8")).hexdigest()[:16]
    configured = os.environ.get("READER_IOS_BUILD_ROOT")
    if configured is not None and not configured.strip():
        raise RuntimeError("READER_IOS_BUILD_ROOT must be an absolute nonempty path")
    raw = Path(configured).expanduser() if configured is not None else Path.home() / "Library/Caches/Reader-iOS" / key
    if not raw.is_absolute():
        raise RuntimeError("READER_IOS_BUILD_ROOT must be absolute")
    root = raw.resolve()
    excluded = [WORKSPACE, Path.home() / "Documents", Path.home() / "Desktop",
                Path.home() / "Library/CloudStorage", Path.home() / "Library/Mobile Documents"]
    if any(root == base.resolve() or base.resolve() in root.parents for base in excluded):
        raise RuntimeError("iOS build outputs must be outside the workspace and FileProvider locations")
    # A caller may configure another provider's path. Inspect existing ancestor
    # metadata through Apple's tool; no user files/attributes are changed.
    for ancestor in [root, *root.parents]:
        if not ancestor.exists():
            continue
        attributes = subprocess.run(["/usr/bin/xattr", str(ancestor)], capture_output=True, text=True)
        if attributes.returncode:
            raise RuntimeError("Cannot verify the configured build output location: " + str(ancestor))
        if any(name.startswith("com.apple.fileprovider.") for name in attributes.stdout.splitlines()):
            raise RuntimeError("iOS build output is inside a FileProvider location: " + str(ancestor))
    return root


def path_for(kind):
    root = build_root()
    names = {"root": "", "app-derived": "AppDerivedData", "test-derived": "TestDerivedData", "artifacts": "app-artifacts"}
    return root / names[kind] if names[kind] else root


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", required=True, choices=["root", "app-derived", "test-derived", "artifacts"])
    args = parser.parse_args()
    try:
        print(path_for(args.kind))
    except (OSError, RuntimeError) as error:
        raise SystemExit("iOS build path selection failed: " + str(error))
