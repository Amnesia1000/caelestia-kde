pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.services

/// Adapter over the C++ QuickShareService singleton, plus the shell-side parts of
/// the feature: the incoming-transfer prompt and the auto-start on shell launch.
/// Referencing this singleton is what creates the C++ service, so the shell root
/// holds a reference to it (see shell.qml) rather than letting the drawer be first.
Singleton {
    id: root

    readonly property bool isEnabled: QuickShareService.isEnabled
    readonly property bool isVisible: QuickShareService.isVisible
    readonly property var nearbyDevices: QuickShareService.nearbyDevices
    readonly property var transferHistory: QuickShareService.transferHistory

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

    function setEnabled(enabled: bool): void {
        QuickShareService.isEnabled = enabled;
    }

    function setVisible(visible: bool): void {
        QuickShareService.isVisible = visible;
    }

    function toggle(): void {
        const enabled = !root.isEnabled;
        root.setEnabled(enabled);
        root.setVisible(enabled);
    }

    function sendFile(deviceId: string, filePath: string): void {
        QuickShareService.sendFile(deviceId, filePath);
    }

    function acceptIncomingTransfer(): void {
        QuickShareService.acceptIncomingTransfer();
    }

    function rejectIncomingTransfer(): void {
        QuickShareService.rejectIncomingTransfer();
    }

    function clearHistory(): void {
        QuickShareService.clearHistory();
    }

    function removeHistoryEntry(index: int): void {
        QuickShareService.removeHistoryEntry(index);
    }

    function startBleWakeupBroadcast(): void {
        QuickShareService.startBleWakeupBroadcast();
    }

    function stopBleWakeupBroadcast(): void {
        QuickShareService.stopBleWakeupBroadcast();
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
        if (GlobalConfig.services.quickShareAutoStart) {
            root.setEnabled(true);
            root.setVisible(true);
        }
    }

    Connections {
        function onIncomingTransferRequested(deviceName: string, fileName: string, fileSize: real): void {
            root.clearPrompt();
            root.promptDeviceName = deviceName;
            root.promptFileName = fileName;
            root.promptFileSize = fileSize;
            root.prompt = Notifs.addShellNotification({
                summary: qsTr("Incoming file"),
                body: root.promptBody(),
                appName: qsTr("Quick Share"),
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

        function onTransferFinished(deviceId: string, success: bool): void {
            if (deviceId === "incoming")
                root.clearPrompt();
        }

        function onErrorOccurred(message: string): void {
            Toaster.toast(qsTr("Quick Share"), message, "error");
        }

        target: QuickShareService
    }
}
