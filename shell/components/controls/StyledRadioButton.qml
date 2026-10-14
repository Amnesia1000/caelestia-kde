import QtQuick
import QtQuick.Templates
import Caelestia.Config
import qs.components
import qs.services

RadioButton {
    id: root

    font: Tokens.font.body.small

    implicitWidth: implicitIndicatorWidth + implicitContentWidth + contentItem.anchors.leftMargin
    implicitHeight: Math.max(implicitIndicatorHeight, implicitContentHeight)

    indicator: Rectangle {
        id: outerCircle

        implicitWidth: 20
        implicitHeight: 20
        radius: Tokens.rounding.full
        color: "transparent"
        border.color: !root.enabled ? Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.38) : root.checked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        border.width: 2
        anchors.verticalCenter: parent.verticalCenter

        StateLayer {
            anchors.margins: -Tokens.padding.small
            color: root.checked ? Colours.palette.m3onSurface : Colours.palette.m3primary
            disabled: !root.enabled
            z: -1
            onClicked: root.click()
        }

        StyledRect {
            anchors.centerIn: parent
            implicitWidth: 8
            implicitHeight: 8

            radius: Tokens.rounding.full
            color: Qt.alpha(Colours.palette.m3primary, root.checked ? (root.enabled ? 1 : 0.38) : 0)
        }

        Behavior on border.color {
            CAnim {}
        }
    }

    contentItem: StyledText {
        text: root.text
        font: root.font
        color: root.enabled ? Colours.palette.m3onSurface : Qt.alpha(Colours.palette.m3onSurface, 0.38)
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: outerCircle.right
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacing.medium
        elide: Text.ElideRight
    }
}
