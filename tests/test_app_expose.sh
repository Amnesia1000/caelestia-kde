#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIS="$REPO_ROOT/shell/services/Visibilities.qml"
GRID="$REPO_ROOT/shell/modules/overview/WindowGrid.qml"
DOCK="$REPO_ROOT/shell/modules/bar/popouts/DockContext.qml"
KWIN="$REPO_ROOT/shell/services/Kwin.qml"

test_overview_can_be_limited_to_one_application() {
    local vis grid dock kwin
    vis="$(cat "$VIS")"
    grid="$(cat "$GRID")"
    dock="$(cat "$DOCK")"
    kwin="$(cat "$KWIN")"

    assert_contains "$vis" 'property var overviewAppFilter: []' \
        "Visibilities should hold the overview's application filter"
    assert_contains "$vis" 'function showAppWindows(names: var): void' \
        "Visibilities should be able to open the overview for one application"
    assert_contains "$vis" 'overviewAppFilter = [];' \
        "closing the overview must clear the filter, or the next open is still filtered"
}

test_the_grid_filters_through_one_shared_matcher() {
    local grid kwin
    grid="$(cat "$GRID")"
    kwin="$(cat "$KWIN")"

    assert_contains "$grid" 'Kwin.windowMatchesApp(w, filter)' \
        "the window grid must filter through the shared matcher"
    assert_contains "$grid" 'const filter = Visibilities.overviewAppFilter' \
        "the filter must be read inside the binding, or the grid never re-evaluates"
    assert_contains "$grid" 'on_AppFilterChanged: _updateWsWindows()' \
        "the rendered window cards must re-run when the filter changes"
    assert_contains "$kwin" 'function windowMatchesApp(w: var, names: var): bool' \
        "the app matcher belongs on the Kwin service so the dock and grid agree"
    assert_contains "$kwin" 'replace(/\.desktop$/, "")' \
        "matching must normalise desktop entry ids against window classes"
}

test_the_dock_offers_show_all_windows() {
    local dock
    dock="$(cat "$DOCK")"

    assert_contains "$dock" 'Visibilities.showAppWindows(root.appNames)' \
        "the dock context menu should open the overview for that application"
    assert_contains "$dock" 'Kwin.windowMatchesApp(windows[i], root.appNames)' \
        "the entry should only appear when the application has windows"
    assert_contains "$dock" 'qsTr("Show all windows")' \
        "the action needs a label"
}

run_tests
