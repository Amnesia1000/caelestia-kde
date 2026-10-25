#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMERS="$REPO_ROOT/shell/services/Timers.qml"
CARD="$REPO_ROOT/shell/modules/utilities/cards/TimersCard.qml"
CONTENT="$REPO_ROOT/shell/modules/utilities/Content.qml"
SCHEMA="$REPO_ROOT/shell/plugin/src/Caelestia/Config/utilitiesconfig.hpp"
PANEL_PAGE="$REPO_ROOT/shell/modules/nexus/pages/utilities/UtilitiesPanelPage.qml"
LOADER="$REPO_ROOT/shell/modules/ServiceLoader.qml"
AI="$REPO_ROOT/shell/modules/sidebar/AiAssistant.qml"

# A timer is a deadline, not a countdown: storing what is left means a restart two
# minutes into a 25 minute timer silently loses the other 23.
test_a_timer_is_stored_as_the_moment_it_ends() {
    assert_file_contains "$TIMERS" 'ends: Date.now() + seconds * 1000' "starting a timer records when it ends"
    assert_file_contains "$TIMERS" 'ends: timer.ends' "and that is what is written to disk"
    assert_file_contains "$TIMERS" 'path: `${Paths.state}/timers.json`' "beside the other state the shell keeps"
    assert_file_contains "$TIMERS" 'root.list = data.filter(timer => timer.ends > Date.now())' \
        "loading keeps the ones that have not ended yet"
}

# A timer that ran out while the shell was down already happened: one message for the
# batch, not a burst of toasts the moment the shell starts.
test_timers_that_ran_out_while_the_shell_was_down_are_reported_once() {
    assert_file_contains "$TIMERS" 'if (ended.length === 1)' "one timer, one message"
    assert_file_contains "$TIMERS" 'timers finished while the shell was not running' \
        "and several timers are counted, not replayed"
}

test_a_timer_ends_as_a_notification() {
    assert_file_contains "$TIMERS" 'Notifs.addShellNotification({' \
        "the completion goes through the shell's own notifications, so it respects DND and lands in the list"
    assert_file_contains "$TIMERS" 'materialIcon: "timer"' "with a timer icon"
}

test_durations_are_read_the_way_they_are_typed() {
    assert_file_contains "$TIMERS" 'function parseDuration(text: string): int' "one parser, shared by the card and the CLI"
    assert_file_contains "$TIMERS" 'if (unit.startsWith("h"))' "hours"
    assert_file_contains "$TIMERS" 'else if (unit.startsWith("s"))' "seconds"
    assert_file_contains "$TIMERS" 'seconds += amount * 60;' "and a bare number is minutes"
}

test_the_card_and_its_setting_exist() {
    assert_file_exists "$CARD"
    assert_file_contains "$CARD" 'Timers.start(' "the card starts timers"
    assert_file_contains "$CARD" 'Timers.remaining(' "and shows what is left"
    assert_file_contains "$CONTENT" 'TimersCard {' "the card is in the utilities drawer"
    assert_file_contains "$CONTENT" '[idleInhibit, timers, capture, quickShare, toggles]' \
        "and in the height the drawer animates to, or it would be clipped"
    assert_file_contains "$SCHEMA" 'showTimers' "the card can be turned off"
    assert_file_contains "$PANEL_PAGE" 'setting: "showTimers"' "from the utilities panel page"
}

test_the_ai_tool_uses_the_same_timers() {
    assert_file_contains "$AI" 'Timers.start(secs, msg);' "a timer the assistant sets is a real one"
    assert_file_not_contains "$AI" 'Qt.createQmlObject(timerQml' \
        "and not an anonymous timer nobody can see or cancel"
    assert_file_contains "$LOADER" 'Timers;' "the service is loaded at startup, so the IPC target exists"
}

test_timers_can_be_driven_without_the_drawer() {
    assert_file_contains "$TIMERS" 'target: "timers"' "there is an IPC target"
    assert_file_contains "$TIMERS" 'function startFor(duration: string, message: string): void' \
        "which takes a duration as typed"
    assert_file_contains "$TIMERS" 'function list(): string' "and can report what is running"
}

run_tests
