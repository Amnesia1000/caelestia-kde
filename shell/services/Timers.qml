pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

/// The countdown timers that are running, how long they have left, and what to say
/// when one ends.
///
/// A timer stores the moment it ends rather than the time left, and that moment is what
/// is written to disk: a timer set for 25 minutes still has 23 left if the shell restarts
/// two minutes later, which a counter reset on reload would quietly lose. One ticker runs
/// for all of them.
Singleton {
    id: root

    /// `{ id, ends, seconds, message }`, soonest first.
    property list<var> list: []
    /// Read so that every view showing a countdown recomputes with the ticker.
    property double now: Date.now()
    property bool loaded: false
    property string savedState: ""

    readonly property int count: root.list.length
    readonly property string appName: qsTr("Timers")

    function remaining(timer: var): int {
        return Math.max(0, Math.ceil((timer.ends - root.now) / 1000));
    }

    function start(seconds: int, message: string): void {
        if (seconds <= 0)
            return;

        const timer = {
            id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
            ends: Date.now() + seconds * 1000,
            seconds: seconds,
            message: message.trim()
        };
        root.list = [...root.list, timer].sort((a, b) => a.ends - b.ends);
    }

    function cancel(id: string): void {
        root.list = root.list.filter(timer => timer.id !== id);
    }

    function clear(): void {
        root.list = [];
    }

    /// Reads a duration the way someone types one: `25` and `25m` are minutes, `90s` is
    /// seconds, and `1h30` is an hour and a half. Returns 0 when there is no number in it.
    function parseDuration(text: string): int {
        const value = text.trim().toLowerCase();
        if (value === "")
            return 0;

        let seconds = 0;
        let found = false;
        const pattern = /(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)?/g;
        let match;
        while ((match = pattern.exec(value)) !== null) {
            const amount = Number(match[1]);
            if (!isFinite(amount))
                continue;

            found = true;
            const unit = match[2] ?? "";
            if (unit.startsWith("h"))
                seconds += amount * 3600;
            else if (unit.startsWith("s"))
                seconds += amount;
            else
                seconds += amount * 60;
        }

        return found ? Math.round(seconds) : 0;
    }

    function announce(message: string): void {
        Notifs.addShellNotification({
            appName: root.appName,
            summary: qsTr("Timer finished"),
            body: message.length > 0 ? message : qsTr("Time is up."),
            materialIcon: "timer"
        });
    }

    function tick(): void {
        root.now = Date.now();

        const due = root.list.filter(timer => timer.ends <= root.now);
        if (due.length === 0)
            return;

        root.list = root.list.filter(timer => timer.ends > root.now);
        for (const timer of due)
            root.announce(timer.message);
    }

    function serialize(): string {
        return JSON.stringify(root.list.map(timer => ({
                        id: timer.id,
                        ends: timer.ends,
                        seconds: timer.seconds,
                        message: timer.message
                    })));
    }

    function save(): void {
        const data = root.serialize();
        if (data === root.savedState)
            return;
        root.savedState = data;
        storage.setText(data);
    }

    onListChanged: {
        if (root.loaded)
            root.save();
    }

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.count > 0
        onTriggered: root.tick()
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/timers.json`

        onLoaded: {
            let data;
            try {
                data = JSON.parse(text());
            } catch (err) {
                Logger.log("[Timers] saved timers are corrupt, starting fresh:", err);
                data = [];
            }
            if (!Array.isArray(data))
                data = [];

            // Anything saved by an older version, or by hand, has to carry a real end
            // time: a timer that cannot say when it ends can never fire.
            data = data.filter(timer => timer && isFinite(Number(timer.ends))).map(timer => ({
                            id: String(timer.id ?? timer.ends),
                            ends: Number(timer.ends),
                            seconds: Number(timer.seconds) || 0,
                            message: String(timer.message ?? "")
                        }));

            // A timer that ran out while the shell was down already happened: say so
            // once, rather than firing a burst of toasts the moment the shell starts.
            const ended = data.filter(timer => timer.ends <= Date.now());
            root.list = data.filter(timer => timer.ends > Date.now()).sort((a, b) => a.ends - b.ends);
            root.loaded = true;
            root.savedState = root.serialize();

            if (ended.length === 1)
                root.announce(ended[0].message);
            else if (ended.length > 1)
                root.announce(qsTr("%1 timers finished while the shell was not running.").arg(ended.length));
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                root.savedState = "[]";
                Qt.callLater(() => storage.setText("[]"));
            }
        }
    }

    IpcHandler {
        function start(seconds: int, message: string): void {
            root.start(seconds, message);
        }

        /// Starts a timer from a duration as typed, e.g. `25m`, `1h30` or `90s`.
        function startFor(duration: string, message: string): void {
            root.start(root.parseDuration(duration), message);
        }

        function cancel(id: string): void {
            root.cancel(id);
        }

        function clear(): void {
            root.clear();
        }

        /// The running timers, soonest first, with the seconds each has left.
        function list(): string {
            return JSON.stringify(root.list.map(timer => ({
                            id: timer.id,
                            message: timer.message,
                            remaining: root.remaining(timer)
                        })));
        }

        target: "timers"
    }
}
