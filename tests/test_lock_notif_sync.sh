#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTIFS="$REPO_ROOT/shell/services/Notifs.qml"
LOCK_UI="$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml"

test_shell_exposes_live_snapshot_over_ipc() {
    local content
    content="$(cat "$NOTIFS")"

    assert_contains "$content" 'function list(): string' \
        "Notifs should expose an IPC snapshot for out-of-process views"
    assert_contains "$content" 'function serializeList(): var' \
        "the snapshot and the persisted history must share one serialiser"
    assert_contains "$content" 'dnd: props.dnd' \
        "the snapshot must carry do-not-disturb alongside the items"
    assert_contains "$content" 'items: root.serializeList()' \
        "the snapshot's items must come from the shared serialiser"
    assert_contains "$content" 'target: "notifs"' \
        "the snapshot must live on the notifs IPC target"
}

test_lockscreen_takes_dnd_from_the_snapshot_and_writes_it_back() {
    local content
    content="$(cat "$LOCK_UI")"

    assert_contains "$content" 'lockScreenUi.isDndEnabled = snapshot.dnd === true' \
        "the lock screen must take do-not-disturb from the shell's snapshot"
    assert_contains "$content" 'onDndRequested:' \
        "the dino game's do-not-disturb request must be handled, not dropped"
    assert_contains "$content" 'call notifs " + (enabled ? "enableDnd" : "disableDnd")' \
        "do-not-disturb belongs to the shell, so it goes back over IPC"
    assert_contains "$content" '_dndBeforeGame' \
        "a session the game started must not switch off a do-not-disturb the user set"
}

test_lockscreen_reads_the_live_snapshot_not_the_persisted_file() {
    local content
    content="$(cat "$LOCK_UI")"

    assert_contains "$content" 'call notifs list' \
        "the lock screen must poll the shell for the live list"
    assert_not_contains "$content" 'cat ~/.local/state/caelestia/notifs.json' \
        "the lock screen must not read the debounced persistence file"
    assert_not_contains "$content" 'notifsClearedAt' \
        "clear-all must not need a local timestamp filter"
    assert_not_contains "$content" 'isClearingNotifs' \
        "clear-all must not need a local suppression latch"
}

test_lockscreen_clears_through_the_shell() {
    local content
    content="$(cat "$LOCK_UI")"

    assert_contains "$content" 'call notifs clear' \
        "clearing from the lock screen must go through the shell so the desktop page follows"
}

run_tests
