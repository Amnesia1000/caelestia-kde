#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINDOW="$REPO_ROOT/shell/modules/drawers/ContentWindow.qml"
NOTIFS="$REPO_ROOT/shell/modules/notifications/Content.qml"

test_the_drawer_window_can_take_the_keyboard() {
    local wants
    wants="$(grep -m1 'readonly property bool wantsKeyboard' "$WINDOW")"

    assert_contains "$wants" 'visibilities.utilities' \
        "the timers are text fields, so the drawer's window has to take the keyboard while it is open"
}

test_the_notification_stack_is_measured_from_where_the_drawer_ends() {
    local content
    content="$(cat "$NOTIFS")"

    assert_contains "$content" 'utilitiesPanel.height).y' \
        "the stack takes what the drawer leaves, measured from the drawer's bottom edge"
    assert_not_contains "$content" '(utilitiesPanel as Utilities.Wrapper).nonAnimHeight - Config.border.thickness' \
        "a drawer's height says nothing about where it ends, and the difference is what sliced notifications"
    assert_contains "$content" 'Math.max(0,' \
        "no room has to mean no panel, never a negative height"
}

test_the_two_panels_do_not_fuse_into_one_blob() {
    local window
    window="$(cat "$WINDOW")"

    assert_contains "$window" 'exclude: [utilsBg]' \
        "a notification background must not bridge into the drawer's behind it"
    assert_contains "$window" '.concat([notifsBg])' \
        "and the drawer must not bridge into the notification's"
}

run_tests
