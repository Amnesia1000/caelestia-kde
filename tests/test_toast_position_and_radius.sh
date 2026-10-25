#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOASTS="$REPO_ROOT/shell/modules/utilities/toasts/Toasts.qml"
PANELS="$REPO_ROOT/shell/modules/drawers/Panels.qml"
PAGE="$REPO_ROOT/shell/modules/nexus/pages/services/ToastPreferencesPage.qml"
SCHEMA="$REPO_ROOT/shell/plugin/src/Caelestia/Config/utilitiesconfig.hpp"
WINDOW="$REPO_ROOT/shell/modules/drawers/ContentWindow.qml"

test_the_corner_is_a_setting_with_a_corner_for_every_taste() {
    assert_file_contains "$SCHEMA" "CONFIG_GLOBAL_PROPERTY(QString, position, u\"auto\"_s)" \
        "the corner is config, so it survives a restart"
    assert_file_contains "$PAGE" 'readonly property list<string> cornerValues: ["auto", "top-left", "top-right", "bottom-left", "bottom-right"]' \
        "all four corners, plus automatic"
    assert_file_contains "$PAGE" 'GlobalConfig.utilities.toasts.position = root.cornerValues' \
        "and the row writes it"
}

# The stack has always grown upwards from the bottom; a top corner has to grow the other
# way, which is why both margins and both edges exist.
test_the_stack_grows_from_the_corner_it_was_given() {
    assert_file_contains "$TOASTS" 'readonly property bool fromTop: root.position.startsWith("top")' "the vertical side comes from the corner"
    assert_file_contains "$TOASTS" 'readonly property bool fromLeft: root.position.endsWith("left")' "and so does the horizontal one"
    assert_file_contains "$TOASTS" 'anchors.top: root.fromTop ? parent.top : undefined' "a top corner hangs from the top"
    assert_file_contains "$TOASTS" 'anchors.bottom: root.fromTop ? undefined : parent.bottom' "and a bottom corner from the bottom"
    assert_file_contains "$TOASTS" 'anchors.topMargin: root.fromTop ? root.offsetFor(index) : 0' "each toast clears the ones in front of it"
    assert_file_contains "$TOASTS" 'anchors.bottomMargin: root.fromTop ? 0 : root.offsetFor(index)' "in the direction the stack grows"
    assert_file_contains "$TOASTS" 'Behavior on anchors.topMargin' "and the movement is animated either way"
}

# The default must not move anyone's toasts: `auto` resolves to the corner the shell has
# always used.
test_automatic_keeps_the_corner_the_shell_always_used() {
    assert_file_contains "$PANELS" 'return wanted === "auto" ? "bottom-right" : wanted;' \
        "automatic means the bottom, clear of the launcher"
    assert_file_contains "$PANELS" 'position: toasts.corner' "the surface is told the resolved corner"
    assert_file_contains "$PANELS" 'anchors.right: toasts.fromLeft ? undefined : sidebar.left' \
        "and a right-hand corner still sits clear of the sidebar"
}

# The drawer's frame and the surface drawn inside it are one number, not two: a frame
# rounding that disagrees with the panel leaves a sliver of wallpaper at every corner.
test_the_drawer_frame_and_its_surface_share_one_radius() {
    assert_file_contains "$WINDOW" 'readonly property real borderRounding: Config.border.rounding' \
        "the radius has a single owner"
    assert_eq "1" "$(find "$WINDOW" -type f -exec grep -c 'readonly property real borderRounding' {} \;)" \
        "and it is defined once"
    assert_eq "yes" "$([[ "$(find "$WINDOW" -type f -exec grep -c 'radius: root.borderRounding' {} \;)" -ge 2 ]] && echo yes || echo no)" \
        "the frame and the surface both read it, so they cannot disagree"
    # What is left on a token is the bar island: a surface of its own, with no frame
    # around it to line up with.
    assert_file_contains "$WINDOW" 'radius: Tokens.rounding.extraLarge' \
        "the island keeps the corner of an island"
}

run_tests
