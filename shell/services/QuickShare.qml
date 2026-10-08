pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.Services.QuickShare
import qs.services

/// The shell-side part of Quick Share: the prompt for a transfer another device
/// started, and turning the service on at shell launch. The service itself is a QML
/// singleton consumers use directly (QuickShareService); this only exists because the
/// prompt outlives a single drawer, and referencing it is what brings the service up
/// on launch (see shell.qml).
Singleton {
    id: root

    /// The live incoming-transfer prompt, while one is pending. Null otherwise.
    property NotifData prompt: null
    /// Whether `prompt` is still the notification Notifs is showing. The user can
    /// dismiss the prompt from the notification centre at any point, which drops it
    /// from Notifs.list, so the handle below is only safe to touch while this holds.
    readonly property bool promptLive: root.prompt !== null && Notifs.list.includes(root.prompt) && !root.prompt.closed
    property string promptDeviceName: ""
    property string promptFileName: ""
    property real promptFileSize: 0
    property string promptPin: ""
    /// Whether an incoming request is still waiting for an answer. It outlives the
    /// prompt: once the prompt is dismissed the notification loses the only Accept /
    /// Decline the user had, so this is what keeps the request answerable from the
    /// Quick Share card in the utilities drawer.
    property bool pendingIncoming: false

    readonly property string setupScript: Quickshell.shellPath("scripts/quickshare_setup.sh")
    property bool startupComplete: false
    property bool systemReady: false
    property bool setupAttempted: false
    property bool pendingEnable: false
    property bool systemSetupBusy: false
    readonly property bool enabling: root.pendingEnable || root.systemSetupBusy
    property string systemSetupMessage: ""
    property bool setupHintShown: false

    readonly property string systemSetupLabel: root.systemSetupBusy ? qsTr("Setting up…") : qsTr("Set up system access")
    readonly property string systemSetupSubtext: root.systemSetupBusy ? qsTr("Waiting for administrator rights…")
        : root.systemReady ? qsTr("Avahi and the transfer port are ready")
        : root.systemSetupMessage !== "" ? root.systemSetupMessage
        : qsTr("Starts the Avahi daemon and opens the transfer port in the firewall")

    /// Turns the service on or off. Turning it on also makes this shell visible to
    /// nearby devices, which the service keeps in step.
    function toggle(): void {
        root.setEnabled(!QuickShareService.isEnabled);
    }

    function setEnabled(on: bool): void {
        if (!on) {
            root.pendingEnable = false;
            QuickShareService.isEnabled = false;
            return;
        }

        if (!root.startupComplete || root.systemReady || root.setupAttempted) {
            QuickShareService.isEnabled = true;
            return;
        }

        root.pendingEnable = true;
        statusProc.running = true;
    }

    function statusValue(text: string, key: string): string {
        const prefix = key + "=";
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.startsWith(prefix))
                return line.slice(prefix.length).trim();
        }
        return "unknown";
    }

    function applySystemStatus(text: string): void {
        const setup = root.statusValue(text, "SETUP");

        if (setup === "ok") {
            root.systemReady = true;
            root.systemSetupMessage = "";
            root.enablePending();
            return;
        }

        if (setup === "needed" && !root.setupAttempted) {
            Toaster.toast(qsTr("Quick Share"),
                qsTr("Quick Share needs administrator rights to start Avahi and open the transfer port."), "info");
            root.runSystemSetup();
            return;
        }

        if (!root.setupHintShown) {
            root.setupHintShown = true;
            Toaster.toast(qsTr("Quick Share"),
                root.systemSetupMessage !== "" ? root.systemSetupMessage
                    : qsTr("Quick Share could not confirm the transfer port is reachable. Allow port %1 in Settings -> Services -> Quick Share.").arg(QuickShareService.listenPort),
                "warning");
        }
        root.enablePending();
    }

    function enablePending(): void {
        if (!root.pendingEnable)
            return;

        root.pendingEnable = false;
        QuickShareService.isEnabled = true;
    }

    function runSystemSetup(): void {
        if (root.systemSetupBusy)
            return;

        root.setupAttempted = true;
        root.systemSetupBusy = true;
        root.systemSetupMessage = "";
        setupProc.running = true;
    }

    function acceptIncomingTransfer(): void {
        root.pendingIncoming = false;
        QuickShareService.acceptIncomingTransfer();
    }

    function rejectIncomingTransfer(): void {
        root.pendingIncoming = false;
        QuickShareService.rejectIncomingTransfer();
    }

    function clearPrompt(): void {
        if (root.promptLive)
            root.prompt.close();
        root.prompt = null;
        root.promptDeviceName = "";
        root.promptFileName = "";
        root.promptFileSize = 0;
        root.promptPin = "";
    }

    function promptBody(): string {
        let body = qsTr("%1 wants to send you %2 (%3)").arg(root.promptDeviceName).arg(root.promptFileName).arg(Units.formatBytes(root.promptFileSize));
        if (root.promptPin)
            body += qsTr("\nPIN: %1").arg(root.promptPin);
        return body;
    }

    Component.onCompleted: {
        if (GlobalConfig.services.quickShareAutoStart)
            QuickShareService.isEnabled = true;

        root.startupComplete = true;
    }

    Process {
        id: statusProc

        command: ["bash", root.setupScript, "--status", "--port", String(QuickShareService.listenPort)]
        stdout: StdioCollector {
            onStreamFinished: root.applySystemStatus(text)
        }
    }

    Process {
        id: setupProc

        command: ["pkexec", "bash", root.setupScript, "--port", String(QuickShareService.listenPort)]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const message = (text || "").trim();
                if (message !== "")
                    root.systemSetupMessage = message;
            }
        }
        onExited: code => {
            root.systemSetupBusy = false;
            if (code !== 0 && root.systemSetupMessage === "") {
                if (code === 126 || code === 127)
                    root.systemSetupMessage = qsTr("Administrator rights were refused.");
                else
                    root.systemSetupMessage = qsTr("Setup failed (%1)").arg(code);
            }

            statusProc.running = true;
        }
    }

    Connections {
        function onIncomingTransferRequested(deviceName: string, fileName: string, fileSize: real): void {
            root.clearPrompt();
            root.pendingIncoming = true;
            root.promptDeviceName = deviceName;
            root.promptFileName = fileName;
            root.promptFileSize = fileSize;
            root.prompt = Notifs.addShellNotification({
                summary: qsTr("Incoming file"),
                body: root.promptBody(),
                appName: qsTr("Quick Share"),
                materialIcon: "near_me",
                actions: [
                    { identifier: "decline", text: qsTr("Decline"), invoke: () => root.rejectIncomingTransfer() },
                    { identifier: "accept", text: qsTr("Accept"), invoke: () => root.acceptIncomingTransfer() }
                ]
            });
        }

        // The few seconds between the request and the PIN are what the prompt has
        // to cover, so the same prompt is rewritten rather than a second one made.
        function onIncomingTransferPinReady(pinCode: string): void {
            root.promptPin = pinCode;
            if (root.promptLive)
                root.prompt.body = root.promptBody();
        }

        function onIncomingTransferFinished(success: bool): void {
            // Ended either way: the request is no longer answerable.
            root.pendingIncoming = false;
            root.clearPrompt();
        }

        function onErrorOccurred(message: string): void {
            Toaster.toast(qsTr("Quick Share"), message, "error");
        }

        target: QuickShareService
    }
}
