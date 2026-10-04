#!/usr/bin/env python3
"""Compare two installed artifact trees by relative paths and SHA-256 hashes."""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def files_under(root: Path) -> dict[str, Path]:
    return {
        path.relative_to(root).as_posix(): path
        for path in root.rglob("*")
        if path.is_file()
    }


def compare_trees(
    left: Path,
    right: Path,
    allowed_right_only: set[str] | None = None,
    allowed_right_only_prefixes: set[str] | None = None,
) -> list[str]:
    """Return parity failures, allowing explicitly documented right-only files."""
    allowed = allowed_right_only or set()
    allowed_prefixes = allowed_right_only_prefixes or set()
    left_files = files_under(left)
    right_files = files_under(right)
    failures: list[str] = []

    for relative in sorted(left_files.keys() - right_files.keys()):
        failures.append(f"missing from right tree: {relative}")
    for relative in sorted(right_files.keys() - left_files.keys() - allowed):
        if any(relative == prefix or relative.startswith(f"{prefix}/") for prefix in allowed_prefixes):
            continue
        failures.append(f"unexpected in right tree: {relative}")
    for relative in sorted(left_files.keys() & right_files.keys()):
        left_hash = file_hash(left_files[relative])
        right_hash = file_hash(right_files[relative])
        if left_hash != right_hash:
            failures.append(f"hash mismatch: {relative} ({left_hash} != {right_hash})")
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("left", type=Path, help="source/reference tree")
    parser.add_argument("right", type=Path, help="package/release tree")
    parser.add_argument(
        "--allow-right-only",
        action="append",
        default=[],
        metavar="PATH",
        help="right-only relative path allowed by the packaging contract (repeatable)",
    )
    parser.add_argument(
        "--allow-right-only-prefix",
        action="append",
        default=[],
        metavar="PATH",
        help="right-only relative path prefix allowed by the packaging contract (repeatable)",
    )
    args = parser.parse_args(argv)

    for root in (args.left, args.right):
        if not root.is_dir():
            print(f"artifact tree is not a directory: {root}", file=sys.stderr)
            return 2

    failures = compare_trees(
        args.left,
        args.right,
        set(args.allow_right_only),
        set(args.allow_right_only_prefix),
    )
    if failures:
        print("Artifact parity check failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(f"Artifact parity check passed: {args.left} == {args.right}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())