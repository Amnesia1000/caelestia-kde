pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    property bool first: false
    property alias text: heading.text
    property alias actionText: actionLabel.text
    property bool actionVisible: true

    signal actionClicked

    Layout.fillWidth: true
    Layout.topMargin: root.first ? 0 : Math.max(0, Tokens.spacing.large - (parent && parent.spacing !== undefined ? parent.spacing : 0))
    Layout.bottomMargin: -(parent && parent.spacing !== undefined ? Math.max(0, parent.spacing - 4) : 0)
    Layout.leftMargin: Tokens.padding.small
    Layout.rightMargin: Tokens.padding.small
    spacing: Tokens.spacing.small

    StyledText {
        id: heading

        Layout.fillWidth: true
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
        elide: Text.ElideRight
    }

    Item {
        visible: root.actionVisible && actionLabel.text.length > 0
        implicitWidth: actionLabel.implicitWidth + Tokens.padding.small * 2
        implicitHeight: actionLabel.implicitHeight + Tokens.padding.extraSmall
        opacity: actionMouse.pressed ? 0.6 : actionMouse.containsMouse ? 0.85 : 1

        StyledText {
            id: actionLabel

            anchors.centerIn: parent
            color: Colours.palette.m3primary
            font: Tokens.font.label.medium
        }

        Rectangle {
            anchors.left: actionLabel.left
            anchors.right: actionLabel.right
            anchors.top: actionLabel.bottom
            height: 1
            color: actionLabel.color
            visible: actionMouse.containsMouse
        }

        MouseArea {
            id: actionMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionClicked()
        }

        Behavior on opacity {
            Anim {}
        }
    }
}
