#!/usr/bin/env python3
"""Summarize one caller-selected, stopped physical Reader container copy offline.

Uses the sibling physical-snapshot-files.py's single file scan. SQLite queries
only open private copies of each database and its recorded WAL/SHM; copied bytes
must match that scan before connecting. A final check of the known metadata tree
rejects ordinary input drift without another enumeration or full-file scan.

Output contains relative paths, structural table names, hashes, SQLite userVersion,
original Host operation IDs and boolean/null completion states. Paths and IDs may
identify private operations or book filenames; save the result privately. It emits no rows,
SQL, command payloads, absolute input paths or device IDs.
Missing completion remains null (unknown). No device, network or build tools run.
The caller's --stopped-copy assertion does not establish freshness or an atomic
snapshot. As with the file scanner, xattrs/ACLs and Keychain completeness are out
of scope, and a quiescent real copy is required.
"""

import argparse
from contextlib import contextmanager
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import secrets
import sqlite3
import stat
import sys


# Import the maintained sibling without creating __pycache__ in the workspace.
sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location(
    "_reader_physical_snapshot_files", Path(__file__).with_name("physical-snapshot-files.py"))
files = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = files
_spec.loader.exec_module(files)

MAIN_DATABASE = "Library/Application Support/Reader/Core/reader-core.sqlite3"
HOST_COMMANDS = "Library/Application Support/Reader/LocalSources/.operations/commands"
SQLITE_HEADER = b"SQLite format 3\x00"
# Deliberately ignore TMPDIR/TEMP/TMP: they may point into the evidence copy.
SQLITE_TEMP_PARENT = Path("/tmp")


def canonical(value):
    # Match existing semantic evidence: BLOBs are typed hex objects, and rows
    # are sorted by their canonical JSON instead of relying on SQLite row order.
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"),
                      default=lambda v: {"blobHex": v.hex()} if isinstance(v, bytes) else str(v))


def digest(value):
    return hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def relative_parts(value):
    parts = tuple(value.split("/"))
    if any(part in ("", ".", "..") for part in parts):
        raise files.SnapshotError("expected a relative path with no dot components")
    return parts


class ScannedCopy:
    """One held root descriptor and the shared scanner's retained metadata tree."""

    def __init__(self, root, bundle):
        self.root = Path(root).expanduser()
        if not files.BUNDLE_PATTERN.fullmatch(bundle):
            raise files.SnapshotError("invalid bundle identifier")
        self.source = os.lstat(self.root)
        files.check_node(self.source)
        if not stat.S_ISDIR(self.source.st_mode):
            raise files.SnapshotError("container copy must be a directory")
        self.descriptor = os.open(self.root, files.directory_flags())
        try:
            files.require_same(self.source, os.fstat(self.descriptor))
            for name in ("Documents", "Library"):
                node = os.stat(name, dir_fd=self.descriptor, follow_symlinks=False)
                files.check_node(node)
                if not stat.S_ISDIR(node.st_mode):
                    raise files.SnapshotError("select the copied data root containing Documents and Library")
            self.all_files, self.protected_files = {}, {}
            self.tree = files.walk(self.descriptor, (), bundle,
                                   self.all_files, self.protected_files)
            self.check_unchanged()
        except BaseException:
            os.close(self.descriptor)
            raise

    def close(self):
        os.close(self.descriptor)

    def check_unchanged(self):
        files.check_known_entries(self.descriptor, self.tree)
        files.require_same(self.source, os.lstat(self.root))

    def require_command_directory(self, relative):
        tree = self.tree
        for part in relative_parts(relative):
            if part not in tree.directories:
                raise files.SnapshotError("Host command directory is missing from the scanned copy")
            tree = tree.directories[part]
        with self.parent(relative) as (parent, name, _):
            try:
                observed = os.stat(name, dir_fd=parent, follow_symlinks=False)
            except FileNotFoundError:
                raise files.SnapshotError("Host command directory disappeared after the file scan") from None
            files.check_node(observed)
            files.require_signature(tree.signature, observed)

    @contextmanager
    def parent(self, relative):
        parts = relative_parts(relative)
        descriptor = os.dup(self.descriptor)
        tree = self.tree
        try:
            for part in parts[:-1]:
                if part not in tree.directories:
                    raise files.SnapshotError("path parent was not present in the file scan")
                tree = tree.directories[part]
                observed = os.stat(part, dir_fd=descriptor, follow_symlinks=False)
                files.check_node(observed)
                files.require_signature(tree.signature, observed)
                child = files.open_directory(descriptor, part, observed)
                os.close(descriptor)
                descriptor = child
            yield descriptor, parts[-1], tree
        finally:
            os.close(descriptor)

    @contextmanager
    def opened_file(self, relative):
        if relative not in self.all_files:
            raise files.SnapshotError("file was not present in the file scan")
        with self.parent(relative) as (parent, name, tree):
            expected = tree.files.get(name)
            observed = os.stat(name, dir_fd=parent, follow_symlinks=False)
            files.check_node(observed)
            files.require_signature(expected, observed)
            descriptor = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                                 dir_fd=parent)
            try:
                files.require_signature(expected, os.fstat(descriptor))
                yield descriptor
                files.require_signature(expected, os.fstat(descriptor))
                files.require_signature(expected,
                                        os.stat(name, dir_fd=parent, follow_symlinks=False))
            finally:
                os.close(descriptor)

    def header(self, relative):
        with self.opened_file(relative) as descriptor:
            return os.read(descriptor, len(SQLITE_HEADER))

    def copy_verified(self, relative, output):
        expected = self.all_files[relative]
        sha = hashlib.sha256()
        size = 0
        with self.opened_file(relative) as descriptor:
            while size < expected["bytes"]:
                chunk = os.read(descriptor, min(files.CHUNK_BYTES, expected["bytes"] - size))
                if not chunk:
                    break
                size += len(chunk)
                sha.update(chunk)
                output.write(chunk)
            if os.read(descriptor, 1):
                raise files.SnapshotError("file grew after the file scan")
        if {"bytes": size, "sha256": sha.hexdigest()} != expected:
            raise files.SnapshotError("bytes no longer match the file scan")

    def family(self, database):
        result = []
        for suffix in ("", "-wal", "-shm"):
            relative = database + suffix
            if relative in self.all_files:
                result.append(relative)
                continue
            if not suffix:
                raise files.SnapshotError("main database is missing from the file scan")
            # Absence is also bound: a WAL/SHM introduced after the scan cannot
            # silently be omitted from the private database family.
            with self.parent(relative) as (parent, name, _):
                try:
                    os.stat(name, dir_fd=parent, follow_symlinks=False)
                except FileNotFoundError:
                    continue
                raise files.SnapshotError("database companion appeared after the file scan")
        return result


