#!/usr/bin/env python3

from __future__ import annotations

import hashlib
from collections.abc import Iterable
from pathlib import Path

PACKAGE_ONLY_PREFIXES = (
    "etc/xdg/quickshell/caelestia/assets/icons",
    "usr/share/plasma/shells/caelestia.desktop",
    "usr/share/sddm/themes/caelestia",
)

COMPILED_SUFFIXES = (".so", ".dylib", ".dll")

PROVENANCE_RELATIVE = "usr/share/caelestia/build-provenance.json"


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


def matches_prefix(relative: str, prefixes: Iterable[str]) -> bool:
    return any(
        relative == prefix or relative.startswith(f"{prefix}/")
        for prefix in prefixes
    )


def is_package_only(relative: str) -> bool:
    return matches_prefix(relative, PACKAGE_ONLY_PREFIXES)


def is_compiled(relative: str) -> bool:
    return relative.endswith(COMPILED_SUFFIXES)
