pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

/// KScreen owns the outputs. The shell reads its JSON and hands every change back to
/// `kscreen-doctor`, in the same one-shot form System Settings uses, so the two can never
/// disagree about the layout: there is no second copy of the screen setup to keep in step.
Singleton {
    id: root

    property var outputs: []
    property bool failed: false

    /// A machine without kscreen cannot be asked anything, and an empty list would read as
    /// "no screens" rather than "not installed", so the page says which one it is.
    readonly property bool available: !root.failed
    readonly property var connected: root.outputs.filter(output => output.connected)
    readonly property var enabled: root.connected.filter(output => output.enabled)

    readonly property var rotationNames: ["none", "left", "inverted", "right"]
    readonly property var rotationLabels: [qsTr("Normal"), qsTr("Left"), qsTr("Upside down"), qsTr("Right")]

    function outputFor(name: string): var {
        return root.outputs.find(output => output.name === name) ?? null;
    }

    /// The modes worth offering, largest and fastest first, so the current one sits near
    /// the top of the menu instead of buried in the order the driver reports.
    function modesFor(output: var): var {
        return (output?.modes ?? []).slice().sort((a, b) => b.size.width * b.size.height - a.size.width * a.size.height || b.refreshRate - a.refreshRate);
    }

    function modeLabel(mode: var): string {
        return `${mode.size.width} x ${mode.size.height} · ${Math.round(mode.refreshRate)} Hz`;
    }

    function rotationName(rotation: int): string {
        return root.rotationNames[Math.log2(rotation)] ?? "none";
    }

    function refresh(): void {
        readProcess.running = false;
        readProcess.running = true;
    }

    function apply(settings: list<string>): void {
        if (settings.length === 0)
            return;

        writeProcess.command = ["kscreen-doctor", ...settings];
        writeProcess.running = true;
    }

    function setEnabled(name: string, on: bool): void {
        root.apply([`output.${name}.${on ? "enable" : "disable"}`]);
    }

    function setMode(name: string, modeId: string): void {
        root.apply([`output.${name}.mode.${modeId}`]);
    }

    function setScale(name: string, scale: real): void {
        root.apply([`output.${name}.scale.${scale}`]);
    }

    function setRotation(name: string, rotation: string): void {
        root.apply([`output.${name}.rotation.${rotation}`]);
    }

    function setHdr(name: string, on: bool): void {
        root.apply([`output.${name}.hdr.${on ? "enable" : "disable"}`]);
    }

    Component.onCompleted: root.refresh()

    Process {
        id: readProcess

        command: ["kscreen-doctor", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.outputs = JSON.parse(text).outputs ?? [];
                    root.failed = false;
                } catch (error) {
                    root.outputs = [];
                    root.failed = true;
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                root.outputs = [];
                root.failed = true;
            }
        }
    }

    Process {
        id: writeProcess

        // KScreen answers the read with the layout it just applied, so the page shows what
        // really happened rather than what was asked for.
        onExited: root.refresh()
    }
}
