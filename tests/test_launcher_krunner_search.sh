#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE_HPP="$REPO_ROOT/shell/plugin/src/Caelestia/Services/krunnerbridge.hpp"
BRIDGE_CPP="$REPO_ROOT/shell/plugin/src/Caelestia/Services/krunnerbridge.cpp"
SERVICES_CMAKE="$REPO_ROOT/shell/plugin/src/Caelestia/Services/CMakeLists.txt"
SEARCH="$REPO_ROOT/shell/services/Search.qml"
APP_LIST="$REPO_ROOT/shell/modules/launcher/AppList.qml"
CONTENT="$REPO_ROOT/shell/modules/launcher/Content.qml"
KRUNNER_ITEM="$REPO_ROOT/shell/modules/launcher/items/KRunnerItem.qml"
LAUNCHER_CONFIG="$REPO_ROOT/shell/plugin/src/Caelestia/Config/launcherconfig.hpp"

test_bridge_is_optional_at_build_time() {
    local cmake
    cmake="$(cat "$SERVICES_CMAKE")"

    assert_contains "$cmake" 'find_package(KF6Runner QUIET)' \
        "KF6Runner must be optional so a build without it still works"
    assert_contains "$cmake" 'target_compile_definitions(caelestia-services PRIVATE CAELESTIA_HAVE_KRUNNER)' \
        "the bridge must be compiled in only when KF6Runner is found"
    assert_contains "$cmake" 'krunnerbridge.cpp' \
        "the bridge source must always be part of the module"
}

test_bridge_reports_availability_and_runs_results() {
    local hpp cpp
    hpp="$(cat "$BRIDGE_HPP")"
    cpp="$(cat "$BRIDGE_CPP")"

    assert_contains "$hpp" 'QML_ELEMENT' "the bridge must be exposed to QML"
    assert_contains "$hpp" 'Q_PROPERTY(bool available READ available CONSTANT)' \
        "QML needs to know whether KRunner is usable"
    assert_contains "$cpp" 'return false;' \
        "without KF6Runner the bridge must report itself unavailable"
    assert_contains "$cpp" 'launchQuery' "queries go through KRunner's RunnerManager"
    assert_contains "$cpp" 'matchesChanged' "results arrive asynchronously"
    assert_contains "$cpp" 'manager->run(match, chosen)' "the bridge must be able to activate a result"
}

test_launcher_has_a_live_search_mode() {
    local list search
    list="$(cat "$APP_LIST")"
    search="$(cat "$SEARCH")"

    assert_contains "$list" '"clipboard", "windows", "search"' \
        "the launcher must recognise the search mode"
    assert_contains "$list" 'return Search.results;' \
        "the search mode must render KRunner results"
    assert_contains "$list" 'id: krunnerItem' "the search mode needs its own delegate"
    assert_contains "$list" 'onSearchQueryChanged: Search.search(root.searchQuery)' \
        "typing must drive the asynchronous query"
    assert_contains "$list" 'if (state !== "search")' \
        "leaving the mode must reset the bridge"

    assert_contains "$search" 'readonly property bool available: KRunnerBridge.available' \
        "the service must expose availability"
    assert_contains "$search" 'KRunnerBridge.run(index, actionId ?? "")' \
        "the service must forward activation"
}

test_search_results_activate_from_the_keyboard() {
    assert_contains "$(cat "$CONTENT")" 'actionPrefix}search `' \
        "Enter must route the search mode through the result's clicked()"

    local item
    item="$(cat "$KRUNNER_ITEM")"
    assert_contains "$item" 'function clicked(): void' "a result must expose clicked() for the launcher"
    assert_contains "$item" 'Search.run(root.index, "")' "clicked() must run the KRunner match"
}

test_search_mode_is_discoverable_from_the_action_list() {
    local config
    config="$(cat "$LAUNCHER_CONFIG")"

    assert_contains "$config" 'u"Search Everything"_s' "the action list must advertise the mode"
    assert_contains "$config" 'QStringList{ u"autocomplete"_s, u"search"_s }' \
        "the action must autocomplete the search prefix"
}

run_tests
