#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/shell/scripts/calendar_events.py"
SERVICE="$REPO_ROOT/shell/services/CalendarEvents.qml"
POPOUT="$REPO_ROOT/shell/modules/bar/popouts/CalendarPopout.qml"
CONFIG="$REPO_ROOT/shell/plugin/src/Caelestia/Config/serviceconfig.hpp"
PAGE="$REPO_ROOT/shell/modules/nexus/pages/services/CalendarPage.qml"
REGISTRY="$REPO_ROOT/shell/modules/nexus/PageCompRegistry.qml"
DICTIONARY="$REPO_ROOT/shell/modules/nexus/PageDictionary.qml"

PYTHON="$(command -v python3 || command -v python)"

# An ICS fixture covering the cases a hand-written parser gets wrong: a named
# timezone, an all-day date, a weekly rule with BYDAY and an EXDATE, and an
# every-other-day rule that has to stop at COUNT.
write_fixture() {
    cat >"$1" <<'ICS'
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:single@test
SUMMARY:Lunch with Sam
LOCATION:Cafe\, Main St
DTSTART;TZID=Europe/London:20991120T123000
DTEND;TZID=Europe/London:20991120T133000
END:VEVENT
BEGIN:VEVENT
UID:allday@test
SUMMARY:Holiday
DTSTART;VALUE=DATE:20991121
DTEND;VALUE=DATE:20991122
END:VEVENT
BEGIN:VEVENT
UID:weekly@test
SUMMARY:Standup
DTSTART:20991102T090000Z
DTEND:20991102T091500Z
RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=6
EXDATE:20991104T090000Z
END:VEVENT
BEGIN:VEVENT
UID:daily@test
SUMMARY:Stretch
DTSTART:20991001T070000Z
DTEND:20991001T071000Z
RRULE:FREQ=DAILY;INTERVAL=2;COUNT=3
END:VEVENT
END:VCALENDAR
ICS
}

test_parser_expands_recurrence_and_timezones() {
    local dir fixture output
    dir="$(mktemp -d)"
    fixture="$dir/test.ics"
    write_fixture "$fixture"

    output="$("$PYTHON" "$SCRIPT" --days 100000 --source "Test=$fixture" 2>&1)"
    rm -rf "$dir"

    assert_contains "$output" '"summary": "Lunch with Sam"' "a plain event must be read"
    assert_contains "$output" '"summary": "Holiday"' "an all-day event must be read"
    # \, is the iCalendar escape for a comma, which the agenda shows verbatim otherwise.
    assert_contains "$output" '"location": "Cafe, Main St"' "escaped commas must be unescaped"
    assert_contains "$output" '"allDay": true' "an all-day event must say so"

    # 2099-11-02 is a Monday: MO,WE over six weeks is 02, 04, 09, 11, 16, 18 — and the
    # EXDATE removes the 4th, so five Mondays/Wednesdays survive.
    assert_contains "$output" '"day": "2099-11-09"' "recurrence must be expanded"
    assert_contains "$output" '"day": "2099-11-11"' "BYDAY must include the second weekday"
    assert_not_contains "$output" '"day": "2099-11-04"' \
        "EXDATE must remove an occurrence"
    assert_contains "$output" '"day": "2099-10-05"' "INTERVAL=2 must skip every other day"
    assert_not_contains "$output" '"day": "2099-10-06"' "INTERVAL=2 must not emit the days between"
    assert_not_contains "$output" '"day": "2099-10-07"' "COUNT=3 must stop the rule"
}

test_unreadable_source_is_reported_not_fatal() {
    local dir output
    dir="$(mktemp -d)"
    write_fixture "$dir/ok.ics"

    output="$("$PYTHON" "$SCRIPT" --days 100000 --source "Good=$dir/ok.ics" --source "Missing=$dir/nope.ics" 2>&1)"
    rm -rf "$dir"

    assert_contains "$output" '"source": "Missing"' "a broken source must be reported"
    assert_contains "$output" '"summary": "Standup"' \
        "the sources that did load must still be returned"
    assert_contains "$output" '"errors"' "the output must carry an errors list"
}

test_service_reads_the_configured_sources() {
    local service config
    service="$(cat "$SERVICE")"
    config="$(cat "$CONFIG")"

    assert_contains "$config" 'CONFIG_GLOBAL_LIST(CalendarSourceList, calendarSources, {})' \
        "calendars must be configured as a list"
    assert_contains "$config" 'CONFIG_PROPERTY(QString, url, {})' "a source needs its address"
    assert_contains "$service" 'Quickshell.shellPath("scripts/calendar_events.py")' \
        "the reading belongs to the script, not to QML"
    assert_contains "$service" '"--source", `${name}=${url}`' "each source must be passed through"
    assert_contains "$service" 'onSourcesChanged: root.refresh()' "editing the list must refresh"
    assert_contains "$service" 'interval: 15 * 60 * 1000' "a calendar must not go stale"
    assert_contains "$service" 'start: new Date(item.startMs)' \
        "the UI needs dates, not raw milliseconds"
}

test_agenda_is_shown_in_the_calendar_popout() {
    local popout dash
    popout="$(cat "$POPOUT")"
    dash="$REPO_ROOT/shell/modules/dashboard/dash/Calendar.qml"

    assert_contains "$popout" 'CalendarEvents.upcoming(3)' "the popout must list the next days of events"
    assert_contains "$popout" 'CalendarEvents.hasEventsOn(dayItem.model.date)' \
        "days with events must be marked in the grid"
    assert_contains "$popout" 'qsTr("Add a calendar in Settings → Calendar")' \
        "an empty agenda must say where to configure one"
    assert_contains "$(cat "$dash")" 'CalendarEvents.hasEventsOn(dayItem.model.date)' \
        "the dashboard grid must mark those days too"
}

test_calendar_settings_page_is_reachable() {
    local page registry dictionary
    page="$(cat "$PAGE")"
    registry="$(cat "$REGISTRY")"
    dictionary="$(cat "$DICTIONARY")"

    assert_contains "$page" 'GlobalConfig.services.calendarSources.insert' "the page must add sources"
    assert_contains "$page" 'GlobalConfig.services.calendarSources.remove(index)' "and remove them"
    assert_contains "$page" 'Secret address in iCal format' \
        "Google Calendar's export has to be named, or nobody finds it"
    assert_contains "$registry" 'Component { CalendarPage {} }' "the page must be registered"
    assert_contains "$dictionary" 'pagePath: "services/CalendarPage.qml"' "and be searchable"
}

run_tests
