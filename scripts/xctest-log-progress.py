#!/usr/bin/env python3
"""Count completed XCTest progress lines without exposing their contents.

This reads an existing Xcode text log only. A zero count means no standard
entry line was observed; it is not a test result or proof that XCTest is idle.
"""

import argparse
import json
from pathlib import Path


def entry_count(log):
    count = 0
    with log.open("rb") as stream:
        for line in stream:
            line = line.rstrip(b"\r\n")
            if line.startswith(b"Test Case ") and line.endswith(b" started."):
                count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True, help="Existing Xcode text log")
    arguments = parser.parse_args()
    try:
        count = entry_count(arguments.log)
    except OSError:
        parser.exit(2, "Cannot read the Xcode log.\n")
    print(json.dumps({"status": "ENTRY_OBSERVED" if count else "NO_ENTRY_OBSERVED",
                      "startedLines": count, "testResult": "NOT_ASSESSED"}))


if __name__ == "__main__":
    main()
