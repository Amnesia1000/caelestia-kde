#!/usr/bin/env python3
"""Recent documents, optionally only the ones a given application opened.

`recently-used.xbel` is the freedesktop list every toolkit writes to and Plasma's own
recent-documents runner reads, so the dock's jump list can show the same files. Each
bookmark records which applications opened it, which is what makes a per-application
list possible at all.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ElementTree
from urllib.parse import unquote, urlparse
from urllib.request import url2pathname

BOOKMARK = "{http://www.freedesktop.org/standards/desktop-bookmarks}"
MIME = "{http://www.freedesktop.org/standards/shared-mime-info}"


def recent_file() -> str:
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(base, "recently-used.xbel")


def normalise(name: str) -> str:
    """`org.kde.spectacle.desktop` and `org.kde.spectacle` name the same application."""
    name = name.strip()
    if name.endswith(".desktop"):
        name = name[: -len(".desktop")]
    return name.lower()


def short_name(name: str) -> str:
    return normalise(name).rsplit(".", 1)[-1]


def matches(app: str, targets: set) -> bool:
    return normalise(app) in targets or short_name(app) in targets


def parse(path: str) -> list:
    if not os.path.exists(path):
        return []

    try:
        root = ElementTree.parse(path).getroot()
    except ElementTree.ParseError:
        return []

    entries = []
    for bookmark in root.iter("bookmark"):
        href = bookmark.get("href", "")
        if not href.startswith("file://"):
            continue

        file_path = url2pathname(unquote(urlparse(href).path))
        if not os.path.isfile(file_path):
            continue

        applications = [element.get("name", "") for element in bookmark.iter(f"{BOOKMARK}application")]
        mime = bookmark.find(f".//{MIME}mime-type")
        entries.append(
            {
                "name": os.path.basename(file_path),
                "path": file_path,
                "uri": href,
                "mime": mime.get("type", "") if mime is not None else "",
                "modified": bookmark.get("modified", ""),
                "apps": [app for app in applications if app],
            }
        )

    # A file opened five times is still one row in a jump list; the newest visit wins.
    seen = {}
    for entry in entries:
        known = seen.get(entry["path"])
        if known is None or entry["modified"] > known["modified"]:
            seen[entry["path"]] = entry
    ordered = sorted(seen.values(), key=lambda entry: entry["modified"], reverse=True)
    return ordered


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=10, help="how many entries to print")
    parser.add_argument("--app", action="append", default=[], help="only files this application opened")
    parser.add_argument("--file", help="read this xbel file instead of the user's")
    args = parser.parse_args()

    entries = parse(args.file or recent_file())

    if args.app:
        targets = {normalise(name) for name in args.app} | {short_name(name) for name in args.app}
        entries = [entry for entry in entries if any(matches(app, targets) for app in entry["apps"])]

    print(json.dumps(entries[: max(0, args.limit)]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
