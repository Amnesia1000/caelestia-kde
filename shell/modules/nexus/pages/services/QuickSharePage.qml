import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services.QuickShare
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Quick Share")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Status")
        }

        ToggleRow {
            first: true
            text: qsTr("Enable Quick Share")
            subtext: QuickShareService.isEnabled ? qsTr("Listening for nearby devices") : qsTr("Disabled")
            checked: QuickShareService.isEnabled
            onToggled: {
                QuickShareService.isEnabled = checked;
                QuickShareService.isVisible = checked;
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Discoverable")
            subtext: qsTr("Advertise this machine so nearby devices can send to it")
            enabled: QuickShareService.isEnabled
            checked: QuickShareService.isVisible
            onToggled: QuickShareService.isVisible = checked
        }

        SectionHeader {
            text: qsTr("Startup")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Start automatically")
            subtext: qsTr("Turn Quick Share on when the shell starts")
            checked: Config.services.quickShareAutoStart
            onToggled: GlobalConfig.services.quickShareAutoStart = checked
        }

        SectionHeader {
            text: qsTr("Transfers")
        }

        InfoRow {
            first: true
            icon: "download"
            label: qsTr("Received files")
            subtext: qsTr("Saved to your Downloads folder")
        }

        RowButton {
            last: true
            icon: "delete_sweep"
            text: qsTr("Clear transfer history")
            subtext: qsTr("%n transfer(s) recorded", "", QuickShareService.transferHistory.length)
            trailingIcon: "chevron_right"
            onClicked: QuickShareService.clearHistory()
        }
    }
}
