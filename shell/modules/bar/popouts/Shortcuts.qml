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

// Shortcuts popout: quick apps (following the configured default
// applications) and quick toggles.
ColumnLayout {
    id: root

    required property var popouts
    required property DrawerVisibilities visibilities

    width: Math.max(360, togglesView.implicitWidth)
    spacing: Tokens.spacing.medium

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Tokens.spacing.medium

        Repeater {
            model: [
                { name: qsTr("Terminal"), cmd: GlobalConfig.general.apps.terminal, icon: "terminal" },
                { name: qsTr("Browser"), cmd: GlobalConfig.general.apps.browser, icon: "web" },
                { name: qsTr("Editor"), cmd: GlobalConfig.general.apps.editor, icon: "code" },
                { name: qsTr("Files"), cmd: [...GlobalConfig.general.apps.explorer, Quickshell.env("HOME")], icon: "folder" },
            ]

            delegate: IconButton {
                required property var modelData

                type: IconButton.Tonal
                isRound: true
                icon: modelData.icon
                onClicked: Launch.exec(modelData.cmd)
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
