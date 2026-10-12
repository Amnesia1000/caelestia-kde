pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import "../../utilities/cards"
import qs.services

// Shortcuts popout: the utilities card, reused as is.
ColumnLayout {
    id: root

    required property var popouts
    required property DrawerVisibilities visibilities

    width: Math.max(360, togglesView.implicitWidth)
    spacing: Tokens.spacing.small

    Toggles {
        id: togglesView

        Layout.fillWidth: true
        visibilities: root.visibilities
        popouts: root.popouts
    }
}