@contextmanager
def sqlite_temporary(snapshot):
    """Create and clean only our own directory through a verified outside FD."""
    parent_path = SQLITE_TEMP_PARENT.resolve(strict=True)
    parent_before = os.lstat(parent_path)
    files.check_node(parent_before)
    parent = os.open(parent_path, files.directory_flags())
    temporary = None
    descriptor = None
    created = None
    try:
        files.require_same(parent_before, os.fstat(parent))
        files.check_output_ancestry(parent, snapshot.source)
        for _ in range(4):
            candidate = "reader-physical-sqlite-" + secrets.token_hex(12)
            try:
                # Held parent FD prevents a pathname alias from redirecting
                # this mkdir into the source after the ancestry check.
                os.mkdir(candidate, 0o700, dir_fd=parent)
                temporary = candidate
                break
            except FileExistsError:
                continue
        if temporary is None:
            raise files.SnapshotError("could not create a private SQLite copy directory")
        created = os.stat(temporary, dir_fd=parent, follow_symlinks=False)
        descriptor = files.open_directory(parent, temporary, created)
        files.check_output_ancestry(descriptor, snapshot.source)
        yield parent_path / temporary, descriptor
    finally:
        try:
            if temporary is not None:
                if created is None:
                    raise files.SnapshotError("private SQLite directory was not verified")
                if descriptor is not None:
                    for name in os.listdir(descriptor):
                        os.unlink(name, dir_fd=descriptor)
                observed = os.stat(temporary, dir_fd=parent, follow_symlinks=False)
                if (observed.st_dev, observed.st_ino) != (created.st_dev, created.st_ino):
                    raise files.SnapshotError("private SQLite directory identity changed")
                os.rmdir(temporary, dir_fd=parent)
        finally:
            if descriptor is not None:
                os.close(descriptor)
            os.close(parent)


def private_file_record(name, parent):
    sha = hashlib.sha256()
    size = 0
    descriptor = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent)
    with os.fdopen(descriptor, "rb") as source:
        while True:
            chunk = source.read(files.CHUNK_BYTES)
            if not chunk:
                break
            size += len(chunk)
            sha.update(chunk)
    return {"bytes": size, "sha256": sha.hexdigest()}


