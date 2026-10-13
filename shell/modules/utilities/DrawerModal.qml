pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    required property bool open
    required property matrix4x4 deformMatrix
    default property alias content: cardLayout.data

    signal dismissed()

    anchors.fill: parent

    DrawerScrim {
        deformMatrix: root.deformMatrix
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.dismissed()
    }

    StyledRect {
        anchors.centerIn: parent
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainerHigh

        scale: 0
        Component.onCompleted: scale = Qt.binding(() => root.open ? 1 : 0)

        width: Math.min(parent.width - Tokens.padding.extraLargeIncreased, implicitWidth)
        implicitWidth: cardLayout.implicitWidth + Tokens.padding.extraExtraLarge
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.extraExtraLarge

        MouseArea {
            anchors.fill: parent
        }

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
        }

        ColumnLayout {
            id: cardLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large * 1.5
            spacing: Tokens.spacing.medium
        }

        Behavior on scale {
            Anim {}
        }
    }
}
