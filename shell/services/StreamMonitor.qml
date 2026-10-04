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

    property bool sharing: false
    property bool prevDnd: false
    property bool autoDnd: false
    property bool videoFound: false
    property bool obsFound: false
    property int seedHits: 0
    property int seedMisses: 0

    function evaluate() {
        const positive = root.videoFound || root.obsFound;
        if (positive) {
            root.seedMisses = 0;
            if (++root.seedHits >= 2 && !root.sharing)
                root.sharing = true;
        } else {
            root.seedHits = 0;
            if (++root.seedMisses >= 3 && root.sharing)
                root.sharing = false;
        }
    }

    function parseDump(text: string): void {
        let found = false;
        try {
            const nodes = JSON.parse(text || "[]");
            for (let i = 0; i < nodes.length; i++) {
                const props = ((nodes[i] || {}).info || {}).props || {};
                if (nodes[i].type === "PipeWire:Interface:Node" && props["media.class"] === "Video/Source") {
                    found = true;
                    break;
                }
            }
        } catch (e) {
        }
        root.videoFound = found;
        root.evaluate();
    }

    function parseSs(text: string): void {
        let found = false;
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.indexOf("\"obs\"") < 0)
                continue;
            const fields = line.trim().split(/\s+/);
            for (let f = 0; f < fields.length; f++) {
                if (fields[f].indexOf("users:") === 0)
                    continue;
                const port = fields[f].slice(fields[f].lastIndexOf(":") + 1);
                if (port === "1935" || port === "80" || port === "443") {
                    found = true;
                    break;
                }
            }
            if (found)
                break;
        }
        root.obsFound = found;
        root.evaluate();
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
            if (!ssProc.running)
                ssProc.running = true;
        }
    }

    Process {
        id: dumpProc

        command: ["pw-dump"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDump(text)
        }
    }

    Process {
        id: ssProc

        command: ["ss", "-tnp", "state", "established"]
        stdout: StdioCollector {
            onStreamFinished: root.parseSs(text)
        }
    }
}
