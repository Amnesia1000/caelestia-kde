#!/usr/bin/env python3
"""The filesystems the Storage page can act on, as JSON.

`lsblk` is the source, because it is what udisks and GNOME Disks read as well. The
decision about what is worth showing is made here rather than in QML so it can be
tested: loop devices, zram, swap and device-mapper internals are not something anyone
mounts by hand, and every partition of a disk inherits the disk's model and whether it
can be pulled out.

A filesystem mounted at a path the system needs is reported as `system`, so the page can
show it without offering to unmount it: unmounting `/` is not a thing a settings page
should be one click away from.
"""
from __future__ import annotations

import argparse
import json
import subprocess

FIELDS = "NAME,PATH,TYPE,FSTYPE,LABEL,MOUNTPOINTS,RM,HOTPLUG,RO,MODEL,SIZE,FSUSE%"
MOUNTABLE_TYPES = {"part", "disk", "crypt"}
IGNORED_FSTYPES = {"swap"}
SWAP = "[SWAP]"

CRITICAL_MOUNTPOINTS = {
    "/", "/boot", "/boot/efi", "/usr", "/etc", "/var", "/var/tmp", "/var/log", "/opt", "/srv", "/root",
}


def read_devices(path: str | None) -> list:
    if path:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)["blockdevices"]

    result = subprocess.run(["lsblk", "-J", "-o", FIELDS], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)["blockdevices"]


def walk(node: dict):
    yield node
    for child in node.get("children") or []:
        yield from walk(child)


def is_mountable(node: dict) -> bool:
    return node.get("type") in MOUNTABLE_TYPES and bool(node.get("fstype")) and node["fstype"] not in IGNORED_FSTYPES


def mountpoints(node: dict) -> list:
    found = node.get("mountpoints")
    if found is None:
        found = [node.get("mountpoint")] if node.get("mountpoint") else []
    return [point for point in found if point and point != SWAP]


def entry(node: dict, disk: dict, removable: bool) -> dict:
    points = mountpoints(node)
    mountpoint = node.get("mountpoint") or (points[0] if points else "")
    return {
        "device": node.get("path") or f"/dev/{node['name']}",
        "label": node.get("label") or "",
        "fstype": node["fstype"],
        "size": node.get("size") or "",
        "use": node.get("fsuse%") or "",
        "mountpoints": points,
        "mountpoint": mountpoint if mountpoint != SWAP else "",
        "mounted": bool(points) and mountpoint != SWAP,
        "system": any(point in CRITICAL_MOUNTPOINTS for point in points),
        "readOnly": bool(node.get("ro")),
        "removable": removable,
        "model": disk.get("model") or "",
        "disk": disk.get("path") or f"/dev/{disk['name']}",
    }


def entries(devices: list) -> list:
    found = []
    for disk in devices:
        if disk.get("type") != "disk":
            continue
        removable = bool(disk.get("rm")) or bool(disk.get("hotplug"))
        for node in walk(disk):
            if node is not disk and is_mountable(node):
                found.append(entry(node, disk, removable))
            elif node is disk and is_mountable(disk):
                found.append(entry(disk, disk, removable))
    found.sort(key=lambda item: (not item["removable"], item["device"]))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", help="read lsblk JSON from a file instead of running it")
    args = parser.parse_args()

    print(json.dumps({"devices": entries(read_devices(args.file))}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())