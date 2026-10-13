#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PC_SRC="$(cat "$REPO_ROOT/shell/services/PreviewColours.qml")"
WALL_SRC="$(cat "$REPO_ROOT/shell/services/Wallpapers.qml")"
LAUNCHER_SRC="$(cat "$REPO_ROOT/shell/modules/launcher/Content.qml")"

test_the_preview_state_lives_in_one_component() {
    assert_contains "$PC_SRC" 'function show(source: string): void' "show must be part of the interface"
    assert_contains "$PC_SRC" 'function hold(): void' "hold must be part of the interface"
    assert_contains "$PC_SRC" 'function release(): void' "release must be part of the interface"
    assert_contains "$PC_SRC" 'function stop(): void' "stop must be part of the interface"
    assert_not_contains "$WALL_SRC" 'previewColourLock' "the lock flag must stay inside the component"
    assert_not_contains "$WALL_SRC" 'pendingPreviewClear' "the deferred clear must stay inside the component"
    assert_not_contains "$WALL_SRC" 'getPreviewColoursProc' "the matugen process must be owned by the component"
    assert_not_contains "$WALL_SRC" 'property alias previewColours' "the component must not be re-exported"
}

test_only_the_component_shows_the_preview_scheme() {
    assert_contains "$PC_SRC" 'Colours.showPreview = true' "the component sets the preview scheme"
    assert_not_contains "$WALL_SRC" 'Colours.showPreview = true' "Wallpapers must not set the preview scheme"
    assert_not_contains "$WALL_SRC" 'Colours.showPreview = false' "Wallpapers must not clear the preview scheme"
}

test_a_result_is_shown_only_when_it_loaded_and_is_still_wanted() {
    assert_contains "$PC_SRC" 'if (!root.active && !root.held)' "a result nobody waits for must be dropped"
    assert_contains "$PC_SRC" 'root.wanted !== root.running' "a result for an earlier highlight must not be shown"
    assert_contains "$PC_SRC" 'if (Colours.load(text, true))' "a scheme that did not parse must not be shown"
}

test_the_preview_ends_only_while_nothing_wants_it() {
    assert_not_contains "$PC_SRC" 'clearOnRelease' "a stop must not leave a deferred clear behind"
    assert_contains "$PC_SRC" 'if (!active && !held)' "the preview is cleared only while nothing wants it"
}

test_the_wallpaper_change_drives_the_hold() {
    assert_contains "$WALL_SRC" 'previewColoursState.hold()' "setting a wallpaper holds the preview"
    assert_contains "$WALL_SRC" 'previewColoursState.release()' "a loaded wallpaper releases the hold"
    assert_not_contains "$LAUNCHER_SRC" 'previewColours' "the launcher must not drive the preview state"
    assert_not_contains "$LAUNCHER_SRC" 'hold()' "the launcher must not hold the preview state"
}

run_tests
