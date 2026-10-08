pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property var popouts

    implicitWidth: 32
    implicitHeight: 32

    MaterialIcon {
        anchors.centerIn: parent
        text: "sticky_note_2"
        fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
        color: Colours.palette.m3primary
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            if (root.popouts.currentName === "notes") {
                root.popouts.currentName = "";
                root.popouts.hasCurrent = false;
            } else {
                root.popouts.currentName = "notes";
                root.popouts.currentCenter = root.mapToItem(null, root.implicitWidth / 2, 0).x;
                root.popouts.hasCurrent = true;
            }
        }
    }
}
