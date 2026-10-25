#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTIFS="$REPO_ROOT/shell/services/Notifs.qml"
SCHEMA="$REPO_ROOT/shell/plugin/src/Caelestia/Config/notifsconfig.hpp"
POPUP="$REPO_ROOT/shell/modules/notifications/Notification.qml"
DOCK="$REPO_ROOT/shell/modules/sidebar/NotifDock.qml"
DOCK_LIST="$REPO_ROOT/shell/modules/sidebar/NotifDockList.qml"
GROUP="$REPO_ROOT/shell/modules/sidebar/NotifGroup.qml"
PAGE="$REPO_ROOT/shell/modules/nexus/pages/audio/NotificationSilencingPage.qml"

test_turning_an_app_off_is_a_setting_not_a_runtime_habit() {
    assert_file_contains "$SCHEMA" "CONFIG_GLOBAL_PROPERTY(QStringList, mutedApps" \
        "the list has to survive a restart, so it is config and not state"
    assert_file_contains "$NOTIFS" 'return GlobalConfig.notifs.mutedApps.includes(appName);' \
        "one place decides what 'muted' means"
}

test_muting_an_app_drops_what_it_already_sent() {
    assert_file_contains "$NOTIFS" 'function muteApp(appName: string): void' \
        "the popup and the settings page both go through this"
    assert_file_contains "$NOTIFS" 'GlobalConfig.notifs.mutedApps = Array.from(GlobalConfig.notifs.mutedApps).concat([appName]);' \
        "muting records the app"
    assert_file_contains "$NOTIFS" 'root.list = root.list.filter(n => n.appName !== appName);' \
        "and drops what it already sent, or the next banner looks like the mute did not stick"
    assert_file_contains "$NOTIFS" 'for (const notif of dropped)' "closing them is what tells the sender"
}

# A muted notification is answered, not filed: the sender gets its close, and the list,
# the unread count and the sound never see it.
test_a_muted_notification_is_answered_and_never_filed() {
    local block order
    block="$(sed -n '/onNotification: notif => {/,/^        }$/p' "$NOTIFS")"

    assert_contains "$block" 'if (root.isMuted(notif.appName)) {' "the notification path checks the mute first"
    assert_contains "$block" 'notification: notif' "and still builds the notification so it can be dismissed"

    order="$(printf '%s\n' "$block" | awk '
        /if \(root\.isMuted\(notif\.appName\)\)/ { mute = NR }
        /root\.registerNotification\(comp\)/ { register = NR }
        /Audio\.playNotification\(\)/ { sound = NR }
        END { print (mute && register && sound && mute < register && mute < sound) ? 1 : 0 }
    ')"
    assert_eq "1" "$order" "the mute has to return before anything is registered or played"
}

test_the_popup_offers_the_mute() {
    assert_file_contains "$POPUP" 'icon: "notifications_off"' "the button is on the notification itself"
    assert_file_contains "$POPUP" 'onClicked: Notifs.muteApp(root.modelData.appName)' \
        "and mutes the application that sent it, not the shell"
}

# The filter has to reach every layer that decides what is drawn, or the search box
# narrows nothing: the app list, the notifications inside each app, and the dock that
# owns the query.
test_the_search_reaches_the_list_it_narrows() {
    assert_file_contains "$NOTIFS" 'function matchesQuery(notif: var, query: string): bool' \
        "one definition of what a search matches"
    assert_file_contains "$NOTIFS" '[notif.appName, notif.summaryPlain, notif.bodyPlain]' \
        "the app, the summary, and the body without its markup"
    assert_file_contains "$DOCK" 'onTextEdited: text => root.query = text' "the dock owns the query"
    assert_file_contains "$DOCK" 'filter: root.query' "and passes it to the list"
    assert_file_contains "$DOCK_LIST" 'Notifs.matchesQuery(n, root.filter)' "the app list is filtered"
    assert_file_contains "$GROUP" 'Notifs.matchesQuery(n, root.filter)' "and so are the notifications inside an app"
}

test_the_search_and_the_mute_can_be_driven_without_a_pointer() {
    assert_file_contains "$NOTIFS" 'function mute(appName: string): void' "mute is on the IPC"
    assert_file_contains "$NOTIFS" 'function unmute(appName: string): void' "and so is unmute"
    assert_file_contains "$NOTIFS" 'function search(query: string): string' "and the search it would show"
}

test_the_settings_page_shows_both_policies() {
    assert_file_contains "$PAGE" 'GlobalConfig.notifs.mutedApps' "apps that send nothing"
    assert_file_contains "$PAGE" 'GlobalConfig.audio.sounds.disabledNotifApps' "and apps that send quietly"
    assert_file_contains "$PAGE" 'AppPickerRow {' "the applications are picked from what is installed, not typed from memory"
}

run_tests
