pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services.QuickShare
import qs.services

Singleton {
    id: root

    property NotifData prompt: null
    readonly property bool promptLive: root.prompt !== null && Notifs.list.includes(root.prompt) && !root.prompt.closed
    property string promptDeviceName: ""
    property string promptFileName: ""
    property real promptFileSize: 0
    property string promptPin: ""
    property bool pendingIncoming: false

    readonly property bool enabled: QuickShareService.isEnabled || root.pendingEnable
    property bool pendingEnable: false
    /// second enable neither repeats the prompt nor the warning.
    property bool raised: false

    function setEnabled(on: bool): void {
        root.pendingEnable = on;

        if (!on) {
            QuickShareService.isEnabled = false;
            return;
        }

        if (QuickShareSetup.state === QuickShareSetup.State.Unknown)
            QuickShareSetup.check();
        else
            root.finishEnable();
    }

    function finishEnable(): void {
        if (!root.pendingEnable)
            return;

        root.pendingEnable = false;
        QuickShareService.isEnabled = true;
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
    }

    Connections {
        // through, needs a privileged run first, or has to be let through with a warning;
        function onReported(): void {
            if (!root.pendingEnable)
                return;

            if (!root.raised) {
                if (QuickShareSetup.needsSetup) {
                    root.raised = true;
                    Toaster.toast(qsTr("Quick Share"),
                        qsTr("Quick Share needs administrator rights to start Avahi and open the transfer port."), "info");
                    QuickShareSetup.run();
                    return;
                }

                if (QuickShareSetup.state === QuickShareSetup.State.Unverified) {
                    root.raised = true;
                    Toaster.toast(qsTr("Quick Share"),
                        QuickShareSetup.message !== "" ? QuickShareSetup.message
                            : qsTr("Quick Share could not confirm the transfer port is reachable. Allow port %1 in Settings -> Services -> Quick Share.").arg(QuickShareService.listenPort),
                        "warning");
                }
            }

            root.finishEnable();
        }

        target: QuickShareSetup
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

        function onIncomingTransferPinReady(pinCode: string): void {
            root.promptPin = pinCode;
            if (root.promptLive)
                root.prompt.body = root.promptBody();
        }

        function onIncomingTransferFinished(success: bool): void {
            root.pendingIncoming = false;
            root.clearPrompt();
        }

        function onErrorOccurred(message: string): void {
            Toaster.toast(qsTr("Quick Share"), message, "error");
        }

        target: QuickShareService
    }
}
