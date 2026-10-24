pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.utils

// Keep-awake outlives the shell. `PersistentProperties` alone does not survive a
// service restart — it is written when the shell reloads itself, not when it is
// stopped — so the intent is kept in a file of its own and read back on start.
Singleton {
    id: root

    property bool enabled: false
    property date enabledSince: new Date()

    // Reading the file is not a toggle: restoring a value must not be written back,
    // and a toggle made before the file arrives must win over what it says.
    property bool restoring: false
    property bool touched: false

    function restore(text: string): void {
        if (root.touched)
            return;

        let state = {};
        try {
            state = JSON.parse(text) ?? {};
        } catch (err) {
            return;
        }

        root.restoring = true;
        root.enabled = state.enabled === true;
        const since = state.since ? new Date(state.since) : new Date();
        root.enabledSince = isNaN(since.getTime()) ? new Date() : since;
        root.restoring = false;
    }

    onEnabledChanged: {
        if (root.restoring)
            return;

        root.touched = true;
        if (root.enabled)
            root.enabledSince = new Date();
        saveTimer.restart();
    }

    IdleInhibitor {
        enabled: root.enabled
        window: PanelWindow {
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            mask: Region {}
        }
    }

    FileView {
        id: stateFile

        path: `${Paths.state}/keepawake.json`
        watchChanges: false
        printErrors: false

        onLoaded: root.restore(stateFile.text())
    }

    Timer {
        id: saveTimer

        interval: 300
        onTriggered: stateFile.setText(JSON.stringify({ enabled: root.enabled, since: root.enabledSince.toISOString() }))
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.enabled;
        }

        function toggle(): void {
            root.enabled = !root.enabled;
        }

        function enable(): void {
            root.enabled = true;
        }

        function disable(): void {
            root.enabled = false;
        }

        target: "idleInhibitor"
    }
}

