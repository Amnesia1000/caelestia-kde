pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

/// Focus sessions: Do Not Disturb that turns itself on for the windows configured in
/// Nexus, while a short list of apps is still allowed through.
///
/// The switch is applied through Notifs' silent setter, so a session does not announce
/// itself with a toast, and it is only ever undone while it is what turned DND on — a
/// DND the user set by hand is theirs to clear.
Singleton {
    id: root

    readonly property bool enabled: GlobalConfig.notifs.focusEnabled
    readonly property var schedules: GlobalConfig.notifs.focusSchedules.values ?? []
    readonly property var allowlist: GlobalConfig.notifs.focusAllowlist ?? []

    /// Recomputed on a timer so a session starts on the minute it is due.
    property date now: new Date()

    /// Whether focus is what turned DND on, so it knows whether to undo it.
    property bool _applied: false

    readonly property var activeSchedule: {
        for (const schedule of root.schedules)
            if (root.scheduleActive(schedule, root.now))
                return schedule;
        return null;
    }

    readonly property bool active: root.enabled && root.activeSchedule !== null
    readonly property string activeName: root.activeSchedule?.name ?? ""
    readonly property bool applied: root._applied && root.active && Notifs.dnd

    function parseTime(value: string): int {
        const parts = (value ?? "").split(":");
        if (parts.length < 2)
            return -1;

        const hours = parseInt(parts[0], 10);
        const minutes = parseInt(parts[1], 10);
        if (isNaN(hours) || isNaN(minutes))
            return -1;

        return Math.max(0, Math.min(23, hours)) * 60 + Math.max(0, Math.min(59, minutes));
    }

    function dayToken(date: date): string {
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.getDay()];
    }

    function scheduleActive(schedule: var, at: date): bool {
        const start = root.parseTime(schedule.start);
        const end = root.parseTime(schedule.end);
        if (start < 0 || end < 0 || start === end)
            return false;

        const days = schedule.days ?? [];
        const minutes = at.getHours() * 60 + at.getMinutes();
        const allowedOn = day => days.length === 0 || days.includes(day);

        if (end > start)
            return allowedOn(root.dayToken(at)) && minutes >= start && minutes < end;

        // Overnight: the part after midnight still belongs to the day it started on.
        if (minutes >= start)
            return allowedOn(root.dayToken(at));

        const yesterday = new Date(at.getFullYear(), at.getMonth(), at.getDate() - 1);
        return minutes < end && allowedOn(root.dayToken(yesterday));
    }

    /// The time a running session ends, for the "until" line in Nexus.
    function activeEnd(): string {
        return root.activeSchedule?.end ?? "";
    }

    function allows(appName: string): bool {
        if (!root.applied || appName === "")
            return false;

        const name = appName.toLowerCase();
        return root.allowlist.some(allowed => allowed.toLowerCase() === name);
    }

    function sync(): void {
        root.now = new Date();

        if (root.active) {
            if (!Notifs.dnd) {
                Notifs.setDndSilently(true);
                root._applied = true;
            }
            return;
        }

        if (root._applied) {
            if (Notifs.dnd)
                Notifs.setDndSilently(false);
            root._applied = false;
        }
    }

    onEnabledChanged: root.sync()
    onSchedulesChanged: root.sync()
    Component.onCompleted: root.sync()

    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        onTriggered: root.sync()
    }
}
