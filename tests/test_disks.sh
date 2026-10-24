#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/shell/scripts/disks.py"
SERVICE="$REPO_ROOT/shell/services/Disks.qml"
PAGE="$REPO_ROOT/shell/modules/nexus/pages/StoragePage.qml"
DICTIONARY="$REPO_ROOT/shell/modules/nexus/PageDictionary.qml"
REGISTRY="$REPO_ROOT/shell/modules/nexus/PageCompRegistry.qml"
PYTHON="$(command -v python3 || command -v python)"

TMP="$("$PYTHON" -c 'import tempfile; print(tempfile.mkdtemp())')"
trap 'rm -rf "$TMP"' EXIT

# A laptop disk with a swap partition, a USB stick, a whole-disk filesystem on another
# stick, and the plumbing lsblk also reports: loop devices and zram.
prepare() {
    "$PYTHON" - "$TMP/lsblk.json" <<'PY'
import json
import sys

data = {
    "blockdevices": [
        {
            "name": "sda", "path": "/dev/sda", "type": "disk", "fstype": None, "label": None,
            "mountpoints": [], "rm": False, "hotplug": False, "ro": False, "model": "Samsung SSD", "size": "931.5G",
            "children": [
                {"name": "sda1", "path": "/dev/sda1", "type": "part", "fstype": "vfat", "label": "ESP",
                 "mountpoints": ["/boot"], "rm": False, "hotplug": False, "ro": False, "size": "1G", "fsuse%": "12%"},
                {"name": "sda2", "path": "/dev/sda2", "type": "part", "fstype": "ext4", "label": "root",
                 "mountpoints": ["/", "/var/tmp"], "rm": False, "hotplug": False, "ro": False, "size": "930G", "fsuse%": "41%"},
                {"name": "sda3", "path": "/dev/sda3", "type": "part", "fstype": "swap", "label": "swap",
                 "mountpoints": ["[SWAP]"], "rm": False, "hotplug": False, "ro": False, "size": "8G", "fsuse%": None},
            ],
        },
        {"name": "loop0", "path": "/dev/loop0", "type": "loop", "fstype": "squashfs", "label": None,
         "mountpoints": ["/snap/core"], "rm": False, "hotplug": False, "ro": True, "model": None, "size": "128M"},
        {"name": "zram0", "path": "/dev/zram0", "type": "disk", "fstype": None, "label": None,
         "mountpoints": ["[SWAP]"], "rm": False, "hotplug": False, "ro": False, "model": None, "size": "4G"},
        {
            "name": "sdb", "path": "/dev/sdb", "type": "disk", "fstype": None, "label": None,
            "mountpoints": [], "rm": True, "hotplug": True, "ro": False, "model": "USB Stick", "size": "57.3G",
            "children": [
                {"name": "sdb1", "path": "/dev/sdb1", "type": "part", "fstype": "exfat", "label": "Backup",
                 "mountpoints": [], "rm": True, "hotplug": True, "ro": False, "size": "57.3G", "fsuse%": None},
            ],
        },
        {"name": "sdc", "path": "/dev/sdc", "type": "disk", "fstype": "ext4", "label": "Whole disk",
         "mountpoints": ["/mnt/whole"], "rm": False, "hotplug": True, "ro": False, "model": "Portable",
         "size": "14.6G", "fsuse%": "3%"},
    ]
}

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(data, handle)
PY
    "$PYTHON" "$SCRIPT" --file "$TMP/lsblk.json" > "$TMP/out.json"
}

# What the script reports for one device, given without its /dev/ prefix: Git Bash
# rewrites a bare /dev/... argument into a Windows device path before Python sees it.
fields() {
    local device="$1"
    shift
    "$PYTHON" - "$TMP/out.json" "$device" "$@" <<'PY'
import json
import sys

entries = json.load(open(sys.argv[1], encoding="utf-8"))["devices"]
device, keys = f"/dev/{sys.argv[2].rsplit('/', 1)[-1]}", sys.argv[3:]
match = next((entry for entry in entries if entry["device"] == device), None)
print("missing" if match is None else " ".join(f"{key}={match[key]}" for key in keys))
PY
}

ordered_devices() {
    "$PYTHON" - "$TMP/out.json" <<'PY'
import json
import sys

print(" ".join(entry["device"] for entry in json.load(open(sys.argv[1], encoding="utf-8"))["devices"]))
PY
}

test_the_plumbing_is_left_out() {
    prepare

    assert_eq "/dev/sdb1 /dev/sdc /dev/sda1 /dev/sda2" "$(ordered_devices)" \
        "swap, zram and loop devices are not things you mount by hand, and removable media comes first"
}

test_a_partition_inherits_its_disk() {
    prepare

    assert_eq "removable=True model=USB Stick disk=/dev/sdb mounted=False label=Backup fstype=exfat" \
        "$(fields sdb1 removable model disk mounted label fstype)" \
        "the page groups by disk and only ejects removable ones, so both have to come from the parent"
    assert_eq "removable=False model=Samsung SSD system=True mountpoints=['/', '/var/tmp']" "$(fields sda2 removable model system mountpoints)" "the files the system needs are marked, so the page can show them without offering to unmount them"
}

test_a_whole_disk_filesystem_is_listed_too() {
    prepare

    assert_eq "mountpoint=/mnt/whole use=3% removable=True system=False" "$(fields sdc mountpoint use removable system)" \
        "a stick formatted without a partition table has no children to walk into"
}

test_mounting_goes_through_udisks() {
    assert_file_contains "$SERVICE" '["udisksctl", "mount", "-b", entry.device]' \
        "mounting has to be the polkit-checked path, not a plain mount"
    assert_file_contains "$SERVICE" '["udisksctl", "unmount", "-b", entry.device]' "unmounting likewise"
    assert_file_contains "$SERVICE" '["udisksctl", "power-off", "-b", entry.disk]' \
        "and a disk, not a partition, is what gets powered off"
    assert_file_contains "$SERVICE" 'Quickshell.shellPath("scripts/disks.py")' \
        "the service reads the same list this test exercises"
}

test_the_page_is_reachable() {
    assert_file_exists "$PAGE"
    assert_file_contains "$DICTIONARY" 'key: "storage"' "the page needs a dictionary entry"
    assert_file_contains "$REGISTRY" 'key: "storage"' "and a component slot"
    assert_file_contains "$PAGE" 'Disks.refresh()' "the list is re-read when the page is shown"
}

run_tests