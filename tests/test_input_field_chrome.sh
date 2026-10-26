#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="$REPO_ROOT/shell/components/controls/StyledInputField.qml"
FIELD="$REPO_ROOT/shell/components/controls/StyledTextField.qml"
LAYER="$REPO_ROOT/shell/components/StateLayer.qml"

test_a_field_inside_a_box_does_not_draw_a_box_of_its_own() {
    assert_file_contains "$INPUT" 'flat: true' \
        "the container is the box; a field that outlines itself as well draws two"
}

test_the_field_can_be_asked_for_no_chrome() {
    assert_file_contains "$FIELD" 'property bool flat: false' \
        "the field has to be able to drop its outline and its fill"
    assert_file_contains "$FIELD" 'sourceComponent: root.flat ? null :' \
        "and dropping them has to actually drop them"
}

test_hover_feedback_belongs_to_whoever_draws_the_box() {
    assert_file_contains "$LAYER" 'root.showHoverBackground && (containsMouse' \
        "the setting has to be honoured, not just declared"
    assert_file_contains "$FIELD" 'showHoverBackground: !root.flat' \
        "a flat field leaves the hover to its container instead of tinting a second rectangle"
}

run_tests
