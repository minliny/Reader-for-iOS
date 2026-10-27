#!/usr/bin/env python3
"""Hash one caller-selected, stopped iPhone data-container copy, offline.

Example (the output's existing parent must be outside the input container):
  python3 physical-snapshot-files.py --container-copy /private/tmp/run/container \
    --bundle io.reader.minliny.free --stopped-copy --output /private/tmp/run/files.private.json

Each regular file is read once, in chunks. The same record populates allFiles
and, when applicable, protectedFiles. Paths keep their original relative spelling;
JSON escaping is lossless, including filesystem names decoded with surrogateescape.
No file contents, database rows, absolute source paths, or device IDs are emitted.

The caller must establish that this is a real, stopped-device copy. This tool
does not connect to a device or prove freshness, device state, or an atomic
point-in-time snapshot. It rejects links/special nodes and checks identities,
sizes, modes, mtimes and ctimes before/after reading and again before output.
The final check uses the already known entries; it neither enumerates directories
again nor rereads contents. Ordinary concurrent changes cause failure, but these
checks cannot replace a quiescent copy or detect every adversarial metadata reset.
Only data-fork file bytes are covered, not xattrs, ACLs or Keychain completeness.
Reading may cause filesystem-managed access-time updates.
"""

import argparse
from dataclasses import dataclass, field
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys


CHUNK_BYTES = 1024 * 1024
BUNDLE_PATTERN = re.compile(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\Z")


class SnapshotError(RuntimeError):
    """A safe diagnostic containing no evidence contents or private names."""


@dataclass
class Directory:
    signature: tuple
    files: dict = field(default_factory=dict)
    directories: dict = field(default_factory=dict)


def signature(value):
    # Exclude access time: a read can update it without changing the evidence.
    return (value.st_dev, value.st_ino, value.st_mode, value.st_nlink,
            value.st_size, value.st_mtime_ns, value.st_ctime_ns)


def require_same(expected, actual):
    if signature(expected) != signature(actual):
        raise SnapshotError("input identity or metadata changed during snapshot")


def require_signature(expected, actual):
    if expected != signature(actual):
        raise SnapshotError("input identity or metadata changed during snapshot")


def check_node(value):
    if stat.S_ISLNK(value.st_mode):
        raise SnapshotError("symbolic links are not accepted")
    if not (stat.S_ISDIR(value.st_mode) or stat.S_ISREG(value.st_mode)):
        raise SnapshotError("only directories and regular files are accepted")


def directory_flags():
    return os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def open_directory(parent_fd, name, expected):
    descriptor = os.open(name, directory_flags(), dir_fd=parent_fd)
    try:
        require_same(expected, os.fstat(descriptor))
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def file_record(parent_fd, name, expected):
    # NONBLOCK also prevents blocking if a regular file is raced into a FIFO.
    descriptor = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                         dir_fd=parent_fd)
    try:
        opened = os.fstat(descriptor)
        if not stat.S_ISREG(opened.st_mode):
            raise SnapshotError("only regular files may be hashed")
        require_same(expected, opened)
        digest = hashlib.sha256()
        read_bytes = 0
        while read_bytes < opened.st_size:
            chunk = os.read(descriptor, min(CHUNK_BYTES, opened.st_size - read_bytes))
            if not chunk:
                break
            read_bytes += len(chunk)
            digest.update(chunk)
        if os.read(descriptor, 1):
            raise SnapshotError("file grew during snapshot")
        require_same(opened, os.fstat(descriptor))
        require_same(opened, os.stat(name, dir_fd=parent_fd, follow_symlinks=False))
        if read_bytes != opened.st_size:
            raise SnapshotError("file size changed during snapshot")
        return {"bytes": read_bytes, "sha256": digest.hexdigest()}
    finally:
        os.close(descriptor)


def is_protected(relative, bundle):
    return (relative.startswith("Documents/")
            or relative.startswith("Library/Application Support/")
            or relative == "Library/Preferences/" + bundle + ".plist")


def walk(descriptor, parts, bundle, all_files, protected_files):
    before = os.fstat(descriptor)
    node = Directory(signature(before))
    for name in sorted(os.listdir(descriptor)):
        observed = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
        check_node(observed)
        child_parts = parts + (name,)
        if stat.S_ISDIR(observed.st_mode):
            child = open_directory(descriptor, name, observed)
            try:
                node.directories[name] = walk(child, child_parts, bundle,
                                              all_files, protected_files)
            finally:
                os.close(child)
            require_same(observed, os.stat(name, dir_fd=descriptor,
                                           follow_symlinks=False))
        else:
            relative = "/".join(child_parts)
            record = file_record(descriptor, name, observed)
            all_files[relative] = record
            if is_protected(relative, bundle):
                protected_files[relative] = record
            node.files[name] = signature(observed)
    require_same(before, os.fstat(descriptor))
    return node


