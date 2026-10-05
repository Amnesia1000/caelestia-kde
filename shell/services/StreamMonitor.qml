pragma ComponentBehavior: Bound
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

    function evaluate(): void {
        const positive = root.videoFound || root.obsFound || Recorder.running;
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
                const node = nodes[i] || {};
                if (node.type !== "PipeWire:Interface:Node")
                    continue;

                const props = (node.info || {}).props || {};
                const mediaClass = props["media.class"] || "";
                const nodeName = props["node.name"] || "";
                const mediaName = props["media.name"] || "";
                const mediaRole = props["media.role"] || "";

                if (mediaClass === "Stream/Input/Video") {
                    if (nodeName === "quickshell" || nodeName === "caelestia-shell" || mediaName.indexOf("plasma-screencast-") === 0)
                        continue;
                    found = true;
                    break;
                }

                if (mediaClass === "Video/Source") {
                    if (mediaRole === "Camera" || nodeName.indexOf("v4l2_input") === 0)
                        continue;
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
            if (line.indexOf("\"obs\"") < 0 && line.indexOf("\"obs64\"") < 0 && line.indexOf("\"obs-studio\"") < 0)
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

    Connections {
        function onDndWhileStreamingChanged(): void {
            if (!Config.utilities.toasts.dndWhileStreaming && root.autoDnd) {
                root.autoDnd = false;
                Notifs.dnd = root.prevDnd;
            } else if (Config.utilities.toasts.dndWhileStreaming && root.sharing && !Notifs.dnd) {
                root.prevDnd = Notifs.dnd;
                root.autoDnd = true;
                Notifs.dnd = true;
            }
        }

        target: Config.utilities.toasts
    }

    Connections {
        function onDndChanged(): void {
            if (root.autoDnd && !Notifs.dnd)
                root.autoDnd = false;
        }

        target: Notifs
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
