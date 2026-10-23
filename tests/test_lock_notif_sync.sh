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
    assert_contains "$content" 'return root.serializeState();' \
        "the snapshot must reuse the persisted serialiser so both views describe the same list"
    assert_contains "$content" 'target: "notifs"' \
        "the snapshot must live on the notifs IPC target"
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
