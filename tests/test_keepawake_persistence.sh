#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$REPO_ROOT/shell/services/IdleInhibitor.qml"

test_the_intent_is_read_from_and_written_to_the_state_directory() {
    assert_file_contains "$SERVICE" 'path: `${Paths.state}/keepawake.json`' \
        "the state lives next to the other runtime files"
    assert_file_contains "$SERVICE" 'stateFile.setText(JSON.stringify({ enabled:' \
        "a toggle has to be written back"
    assert_file_contains "$SERVICE" 'onLoaded: root.restore(stateFile.text())' \
        "and read back on start, so a restart keeps the machine awake"
    assert_file_contains "$SERVICE" 'root.enabledSince = isNaN(since.getTime()) ? new Date() : since' \
        "the active-since time has to survive the restart, and a corrupt value must not throw"
}

test_persistent_properties_are_not_used_for_it() {
    assert_file_not_contains "$SERVICE" 'reloadableId' \
        "the reload-only property store does not survive a restart of the service"
}

test_restoring_is_not_written_back() {
    assert_file_contains "$SERVICE" 'if (root.restoring)' \
        "reading the file must not look like a toggle"
    assert_file_contains "$SERVICE" 'root.restoring = true' \
        "the guard has to wrap the restore"
    assert_file_contains "$SERVICE" 'if (root.touched)' \
        "a toggle made before the file arrives must win over what it says"
}

test_the_inhibitor_follows_the_restored_value() {
    assert_file_contains "$SERVICE" 'enabled: root.enabled' \
        "the compositor inhibitor has to stay bound to the restored value"
    assert_file_contains "$SERVICE" 'target: "idleInhibitor"' \
        "the IPC surface is unchanged"
    assert_file_contains "$SERVICE" 'function isEnabled(): bool' \
        "and still answers the same question"
}

test_the_timer_is_not_a_dependency_of_the_import_list() {
    assert_file_contains "$SERVICE" 'import QtQuick' \
        "the save timer needs QtQuick, and a missing import takes the whole shell down"
}

run_tests
