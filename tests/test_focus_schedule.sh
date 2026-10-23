#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$REPO_ROOT/shell/services/Focus.qml"
NOTIFS="$REPO_ROOT/shell/services/Notifs.qml"
CONFIG="$REPO_ROOT/shell/plugin/src/Caelestia/Config/notifsconfig.hpp"
PAGE="$REPO_ROOT/shell/modules/nexus/pages/services/FocusPage.qml"
HUB="$REPO_ROOT/shell/modules/nexus/pages/services/NotificationsPage.qml"
REGISTRY="$REPO_ROOT/shell/modules/nexus/PageCompRegistry.qml"

test_schedules_are_configured_as_windows() {
    local config
    config="$(cat "$CONFIG")"

    assert_contains "$config" 'CONFIG_GLOBAL_PROPERTY(bool, focusEnabled, false)' \
        "focus has to be opt-in"
    assert_contains "$config" 'CONFIG_GLOBAL_LIST(FocusScheduleList, focusSchedules, {})' \
        "schedules are a list of windows"
    assert_contains "$config" 'CONFIG_PROPERTY(QStringList, days, {})' "a window needs its days"
    assert_contains "$config" 'CONFIG_PROPERTY(QString, start' "and a start time"
    assert_contains "$config" 'CONFIG_PROPERTY(QString, end' "and an end time"
    assert_contains "$config" 'CONFIG_GLOBAL_PROPERTY(QStringList, focusAllowlist, QStringList())' \
        "apps allowed through the session have to be configurable"
}

test_overnight_windows_belong_to_the_day_they_started() {
    local service
    service="$(cat "$SERVICE")"

    assert_contains "$service" 'function scheduleActive(schedule: var, at: date): bool' \
        "the window logic must be one testable function"
    # 22:00-07:00 is a normal focus window; taken literally it would never match.
    assert_contains "$service" 'const yesterday = new Date(at.getFullYear(), at.getMonth(), at.getDate() - 1)' \
        "an overnight window must check the day it started on"
    assert_contains "$service" 'if (start < 0 || end < 0 || start === end)' \
        "a malformed or empty window must not match"
    assert_contains "$service" 'days.length === 0 || days.includes(day)' \
        "a window without days has to mean every day"
}

test_focus_only_undoes_the_dnd_it_turned_on() {
    local service
    service="$(cat "$SERVICE")"

    assert_contains "$service" 'Notifs.setDndSilently(true)' \
        "a session must not announce itself with a toast"
    assert_contains "$service" 'if (root._applied)' \
        "DND the user set by hand must survive the session ending"
    assert_contains "$service" 'if (Notifs.dnd)' \
        "clearing DND twice must not fight the user"
    assert_contains "$service" 'interval: 30 * 1000' "the window has to be re-evaluated as time passes"
}

test_allowlisted_apps_pass_through_the_session() {
    local notifs
    notifs="$(cat "$NOTIFS")"

    assert_contains "$notifs" 'function shouldShowPopup(appName: string): bool' \
        "the popup decision needs to know which app is speaking"
    assert_contains "$notifs" 'props.dnd && !Focus.allows(appName)' \
        "an allowlisted app must still pop up during a session"
    assert_contains "$notifs" 'props.dnd && !Focus.allows(notif.appName)' \
        "and must still make a sound"
    assert_contains "$notifs" 'root.shouldShowPopup(notif.appName)' \
        "the D-Bus path must pass the app name through"
    assert_contains "$notifs" 'root.shouldShowPopup(params.appName ?? "")' \
        "shell-raised notifications must pass theirs too"
    assert_contains "$(cat "$SERVICE")" 'return root.applied && appName !== "" && root.allowlist.includes(appName)' \
        "the allowlist may only apply while focus is what silenced things"
}

test_focus_page_is_reachable_from_notifications() {
    local page hub registry
    page="$(cat "$PAGE")"
    hub="$(cat "$HUB")"
    registry="$(cat "$REGISTRY")"

    assert_contains "$page" 'GlobalConfig.notifs.focusSchedules.insert' "the page must add schedules"
    assert_contains "$page" 'GlobalConfig.notifs.focusSchedules.remove(index)' "and remove them"
    assert_contains "$page" 'GlobalConfig.notifs.focusAllowlist = apps' "and edit the allowlist"
    assert_contains "$hub" 'root.nState.openSubPage(4)' "the hub must link to it"
    assert_contains "$registry" 'Component { FocusPage {} }' "the page must be registered"
}

run_tests
