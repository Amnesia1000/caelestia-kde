#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES="$REPO_ROOT/shell/services"
BAR_COMPONENTS="$REPO_ROOT/shell/modules/bar/components"
BAR_POPOUTS="$REPO_ROOT/shell/modules/bar/popouts"
CONFIG="$REPO_ROOT/shell/plugin/src/Caelestia/Config"
NEXUS_PANELS="$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar"
PRIVACY="$SERVICES/Privacy.qml"

test_microphone_capture_is_read_from_the_audio_streams() {
    assert_file_exists "$PRIVACY"

    assert_file_contains "$PRIVACY" '"media.class"] !== "Stream/Input/Audio"' \
        "only capture streams count: playback streams are not private"
    assert_file_contains "$PRIVACY" 'for (const stream of Audio.streams)' \
        "the indicator reuses the stream list the audio service already keeps"
    assert_file_contains "$PRIVACY" 'name === Audio.selfAppName' \
        "the shell's own capture must not light the indicator"
    assert_file_contains "$PRIVACY" 'names.includes(name)' \
        "one row per application, not one per stream"
}

test_video_capture_comes_from_the_native_watcher() {
    assert_file_contains "$PRIVACY" 'PipewireStreamWatcher.activeStreams' \
        "screen and camera capture is what the native watcher reports"
}

test_the_indicator_only_exists_while_something_captures() {
    assert_file_contains "$PRIVACY" 'readonly property bool inUse: root.entries.length > 0' \
        "there has to be a single answer to whether anything is capturing"
    assert_file_contains "$BAR_COMPONENTS/StatusIcons.qml" 'case "privacy":' \
        "the bar has to know the icon id"
    assert_file_contains "$BAR_COMPONENTS/StatusIcons.qml" 'return Privacy.inUse;' \
        "and the icon may only appear while something is capturing"
    assert_file_contains "$BAR_COMPONENTS/StatusIcons.qml" 'id: privacyComp' \
        "the icon needs a component to draw"
}

test_the_icon_is_shipped_and_migrated_into_an_existing_list() {
    assert_file_contains "$CONFIG/barconfig.hpp" 'LIST_ENTRY(privacy, true)' \
        "new configs get the icon in the status area"
    assert_file_contains "$NEXUS_PANELS/BarStatusIcons.qml" 'privacy: qsTr("Privacy")' \
        "the status icon editor needs a label for it"
    assert_file_contains "$SERVICES/ConfigMigrations.qml" 'root.migratePrivacyIcon();' \
        "configs that already override the list have to be migrated"
    assert_file_contains "$SERVICES/ConfigMigrations.qml" 'if (!icons.isOverride("values")' \
        "a config that does not override the list already has the new default"
    assert_file_contains "$SERVICES/ConfigMigrations.qml" 'entry.id === "privacy"' \
        "the migration has to be idempotent"
}

test_the_popout_lists_what_is_capturing() {
    assert_file_exists "$BAR_POPOUTS/Privacy.qml"
    assert_file_contains "$BAR_POPOUTS/Content.qml" 'name: "privacy"' \
        "the popout has to be registered"
    assert_file_contains "$BAR_POPOUTS/Privacy.qml" 'values: [...QsServices.Privacy.entries]' \
        "the popout lists the same rows the service reports"
}

run_tests
