pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services

Singleton {
    id: root

    readonly property string checkScript: Quickshell.shellPath("scripts/check-workspace-tracker.sh")

    Timer {
        interval: 5000
        running: true

        onTriggered: check.running = true
    }

    Process {
        id: check

        command: ["bash", root.checkScript]

        onExited: code => {
            if (code !== 3)
                return;

            console.warn("[WorkspaceTrackerGuard] the effect is enabled but not loaded");
            Toaster.toast(qsTr("Workspace tracker effect is not running"), qsTr("KWin stopped loading it after a KDE update. Run caelestia update, then log out and back in."), "extension_off", Toast.Warning);
        }
    }
}
