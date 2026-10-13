import QtQuick
import Quickshell.Io
import qs.services

// The colour preview of the wallpaper picker. It owns the matugen process and decides when its
// result may cover the applied scheme:
//   show(source)  preview an image; a call made while a preview runs reruns it for the latest source.
//                 An empty source is a no-op, so a source that is not previewable yet leaves whatever
//                 is on screen alone until the caller can name one (see onVideoThumb)
//   hold()        keep the preview on screen until release(), while the chosen scheme loads
//   release()     the chosen scheme has landed; the preview ends unless the picker wants it again
//   stop()        the preview is over; a result that arrives later is dropped
Item {
    id: root

    property list<string> extraArgs: []

    readonly property bool active: wanted !== ""

    property bool held
    property string wanted
    property string running

    function show(source: string): void {
        if (source === "")
            return;
        wanted = source;
        if (!proc.running)
            start();
    }

    function hold(): void {
        held = true;
    }

    function release(): void {
        if (!held)
            return;
        held = false;
        settle();
    }

    function stop(): void {
        wanted = "";
        settle();
    }

    // The preview covers the applied scheme only while something still wants it: the picker's
    // highlight, or a chosen scheme that has not landed yet.
    function settle(): void {
        if (!active && !held)
            Colours.clearPreview();
    }

    function start(): void {
        if (!active)
            return;
        running = wanted;
        proc.running = true;
    }

    Process {
        id: proc

        command: ["caelestia", "wallpaper", "-p", root.running, ...root.extraArgs]
        stdout: StdioCollector {
            onStreamFinished: {
                // Nothing wants a preview any more and no chosen scheme is waiting on one.
                if (!root.active && !root.held)
                    return;
                // The highlight moved while this ran, so the result belongs to an earlier one.
                if (root.active && root.wanted !== root.running) {
                    Qt.callLater(root.start);
                    return;
                }
                if (Colours.load(text, true))
                    Colours.showPreview = true;
            }
        }
    }
}
