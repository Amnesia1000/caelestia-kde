#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES="$REPO_ROOT/shell/services"
PLUGIN_SERVICES="$REPO_ROOT/shell/plugin/src/Caelestia/Services"
PREFS="$REPO_ROOT/shell/modules/nexus/pages/services"
STREAM_MONITOR="$SERVICES/StreamMonitor.qml"
NOTIFS="$SERVICES/Notifs.qml"
INDICATOR="$REPO_ROOT/shell/modules/bar/components/NotificationsIndicator.qml"

test_stream_monitor_binds_to_native_pipewire_watcher() {
    assert_file_contains "$SERVICES/StreamMonitor.qml" 'PipewireStreamWatcher.streaming' \
        "StreamMonitor must bind to native PipewireStreamWatcher"
    assert_file_contains "$SERVICES/StreamMonitor.qml" 'Recorder.running' \
        "StreamMonitor must account for local screen recorder state"
    assert_file_not_contains "$SERVICES/StreamMonitor.qml" 'Quickshell.Services.Pipewire' \
        "StreamMonitor must not rely on audio-only Quickshell.Services.Pipewire"
}

test_native_pipewire_watcher_sources_are_registered() {
    assert_file_exists "$PLUGIN_SERVICES/pipewirestreamwatcher.hpp"
    assert_file_exists "$PLUGIN_SERVICES/pipewirestreamwatcher.cpp"
    assert_file_contains "$PLUGIN_SERVICES/CMakeLists.txt" 'pipewirestreamwatcher.cpp' \
        "pipewirestreamwatcher.cpp must be registered in CMakeLists.txt"
    assert_file_contains "$PLUGIN_SERVICES/pipewirestreamwatcher.hpp" 'QML_SINGLETON' \
        "PipewireStreamWatcher must be a QML singleton"
}

test_notification_preferences_page_has_no_duplicate_properties() {
    assert_file_contains "$PREFS/NotificationPreferencesPage.qml" 'dndWhileStreaming' \
        "NotificationPreferencesPage must configure dndWhileStreaming"
}

test_auto_dnd_is_applied_without_announcing_it() {
    assert_file_contains "$NOTIFS" 'suppressDndToast' \
        "Notifs must be able to change dnd without the change toast"
    assert_file_contains "$NOTIFS" 'function setDndSilently(value: bool)' \
        "Notifs must expose a dedicated silent dnd setter"
    assert_file_contains "$STREAM_MONITOR" 'Notifs.setDndSilently(true)' \
        "engaging auto dnd must not announce the change"
    assert_file_contains "$STREAM_MONITOR" 'Notifs.setDndSilently(false)' \
        "releasing auto dnd must not announce the change"
    assert_file_not_contains "$STREAM_MONITOR" 'Notifs.dnd = ' \
        "StreamMonitor must not write dnd directly, that always announces"
    assert_file_contains "$STREAM_MONITOR" 'if (!root.autoWriting)' \
        "only StreamMonitor's own dnd writes may be ignored"
}

test_a_manual_dnd_toggle_still_announces() {
    assert_file_contains "$INDICATOR" 'Notifs.dnd = !Notifs.dnd' \
        "the bar indicator keeps announcing a manual toggle"
    assert_file_contains "$NOTIFS" 'utilities.toasts.dndChanged' \
        "the dnd toast stays behind its own setting"
}

run_tests
