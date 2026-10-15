pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import "../../utilities/cards"
import qs.services
import qs.utils

// Shortcuts popout: system shortcuts, quick apps, and quick toggles.
ColumnLayout {
    id: root

    required property var popouts
    required property DrawerVisibilities visibilities

    width: Math.max(360, togglesView.implicitWidth)
    spacing: Tokens.spacing.medium

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Tokens.spacing.medium
        visible: Config.bar.shortcuts.showSystem

        Repeater {
            model: [
                { name: qsTr("Nexus"), action: "nexus", icon: "dashboard" },
                { name: qsTr("Launcher"), action: "launcher", icon: "apps" },
                { name: qsTr("Overview"), action: "overview", icon: "view_array" },
                { name: qsTr("Dashboard"), action: "dashboard", icon: "dashboard" },
                { name: qsTr("Screenshot"), action: "screenshot", icon: "screenshot_region" },
                { name: qsTr("Record"), action: "screenRecording", icon: "screen_record" },
            ]

            delegate: IconButton {
                required property var modelData

                type: IconButton.Tonal
                isRound: true
                icon: modelData.icon
                onClicked: {
                    Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "drawers", "toggle", modelData.action]);
                }
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Tokens.spacing.medium
        visible: Config.bar.shortcuts.showApps

        Repeater {
            model: [
                { name: qsTr("Terminal"), cmd: GlobalConfig.general.apps.terminal, icon: "terminal" },
                { name: qsTr("Browser"), cmd: ["firefox"], icon: "web" },
                { name: qsTr("Editor"), cmd: ["code"], icon: "code" },
                { name: qsTr("Files"), cmd: ["nemo"], icon: "folder" },
            ]

            delegate: IconButton {
                required property var modelData

                type: IconButton.Tonal
                isRound: true
                icon: modelData.icon
                onClicked: Launch.exec(modelData.cmd);
            }
        }
    }

    Toggles {
        id: togglesView

        Layout.fillWidth: true
        visibilities: root.visibilities
        popouts: root.popouts
    }
}
