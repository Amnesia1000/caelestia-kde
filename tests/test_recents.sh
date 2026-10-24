#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/shell/scripts/recents.py"
SERVICE="$REPO_ROOT/shell/services/Recents.qml"
DOCK_MENU="$REPO_ROOT/shell/modules/bar/popouts/DockContext.qml"
PYTHON="$(command -v python3 || command -v python)"

TMP="$("$PYTHON" -c 'import tempfile; print(tempfile.mkdtemp())')"
trap 'rm -rf "$TMP"' EXIT

# A recent-documents list with two files that still exist, one that does not, and a web
# page that is not a file at all.
prepare() {
    mkdir -p "$TMP/files"
    : > "$TMP/files/notes.txt"
    : > "$TMP/files/shot.png"

    "$PYTHON" - "$TMP/recently-used.xbel" "$TMP/files" <<'PY'
import sys

target, files = sys.argv[1], sys.argv[2].replace("\\", "/")
template = """<?xml version="1.0" encoding="UTF-8"?>
<xbel version="1.0" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"
      xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info">
  <bookmark href="file:///{files}/notes.txt" modified="2026-10-03T10:00:00Z">
    <info><metadata owner="http://freedesktop.org">
      <mime:mime-type type="text/plain"/>
      <bookmark:applications><bookmark:application name="org.kde.kate" exec="/usr/bin/kate %U" count="2"/></bookmark:applications>
    </metadata></info>
  </bookmark>
  <bookmark href="file:///{files}/shot.png" modified="2026-10-05T10:00:00Z">
    <info><metadata owner="http://freedesktop.org">
      <mime:mime-type type="image/png"/>
      <bookmark:applications><bookmark:application name="org.kde.spectacle" exec="/usr/bin/spectacle %f" count="1"/></bookmark:applications>
    </metadata></info>
  </bookmark>
  <bookmark href="file:///{files}/deleted.txt" modified="2026-10-06T10:00:00Z">
    <info><metadata owner="http://freedesktop.org">
      <mime:mime-type type="text/plain"/>
      <bookmark:applications><bookmark:application name="org.kde.kate" exec="/usr/bin/kate %U" count="1"/></bookmark:applications>
    </metadata></info>
  </bookmark>
  <bookmark href="https://example.com/page" modified="2026-10-07T10:00:00Z"/>
</xbel>
"""

open(target, "w", encoding="utf-8").write(template.replace("{files}", files))
PY
}

names() {
    "$PYTHON" -c 'import json,sys; print(" ".join(entry["name"] for entry in json.load(sys.stdin)))'
}

test_only_files_that_are_still_there_and_newest_first() {
    prepare

    assert_eq "shot.png notes.txt" "$("$PYTHON" "$SCRIPT" --file "$TMP/recently-used.xbel" | names)" \
        "a deleted file and a web page are not documents you can open from a jump list"
}

test_a_jump_list_is_one_applications_history() {
    prepare

    assert_eq "notes.txt" "$("$PYTHON" "$SCRIPT" --file "$TMP/recently-used.xbel" --app kate | names)" \
        "filtering by the name the file records"
    assert_eq "shot.png" "$("$PYTHON" "$SCRIPT" --file "$TMP/recently-used.xbel" --app org.kde.spectacle.desktop | names)" \
        "and by the desktop entry id the dock knows, which is spelled differently"
    assert_eq "shot.png notes.txt" "$("$PYTHON" "$SCRIPT" --file "$TMP/recently-used.xbel" --app kate --app spectacle | names)" \
        "several names for one application still make one list"
}

test_the_limit_is_the_menu_size() {
    prepare

    assert_eq "shot.png" "$("$PYTHON" "$SCRIPT" --file "$TMP/recently-used.xbel" --limit 1 | names)" \
        "the menu asks for a handful, not the whole history"
    assert_file_contains "$SERVICE" '"--limit", "5"' "and five is what it asks for"
}

test_the_dock_menu_offers_them() {
    assert_file_contains "$SERVICE" 'Quickshell.shellPath("scripts/recents.py")' "one owner for the file"
    assert_file_contains "$DOCK_MENU" 'Recents.load(root.appNames)' "the menu asks for this application's history when it opens"
    assert_file_contains "$DOCK_MENU" 'Launch.exec(["xdg-open", entry.path])' "and opens the file"
    assert_file_contains "$DOCK_MENU" 'qsTr("Recent files")' "the row has a heading"
}

run_tests