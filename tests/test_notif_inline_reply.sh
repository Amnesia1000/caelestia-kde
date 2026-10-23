#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTIFS="$REPO_ROOT/shell/services/Notifs.qml"
NOTIF_DATA="$REPO_ROOT/shell/services/NotifData.qml"
SIDEBAR_NOTIF="$REPO_ROOT/shell/modules/sidebar/Notif.qml"

test_server_advertises_inline_reply() {
    assert_contains "$(cat "$NOTIFS")" 'inlineReplySupported: true' \
        "clients only offer reply when the server advertises it"
}

test_notification_model_forwards_replies() {
    local data
    data="$(cat "$NOTIF_DATA")"

    assert_contains "$data" 'readonly property bool hasInlineReply: notif.notification?.hasInlineReply ?? false' \
        "a notification must know whether the sender offered a reply"
    assert_contains "$data" 'function sendReply(text: string): void' \
        "NotifData must expose the reply entry point"
    assert_contains "$data" 'notification.sendInlineReply(trimmed)' \
        "replies must go through the notification server"
    assert_contains "$data" 'if (!notification || !hasInlineReply || !trimmed)' \
        "empty replies and non-replyable notifications must be ignored"
}

test_sidebar_offers_the_reply_field_only_when_needed() {
    local notif
    notif="$(cat "$SIDEBAR_NOTIF")"

    assert_contains "$notif" 'visible: root.modelData?.hasInlineReply ?? false' \
        "the reply field must hide for notifications that cannot be answered"
    assert_contains "$notif" 'root.modelData.sendReply(text)' \
        "accepting the field must send the reply"
    assert_contains "$notif" 'root.modelData?.inlineReplyPlaceholder ?? ""' \
        "the field must use the sender's placeholder"
}

run_tests
