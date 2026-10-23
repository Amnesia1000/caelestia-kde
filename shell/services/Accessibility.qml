pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

/// The accessibility switches the shell can drive, and the one thing it cannot: the
/// system text size, which belongs to KDE.
///
/// Everything visual the shell draws comes from its own token fonts, so enlarging the
/// text in System Settings used to leave the shell untouched. `followSystemScale` keeps
/// the two together by reading KDE's font size and writing it as the shell's type scale.
/// The rest of the page drives KWin itself: the magnifier, colour inversion and the
/// colour-blindness filters are KWin effects, so the shell only loads and unloads them.
Singleton {
    id: root

    /// KDE's default font size, and the size the shell's own type scale is built for.
    readonly property int basePointSize: 10
    readonly property real minScale: 0.5
    readonly property real maxScale: 2

    property int systemPointSize: 0
    property bool zoomLoaded: false
    property bool invertLoaded: false
    property bool colourFilterLoaded: false
    property bool screenReaderInstalled: false

    readonly property real systemScale: {
        const points = root.systemPointSize > 0 ? root.systemPointSize : root.basePointSize;
        const scale = points / root.basePointSize;
        return Math.max(root.minScale, Math.min(root.maxScale, Math.round(scale * 100) / 100));
    }

    readonly property bool followSystem: GlobalConfig.appearance.font.followSystemScale

    function applySystemScale(): void {
        if (!root.followSystem)
            return;
        const current = GlobalConfig.appearance.font.scale;
        if (Math.abs(current - root.systemScale) < 0.005)
            return;

        GlobalConfig.appearance.font.scale = root.systemScale;
        GlobalConfig.save();
    }

    function setEffect(name: string, on: bool): void {
        const method = on ? "loadEffect" : "unloadEffect";
        Quickshell.execDetached(["qdbus6", "org.kde.KWin", "/Effects", `org.kde.kwin.Effects.${method}`, name]);
        if (name === "zoom")
            root.zoomLoaded = on;
        else if (name === "invert")
            root.invertLoaded = on;
        else if (name === "colorblindnesscorrection")
            root.colourFilterLoaded = on;
    }

    function startScreenReader(): void {
        if (root.screenReaderInstalled)
            Quickshell.execDetached(["orca"]);
    }

    function applyState(output: string): void {
        const lines = output.trim().split("\n");
        if (lines.length >= 4) {
            root.zoomLoaded = lines[0].trim() === "true";
            root.invertLoaded = lines[1].trim() === "true";
            root.colourFilterLoaded = lines[2].trim() === "true";
            root.screenReaderInstalled = lines[3].trim() === "yes";
        }
        root.applySystemScale();
    }

    function refresh(): void {
        if (!stateProcess.running)
            stateProcess.running = true;
        if (!fontProcess.running)
            fontProcess.running = true;
    }

    onFollowSystemChanged: root.applySystemScale()
    Component.onCompleted: root.refresh()

    /// One round trip for the three effects and the screen reader, rather than four.
    Process {
        id: stateProcess

        command: [
            "bash", "-c",
            "for e in zoom invert colorblindnesscorrection; do qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded \"$e\" 2>/dev/null || echo false; done; command -v orca >/dev/null && echo yes || echo no"
        ]

        stdout: StdioCollector {
            onStreamFinished: root.applyState(text)
        }
    }

    /// `font` is a KConfig entry shaped "Family,11,-1,5,…": the point size is the
    /// second field, and an absent key means KDE's default is in use.
    Process {
        id: fontProcess

        command: ["kreadconfig6", "--file", "kdeglobals", "--group", "General", "--key", "font"]

        stdout: StdioCollector {
            onStreamFinished: {
                const size = parseInt((text.split(",")[1] ?? "").trim(), 10);
                root.systemPointSize = isNaN(size) || size <= 0 ? 0 : size;
                root.applySystemScale();
            }
        }
    }

    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
