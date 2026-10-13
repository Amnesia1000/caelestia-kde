pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Services.QuickShare

Singleton {
    id: root

    enum State {
        Unknown,
        Ready,
        NeedsSetup,
        Unverified
    }

    readonly property string script: Quickshell.shellPath("scripts/quickshare_setup.sh")

    property int state: QuickShareSetup.State.Unknown
    property bool busy: false
    property string message: ""
    property bool lastRunSucceeded: false

    readonly property bool ready: root.state === QuickShareSetup.State.Ready
    readonly property bool needsSetup: root.state === QuickShareSetup.State.NeedsSetup

    readonly property string status: {
        if (root.message !== "")
            return root.message;
        if (root.ready)
            return qsTr("Avahi and the transfer port are ready");
        if (root.state === QuickShareSetup.State.Unverified)
            return qsTr("The transfer port could not be confirmed");
        if (root.busy)
            return qsTr("Asking the system…");
        return qsTr("Starts the Avahi daemon and opens the transfer port in the firewall");
    }

    signal reported()

    function check(): void {
        if (root.busy)
            return;

        root.state = QuickShareSetup.State.Unknown;
        root.busy = true;
        reportProc.running = true;
    }

    function run(): void {
        if (root.busy)
            return;

        root.busy = true;
        root.message = qsTr("Waiting for administrator rights…");
        root.lastRunSucceeded = false;
        setupProc.running = true;
    }

    Process {
        id: reportProc

        command: ["bash", root.script, "--status", "--port", String(QuickShareService.listenPort)]
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("SETUP="))
                    return;

                switch (line.slice(6).trim()) {
                case "ok":
                    root.state = QuickShareSetup.State.Ready;
                    root.message = "";
                    break;
                case "needed":
                    root.state = QuickShareSetup.State.NeedsSetup;
                    break;
                default:
                    root.state = QuickShareSetup.State.Unverified;
                    break;
                }
            }
        }
        onExited: code => {
            root.busy = false;

            if (code !== 0 || root.state === QuickShareSetup.State.Unknown) {
                root.state = QuickShareSetup.State.Unverified;
                if (root.message === "" && !root.lastRunSucceeded)
                    root.message = qsTr("Quick Share's system setup helper could not be run");
            }

            if (root.lastRunSucceeded) {
                root.lastRunSucceeded = false;
                if (root.state === QuickShareSetup.State.NeedsSetup)
                    root.message = qsTr("Setup ran, but the port is still blocked");
                else if (root.state !== QuickShareSetup.State.Ready)
                    root.message = qsTr("Setup ran; the port cannot be checked again without root");
            }

            root.reported();
        }
    }

    Process {
        id: setupProc

        command: ["pkexec", "bash", root.script, "--port", String(QuickShareService.listenPort)]
        stderr: SplitParser {
            onRead: line => {
                const said = line.trim();
                if (said !== "")
                    root.message = said;
            }
        }
        onExited: code => {
            root.busy = false;
            root.lastRunSucceeded = code === 0;

            if (code === 126 || code === 127)
                root.message = qsTr("Administrator rights were refused");
            else if (code !== 0 && root.message === "")
                root.message = qsTr("Setup failed (%1)").arg(code);

            root.check();
        }
    }
}