def check_known_entries(descriptor, node):
    """Recheck recorded metadata, without a second enumeration or content read."""
    require_signature(node.signature, os.fstat(descriptor))
    for name, expected in node.files.items():
        observed = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
        check_node(observed)
        require_signature(expected, observed)
    for name, child_node in node.directories.items():
        observed = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
        check_node(observed)
        require_signature(child_node.signature, observed)
        child = open_directory(descriptor, name, observed)
        try:
            check_known_entries(child, child_node)
        finally:
            os.close(child)
        require_signature(child_node.signature,
                          os.stat(name, dir_fd=descriptor, follow_symlinks=False))
    # Adding/removing/renaming entries updates directory mtime/ctime.
    require_signature(node.signature, os.fstat(descriptor))


def snapshot_files(root, bundle):
    if not BUNDLE_PATTERN.fullmatch(bundle):
        raise SnapshotError("bundle must be a dot-separated bundle identifier")
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        raise SnapshotError("this platform lacks no-follow directory support")
    root = Path(root).expanduser()
    observed = os.lstat(root)
    check_node(observed)
    if not stat.S_ISDIR(observed.st_mode):
        raise SnapshotError("container copy must be a directory")
    descriptor = os.open(root, directory_flags())
    try:
        require_same(observed, os.fstat(descriptor))
        for name in ("Documents", "Library"):
            required = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
            check_node(required)
            if not stat.S_ISDIR(required.st_mode):
                raise SnapshotError("select the copied data root containing Documents and Library")
        all_files, protected_files = {}, {}
        tree = walk(descriptor, (), bundle, all_files, protected_files)
        check_known_entries(descriptor, tree)
        require_same(observed, os.lstat(root))
        return {"schemaVersion": 1,
                "sourceKind": "caller-asserted-stopped-physical-container-copy",
                "bundleIdentifier": bundle,
                "allFiles": all_files, "protectedFiles": protected_files}
    finally:
        os.close(descriptor)


def output_path(argument, root):
    if argument == "-":
        return None
    destination = Path(argument).expanduser()
    if destination.is_symlink():
        raise SnapshotError("output must not be a symbolic link")
    # Reject a destination in the source, including a symlinked parent alias.
    source_real = root.resolve(strict=True)
    destination_real = destination.resolve(strict=False)
    if destination_real == source_real or source_real in destination_real.parents:
        raise SnapshotError("output must be outside the input container")
    if destination.exists():
        raise SnapshotError("output already exists; choose a new private result path")
    return destination_real


def check_output_ancestry(parent_fd, source):
    # Check the opened directory, not just its pathname: a raced ancestor
    # symlink must not redirect the only write into the evidence tree.
    current = os.dup(parent_fd)
    try:
        while True:
            observed = os.fstat(current)
            identity = (observed.st_dev, observed.st_ino)
            if identity == (source.st_dev, source.st_ino):
                raise SnapshotError("output must be outside the input container")
            parent = os.open("..", directory_flags(), dir_fd=current)
            parent_stat = os.fstat(parent)
            if identity == (parent_stat.st_dev, parent_stat.st_ino):
                os.close(parent)
                break
            os.close(current)
            current = parent
    finally:
        os.close(current)


def emit(document, destination, source):
    payload = (json.dumps(document, ensure_ascii=True, sort_keys=True,
                          separators=(",", ":")) + "\n").encode("ascii")
    if destination is None:
        sys.stdout.buffer.write(payload)
        return
    # Exclusive creation prevents overwriting an evidence file or following a
    # destination link introduced after validation. No directory is created.
    parent_before = os.lstat(destination.parent)
    check_node(parent_before)
    parent_fd = os.open(destination.parent, directory_flags())
    try:
        require_same(parent_before, os.fstat(parent_fd))
        check_output_ancestry(parent_fd, source)
        descriptor = os.open(destination.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL
                             | os.O_NOFOLLOW, 0o600, dir_fd=parent_fd)
        with os.fdopen(descriptor, "wb") as output:
            output.write(payload)
    finally:
        os.close(parent_fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--container-copy", type=Path, required=True,
                        help="real stopped-device data copy containing Documents and Library")
    parser.add_argument("--bundle", required=True,
                        help="exact bundle whose Preferences plist is protected")
    parser.add_argument("--stopped-copy", action="store_true", required=True,
                        help="caller attests the supplied path is a real stopped-device copy")
    parser.add_argument("--output", default="-",
                        help="new private JSON file outside the copy, or - for stdout (default)")
    arguments = parser.parse_args()
    try:
        arguments.container_copy = arguments.container_copy.expanduser()
        source = os.lstat(arguments.container_copy)
        destination = output_path(arguments.output, arguments.container_copy)
        document = snapshot_files(arguments.container_copy, arguments.bundle)
        require_same(source, os.lstat(arguments.container_copy))
        # Recheck containment immediately before the only write operation.
        if destination is not None:
            destination = output_path(arguments.output, arguments.container_copy)
        emit(document, destination, source)
    except SnapshotError as error:
        parser.exit(1, "STOP: " + str(error) + "\n")
    except OSError as error:
        # OSError's normal text can include a private filename. Keep diagnostics
        # useful without sending names or source contents to a shared log.
        parser.exit(1, "STOP: filesystem operation failed (errno "
                    + str(error.errno) + ")\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
