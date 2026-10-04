pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.services
import qs.utils

Singleton {
    id: root

    property bool prevDnd: false
    property bool autoDnd: false

    readonly property bool sharing: {
        try {
            const nodes = JSON.parse(collector.text || "[]");
            for (let i = 0; i < nodes.length; i++) {
                const props = ((nodes[i] || {}).info || {}).props || {};
                if (nodes[i].type === "PipeWire:Interface:Node" && props["media.class"] === "Video/Source")
                    return true;
            }
        } catch (e) {
        }
        return false;
    }

    onSharingChanged: {
        if (!Config.utilities.toasts.dndWhileStreaming)
            return;
        if (root.sharing && !Notifs.dnd) {
            root.prevDnd = Notifs.dnd;
            root.autoDnd = true;
            Notifs.dnd = true;
        } else if (!root.sharing && root.autoDnd) {
            root.autoDnd = false;
            Notifs.dnd = root.prevDnd;
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            if (!dumpProc.running)
                dumpProc.running = true;
        }
    }

    Process {
        id: dumpProc

        command: ["pw-dump"]
        stdout: StdioCollector {
            id: collector
        }
    }
}
