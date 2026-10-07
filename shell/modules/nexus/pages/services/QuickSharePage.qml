import QtQuick
import QtQuick.Layouts
import Caelestia.Config
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
            subtext: QuickShare.isEnabled ? qsTr("Listening for nearby devices") : qsTr("Disabled")
            checked: QuickShare.isEnabled
            onToggled: {
                QuickShare.setEnabled(checked);
                QuickShare.setVisible(checked);
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Discoverable")
            subtext: qsTr("Advertise this machine so nearby devices can send to it")
            enabled: QuickShare.isEnabled
            checked: QuickShare.isVisible
            onToggled: QuickShare.setVisible(checked)
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
            subtext: qsTr("%n transfer(s) recorded", "", QuickShare.transferHistory.length)
            trailingIcon: "chevron_right"
            onClicked: QuickShare.clearHistory()
        }
    }
}
