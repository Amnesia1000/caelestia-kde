#!/usr/bin/env python3
"""Add a deterministic SHA-256 hash for an installed artifact tree."""

import hashlib
import json
import sys
from pathlib import Path


def root_hash(root: Path, excluded_prefixes: tuple[str, ...]) -> str:
    digest = hashlib.sha256()
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        relative = path.relative_to(root).as_posix()
        if relative == "share/caelestia/build-provenance.json":
            continue
        if any(relative.startswith(prefix) for prefix in excluded_prefixes):
            continue
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def update(metadata: Path, root: Path, excluded_prefixes: tuple[str, ...]) -> None:
    data = json.loads(metadata.read_text(encoding="utf-8"))
    data["artifact_root_hash"] = root_hash(root, excluded_prefixes)
    metadata.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit("usage: write_provenance_hash.py METADATA ARTIFACT_ROOT [EXCLUDED_PREFIX ...]")
    update(Path(sys.argv[1]), Path(sys.argv[2]), tuple(sys.argv[3:]))