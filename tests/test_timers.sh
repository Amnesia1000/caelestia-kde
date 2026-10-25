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
STYLED_INPUT="$REPO_ROOT/shell/components/controls/StyledInputField.qml"

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
    assert_file_contains "$TIMERS" 'return Duration.parse(text);' "and it is the one in duration.js, which a test can run"
}

# The grammar is pure, so it is executed rather than grepped: drive_duration evaluates
# duration.js the way QML does and runs the given script with node's assert.
drive_duration() {
    DURATION_DIR="$REPO_ROOT/shell/services" node -e '
const fs = require("fs");
const assert = require("assert");
const src = fs.readFileSync(process.env.DURATION_DIR + "/duration.js", "utf8").replace(/^\.pragma library$/m, "");
const names = [...src.matchAll(/^(?:function|var) (\w+)/gm)].map(m => m[1]);
const Duration = new Function(src + "\nreturn {" + names.join(",") + "};")();
'"$1"'
console.log("ok");' 2>&1
}

check_duration() {
    local message="$1" script="$2" out
    out="$(drive_duration "$script")"
    [[ "$out" == "ok" ]] || fail_with_output "$message" "$out"
}

test_a_bare_number_is_minutes_and_a_unit_is_read_as_written() {
    check_duration "durations have to read the way someone types them" '
assert.strictEqual(Duration.parse("25"), 1500, "a bare number is minutes");
assert.strictEqual(Duration.parse("25m"), 1500, "and so is m");
assert.strictEqual(Duration.parse("90s"), 90, "s is seconds");
assert.strictEqual(Duration.parse("1h30"), 5400, "an hour and a half, written in one go");
assert.strictEqual(Duration.parse("1h 30m"), 5400, "and with the space people type");
assert.strictEqual(Duration.parse(" 45 min "), 2700, "the long form survives padding");
'
}

test_junk_is_not_a_duration() {
    check_duration "anything with no number in it has to be zero, not a guess" '
assert.strictEqual(Duration.parse(""), 0, "nothing typed");
assert.strictEqual(Duration.parse("   "), 0, "whitespace");
assert.strictEqual(Duration.parse("later"), 0, "words");
assert.strictEqual(Duration.parse("m"), 0, "a unit with no number");
assert.strictEqual(Duration.parse(null), 0, "and a missing field does not throw");
'
}

test_the_card_and_its_setting_exist() {
    assert_file_exists "$CARD"
    assert_file_contains "$CARD" "Timers.start(" "the card starts timers"
    assert_file_contains "$CARD" "Timers.remaining(" "and shows what is left"
    assert_file_contains "$CONTENT" "TimersCard {" "the card is in the utilities drawer"
    assert_file_contains "$CONTENT" 'const visible = [...layout.children].filter(card => card.visible' \
        "and the height the drawer animates to is read from the layout, not from a second list of names"
    assert_file_contains "$SCHEMA" "showTimers" "the card can be turned off"
    assert_file_contains "$PANEL_PAGE" 'setting: "showTimers"' "from the utilities panel page"
}

# Enter starts a timer. Losing focus does not: `editingFinished` fires for both, and a
# timer that starts because the pointer left the field is a timer nobody asked for.
test_a_timer_starts_on_enter_and_not_on_a_blur() {
    assert_file_contains "$STYLED_INPUT" 'signal accepted' "the field offers Enter on its own"
    assert_file_contains "$STYLED_INPUT" 'root.accepted();' "fed by the text field's own accepted"
    assert_file_contains "$CARD" 'onAccepted: root.beginTyped()' "the card commits on Enter"
    assert_file_not_contains "$CARD" 'onEditingFinished' "and never on focus loss"
    assert_file_contains "$CARD" 'readonly property int typedSeconds: Timers.parseDuration(durationField.text)' \
        "one reading of the field, shared by the button and both fields"
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
