pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/// KScreen owns the outputs. The shell reads its JSON and hands every change back to
/// `kscreen-doctor`, in the same one-shot form System Settings uses, so the two can never
/// disagree about the layout: there is no second copy of the screen setup to keep in step.
Singleton {
    id: root

    property var outputs: []
    property bool failed: false
    /// What each panel says it can show, keyed by output name: read from its EDID, because
    /// KScreen stores whatever it is asked for and cannot tell us whether the screen can.
    property var panels: ({})

    /// A machine without kscreen cannot be asked anything, and an empty list would read as
    /// "no screens" rather than "not installed", so the page says which one it is.
    readonly property bool available: !root.failed
    readonly property var connected: root.outputs.filter(output => output.connected)
    readonly property var enabled: root.connected.filter(output => output.enabled)

    readonly property var rotationNames: ["none", "left", "inverted", "right"]
    readonly property var rotationLabels: [qsTr("Normal"), qsTr("Left"), qsTr("Upside down"), qsTr("Right")]

    /// KWin resets a panel to full brightness whenever its colour mode or resolution
    /// changes, so everything that writes the layout announces it and lets brightness be
    /// put back afterwards.
    signal layoutApplied

    /// HDR is offered only for a panel that advertises an HDR transfer function, so the
    /// switch is not there to be flipped on a screen that cannot show the result.
    function supportsHdr(output: var): bool {
        return root.panels[output?.name]?.hdr === true;
    }

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

    /// The wide colour gamut goes with HDR rather than on its own, which is what KDE's own
    /// switch does: HDR content is graded in BT.2020, so enabling one without the other is
    /// a half-applied change.
    function setHdr(name: string, on: bool): void {
        root.apply([`output.${name}.hdr.${on ? "enable" : "disable"}`, `output.${name}.wcg.${on ? "enable" : "disable"}`]);
    }

    function readPanels(): void {
        const names = root.connected.map(output => output.name);
        if (names.length === 0)
            return;

        panelsProcess.command = ["python3", Quickshell.shellPath("scripts/panel_capabilities.py"), ...names];
        panelsProcess.running = true;
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
                    root.readPanels();
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
        id: panelsProcess

        stdout: StdioCollector {
            onStreamFinished: {
                let reports = [];
                try {
                    reports = JSON.parse(text);
                } catch (error) {
                    // An unreadable EDID is not an error worth a page of its own: the HDR
                    // row simply stays away, because nothing claimed the screen can do it.
                    reports = [];
                }

                const panels = {};
                for (const report of reports)
                    panels[report.output] = report;
                root.panels = panels;
            }
        }
    }

    Process {
        id: writeProcess

        // KScreen answers the read with the layout it just applied, so the page shows what
        // really happened rather than what was asked for.
        onExited: {
            root.refresh();
            root.layoutApplied();
        }
    }
}
