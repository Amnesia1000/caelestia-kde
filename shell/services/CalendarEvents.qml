pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

/// The events of the calendars configured in Nexus, as the agenda shows them.
///
/// The reading itself belongs to `scripts/calendar_events.py`: iCalendar is a
/// text format with recurrence rules, and parsing it in QML would mean a second
/// implementation of something the standard library already handles. The script
/// hands back one sorted list, and this only decides when to ask for it again.
Singleton {
    id: root

    readonly property var sources: GlobalConfig.services.calendarSources.values ?? []
    readonly property int days: Math.max(1, GlobalConfig.services.calendarDays)

    property var events: []
    property var errors: []
    property bool loading: false
    property double updatedAt: 0

    readonly property bool configured: root.sources.length > 0
    readonly property var nextEvent: {
        const now = Date.now();
        for (const event of root.events)
            if (event.end.getTime() > now)
                return event;
        return null;
    }

    readonly property var command: {
        const args = ["python3", Quickshell.shellPath("scripts/calendar_events.py"), "--days", String(root.days)];
        for (const source of root.sources) {
            const name = (source.name || "").trim() || "Calendar";
            const url = (source.url || "").trim();
            if (url)
                args.push("--source", `${name}=${url}`);
        }
        return args;
    }

    function dayKey(date: date): string {
        return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
    }

    function eventsOn(date: date): var {
        const key = root.dayKey(date);
        return root.events.filter(event => event.day === key);
    }

    function hasEventsOn(date: date): bool {
        const key = root.dayKey(date);
        return root.events.some(event => event.day === key);
    }

    /// The events of the next `days` days, grouped by day, skipping empty days.
    function upcoming(limit: int): var {
        const out = [];
        let current = null;
        for (const event of root.events) {
            if (event.end.getTime() < Date.now() && !event.allDay)
                continue;
            if (!current || current.day !== event.day) {
                current = { day: event.day, date: event.start, events: [] };
                out.push(current);
            }
            current.events.push(event);
            if (out.length >= limit)
                break;
        }
        return out;
    }

    function apply(output: string): void {
        root.loading = false;
        try {
            const parsed = JSON.parse(output);
            root.errors = parsed.errors ?? [];
            root.events = (parsed.events ?? []).map(item => ({
                uid: item.uid,
                summary: item.summary,
                location: item.location,
                source: item.source,
                allDay: item.allDay,
                day: item.day,
                start: new Date(item.startMs),
                end: new Date(item.endMs)
            }));
            root.updatedAt = Date.now();
        } catch (error) {
            root.errors = [{ source: "Calendar", error: String(error) }];
        }
    }

    function refresh(): void {
        if (!root.configured || calendarProcess.running)
            return;
        root.loading = true;
        calendarProcess.running = true;
    }

    onSourcesChanged: root.refresh()
    onDaysChanged: root.refresh()
    Component.onCompleted: root.refresh()

    Process {
        id: calendarProcess

        command: root.command

        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }

        onExited: code => {
            root.loading = false;
            if (code !== 0 && root.errors.length === 0)
                root.errors = [{ source: "Calendar", error: `calendar_events.py exited with ${code}` }];
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