def database_facts(snapshot, relative):
    members = snapshot.family(relative)
    with sqlite_temporary(snapshot) as (directory, private):
        for member in members:
            copied = member.rsplit("/", 1)[-1]
            descriptor = os.open(copied, os.O_WRONLY | os.O_CREAT | os.O_EXCL
                                 | os.O_NOFOLLOW, 0o600, dir_fd=private)
            with os.fdopen(descriptor, "wb") as output:
                snapshot.copy_verified(member, output)
            if private_file_record(copied, private) != snapshot.all_files[member]:
                raise files.SnapshotError("private database copy does not match the file scan")
        copied_database = directory / relative.rsplit("/", 1)[-1]
        actual = os.lstat(directory)
        held = os.fstat(private)
        if (actual.st_dev, actual.st_ino) != (held.st_dev, held.st_ino):
            raise files.SnapshotError("private SQLite path identity changed")
        files.check_output_ancestry(private, snapshot.source)
        connection = sqlite3.connect(copied_database.as_uri() + "?mode=ro", uri=True)
        try:
            # SQLite's own temporary sort storage must not follow TMPDIR either.
            connection.execute("PRAGMA temp_store=MEMORY")
            connection.execute("PRAGMA query_only=ON")
            connection.execute("BEGIN")
            schema = [list(row) for row in connection.execute(
                "select type,name,tbl_name,sql from sqlite_master order by type,name")]
            tables = {}
            for kind, name, _, _ in schema:
                if kind != "table":
                    continue
                quoted = '"' + name.replace('"', '""') + '"'
                columns = [row[1] for row in connection.execute("pragma table_info(" + quoted + ")")]
                rows = sorted([list(row) for row in connection.execute("select * from " + quoted)],
                              key=canonical)
                tables[name] = digest({"columns": columns, "rows": rows})
            return {"userVersion": connection.execute("pragma user_version").fetchone()[0],
                    "schemaSHA256": digest(schema), "tables": tables}
        finally:
            connection.close()


def command_record(payload):
    record = json.loads(payload)
    if not isinstance(record, dict) or not isinstance(record.get("id"), str) or not record["id"]:
        raise files.SnapshotError("Host command must have a nonempty string id")
    completed = record.get("completed")
    if completed is not None and not isinstance(completed, bool):
        raise files.SnapshotError("Host completion must be boolean or null")
    return record["id"], completed


def summarize(snapshot, main_database, command_directory):
    relative_parts(main_database)
    relative_parts(command_directory)
    snapshot.require_command_directory(command_directory)
    if main_database not in snapshot.protected_files:
        raise files.SnapshotError("main database must be a protected file in this copy")
    databases = {relative for relative in snapshot.protected_files
                 if snapshot.header(relative) == SQLITE_HEADER}
    if main_database not in databases:
        raise files.SnapshotError("main database does not have the SQLite header")
    facts = {relative: database_facts(snapshot, relative) for relative in sorted(databases)}
    families = {relative + suffix for relative in databases for suffix in ("", "-wal", "-shm")}
    commands, identities = {}, set()
    prefix = command_directory + "/"
    for relative in sorted(snapshot.all_files):
        if not relative.startswith(prefix):
            continue
        payload = io.BytesIO()
        snapshot.copy_verified(relative, payload)
        identity, completed = command_record(payload.getvalue())
        if identity in identities:
            raise files.SnapshotError("duplicate Host command id")
        identities.add(identity)
        commands[identity] = {"sha256": snapshot.all_files[relative]["sha256"],
                              "completed": completed}
    snapshot.check_unchanged()
    return {"schemaVersion": 1, "mainDB": facts[main_database],
            "sidecarDBs": {relative: value for relative, value in facts.items()
                           if relative != main_database},
            "protectedNonSQLiteFiles": {relative: record
                                        for relative, record in snapshot.protected_files.items()
                                        if relative not in families},
            "hostCommands": commands}


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--container-copy", type=Path, required=True)
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--stopped-copy", action="store_true", required=True,
                        help="caller attests this is a real stopped-device copy")
    parser.add_argument("--main-database", default=MAIN_DATABASE,
                        help="main SQLite path relative to the copied container")
    parser.add_argument("--commands", default=HOST_COMMANDS,
                        help="existing Host command directory relative to the copied container")
    parser.add_argument("--output", default="-",
                        help="new private JSON file outside the copy, or - for stdout")
    arguments = parser.parse_args()
    snapshot = None
    try:
        root = arguments.container_copy.expanduser()
        destination = files.output_path(arguments.output, root)
        snapshot = ScannedCopy(root, arguments.bundle)
        document = summarize(snapshot, arguments.main_database, arguments.commands)
        if destination is not None:
            destination = files.output_path(arguments.output, root)
        snapshot.check_unchanged()
        files.emit(document, destination, snapshot.source)
    except files.SnapshotError as error:
        parser.exit(1, "STOP: " + str(error) + "\n")
    except OSError as error:
        parser.exit(1, "STOP: filesystem operation failed (errno " + str(error.errno) + ")\n")
    except sqlite3.Error:
        parser.exit(1, "STOP: SQLite summary query failed\n")
    except (ValueError, UnicodeError):
        parser.exit(1, "STOP: invalid structured input in copied evidence\n")
    finally:
        if snapshot is not None:
            snapshot.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
