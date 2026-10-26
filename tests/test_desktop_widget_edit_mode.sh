#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAYOUT="$REPO_ROOT/shell/services/DesktopLayout.qml"
STORE="$REPO_ROOT/shell/services/ContextMenuStore.qml"
ICONS="$REPO_ROOT/shell/modules/background/DesktopIcons.qml"
BIG="$REPO_ROOT/shell/modules/background/desktopicons/BigItem.qml"
MENU="$REPO_ROOT/shell/modules/background/DesktopContextMenu.qml"
OVERLAY="$REPO_ROOT/shell/modules/background/WidgetEditOverlay.qml"
SHELL_ROOT="$REPO_ROOT/shell/shell.qml"

assert_file_contains "$LAYOUT" 'property bool widgetEditMode: false' "the mode must be desktop-wide state"
assert_file_contains "$LAYOUT" 'function setWidgetEditMode(on: bool): void' "the mode needs one setter every entry point shares"
assert_file_contains "$LAYOUT" 'controller.prepareWidgetEdit();' "entering the mode must settle each screen first"
assert_file_contains "$LAYOUT" 'controller.finishWidgetEdit();' "leaving the mode must end every preview"
assert_file_contains "$LAYOUT" 'target: "desktop"' "the mode must be reachable without the mouse"

test_the_context_menu_entry_toggles_the_mode() {
    assert_file_contains "$STORE" 'action: "EditWidgets"' "the Widgets menu needs an entry for the mode"
    assert_file_contains "$STORE" 'action === "EditWidgets"' "a saved menu must keep the entry in the Widgets group"
    assert_file_contains "$MENU" 'DesktopLayout.toggleWidgetEditMode();' "the entry must toggle rather than only enter"
    assert_file_contains "$MENU" 'entry.action === "EditWidgets"' "the entry needs its own label handling"
}

test_the_content_stops_taking_input() {
    assert_file_contains "$ICONS" 'editMode: root.widgetEditMode' "the widgets must be told about the mode"
    assert_file_contains "$BIG" 'property bool editMode: false' "a card must know when the mode is on"
    assert_file_contains "$BIG" 'enabled: !root.editMode' "widget controls must not take the drag that starts a move"
}

test_the_whole_card_drags_and_every_border_resizes() {
    assert_file_contains "$BIG" 'id: editArea' "the mode needs a surface over the content"
    assert_file_contains "$BIG" 'root.dragRequested(pressPos.x + card.x, pressPos.y + card.y);' "a drag must start from the card, not only its background"
    assert_file_contains "$BIG" 'root.hovered || root.selected || root.editMode || pressed' "the borders must show in the mode without hovering"
}

test_widget_identity_is_visible_while_editing() {
    assert_file_contains "$BIG" 'visible: root.editMode && !root.isGroup' "the badge must only appear while editing"
    assert_file_contains "$BIG" 'text: `${root.span.w} × ${root.span.h}`' "the badge must show the size the card occupies"
    assert_file_contains "$BIG" 'DesktopLayout.widgetOutlines || editMode' "an empty widget must still be locatable while editing"
}

test_editing_never_launches_anything() {
    assert_file_contains "$ICONS" 'if (widgetEditMode)
            return;' "opening files while editing must be impossible"
}

test_deleting_while_editing_leaves_files_alone() {
    assert_file_contains "$ICONS" 'if (widgetEditMode) {' "Delete must branch on the mode"
    assert_file_contains "$ICONS" 'removeWidgets(keys.filter(isWidgetKey));' "editing must remove only the selected widgets"
}

test_the_mode_copies_widgets_not_files() {
    assert_file_contains "$ICONS" 'if (widgetEditMode)
                copyWidgets(selectedKeys());' "Ctrl+C must copy widgets while editing"
    assert_file_contains "$ICONS" 'if (widgetEditMode)
                pasteWidgets();' "Ctrl+V must paste widgets while editing"
    assert_file_contains "$ICONS" 'if (!widgetEditMode)
                copyKeys(selectedKeys(), true);' "cutting a widget must stay unavailable"
    assert_file_contains "$LAYOUT" 'property var widgetClipboard: []' "a copy must survive a paste on another screen"
    assert_file_contains "$ICONS" 'DesktopLayout.newGroupId();' "a paste must allocate a new id per widget"
}

test_escape_and_the_toolbar_leave_the_mode() {
    assert_file_contains "$ICONS" 'DesktopLayout.setWidgetEditMode(false);' "Escape must be a way out"
    assert_file_contains "$OVERLAY" 'onClicked: DesktopLayout.setWidgetEditMode(false)' "the toolbar must be a way out"
    assert_file_contains "$SHELL_ROOT" 'WidgetEditOverlay {}' "the toolbar must be instantiated"
}

test_the_toolbar_offers_the_actions_that_need_no_widget() {
    assert_file_contains "$OVERLAY" 'DesktopLayout.addWidgetRequested(' "the toolbar must add a widget without a right-click"
    assert_file_contains "$OVERLAY" 'DesktopLayout.setAllWidgetsLocked(DesktopLayout.anyWidgetUnlocked())' "the toolbar must lock and unlock every widget"
    assert_file_contains "$OVERLAY" 'DesktopLayout.widgetEditMode && win.controller !== null' "a screen without a desktop must not show the toolbar"
}

test_entering_the_mode_clears_stale_state() {
    assert_file_contains "$ICONS" 'function prepareWidgetEdit(): void {' "the controller must settle before the first click"
    assert_file_contains "$ICONS" 'endResizePreview();
        clearDropPreview();
        clearSelection();' "a leftover selection must not survive into the mode"
    assert_file_contains "$ICONS" 'function finishWidgetEdit(): void {' "leaving the mode must tidy up too"
}

test_the_keyboard_comes_back_to_the_desktop() {
    assert_file_contains "$MENU" 'DesktopLayout.controllerFor(root.screenName)?.grabKeyboard();' "Escape and Delete must reach the desktop once the menu closes"
}

test_the_grid_is_drawn_while_editing() {
    assert_file_contains "$ICONS" 'active: root.widgetEditMode' "the cell guides must be built only while editing"
    assert_file_contains "$ICONS" 'model: root.cols + 1' "the guides must follow the column count"
    assert_file_contains "$ICONS" 'model: root.rows + 1' "the guides must follow the row count"
}

run_tests
