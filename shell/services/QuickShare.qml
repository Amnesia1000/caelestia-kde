pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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

    /// Turns the service on or off, keeping the "visible to nearby devices" flag in
    /// step so that toggling off stops advertising as well.
    function toggle(): void {
        const enabled = !QuickShareService.isEnabled;
        QuickShareService.isEnabled = enabled;
        QuickShareService.isVisible = enabled;
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
        if (!GlobalConfig.services.quickShareAutoStart)
            return;

        QuickShareService.isEnabled = true;
        QuickShareService.isVisible = true;
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
