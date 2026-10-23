pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property bool streamActive: PipewireStreamWatcher.streaming || Recorder.running
    property bool sharing: false
    property bool prevDnd: false
    property bool autoDnd: false
    property bool autoReleasing: false

    function evaluate(): void {
        if (root.streamActive) {
            stopTimer.stop();
            if (!root.sharing)
                root.sharing = true;
        } else if (root.sharing) {
            stopTimer.restart();
        }
    }

    function rescan(): void {
        PipewireStreamWatcher.rescan();
        root.evaluate();
    }

    function engageAutoDnd(): void {
        if (root.autoDnd)
            return;
        root.prevDnd = Notifs.dnd;
        root.autoDnd = true;
        Notifs.setDnd(true, false);
    }

    function releaseAutoDnd(): void {
        if (!root.autoDnd)
            return;
        root.autoReleasing = true;
        root.autoDnd = false;
        Notifs.setDnd(root.prevDnd, false);
        root.autoReleasing = false;
    }

    onStreamActiveChanged: root.evaluate()

    onSharingChanged: {
        if (!Config.utilities.toasts.dndWhileStreaming)
            return;
        if (root.sharing && !Notifs.dnd)
            root.engageAutoDnd();
        else if (!root.sharing)
            root.releaseAutoDnd();
    }

    Component.onCompleted: root.evaluate()

    Timer {
        id: stopTimer

        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.streamActive && root.sharing)
                root.sharing = false;
        }
    }

    Connections {
        function onDndWhileStreamingChanged(): void {
            if (!Config.utilities.toasts.dndWhileStreaming)
                root.releaseAutoDnd();
            else if (root.sharing && !Notifs.dnd)
                root.engageAutoDnd();
        }

        target: Config.utilities.toasts
    }

    Connections {
        function onDndChanged(): void {
            if (root.autoReleasing)
                return;
            if (root.autoDnd && !Notifs.dnd)
                root.autoDnd = false;
        }

        target: Notifs
    }
}
