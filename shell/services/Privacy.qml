pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Services
import qs.services

// Who is capturing the microphone or the screen right now. Both kinds of stream
// node exist only while an application is capturing, so their presence is the
// whole signal: playback streams are not private and are ignored, and the shell's
// own recorder is left to the screen capture widget that already reports it.
Singleton {
    id: root

    // Capture streams, one per application. The shell's own capture is skipped so
    // that the indicator only answers "is somebody else listening".
    readonly property var microphones: {
        const names = [];
        for (const stream of Audio.streams) {
            const name = Audio.getStreamName(stream);
            if (stream.properties?.["media.class"] !== "Stream/Input/Audio" || name === Audio.selfAppName || names.includes(name))
                continue;
            names.push(name);
        }
        return names;
    }

    readonly property var videos: PipewireStreamWatcher.activeStreams

    // One row per kind of capture, in the order the popout lists them.
    readonly property var entries: {
        const rows = [];
        if (root.microphones.length > 0)
            rows.push({ icon: "mic", label: qsTr("Microphone"), apps: root.microphones });
        if (root.videos.length > 0)
            rows.push({ icon: "videocam", label: qsTr("Video capture"), apps: root.videos });
        return rows;
    }

    readonly property bool inUse: root.entries.length > 0
    readonly property string icon: root.microphones.length > 0 ? "mic" : "videocam"
}
