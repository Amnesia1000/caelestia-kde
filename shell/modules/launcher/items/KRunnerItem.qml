pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var modelData
    required property var list

    readonly property real iconSize: (Tokens.sizes.launcher.itemHeight - Tokens.padding.small * 2) * 0.8

    function activate(): void {
        if (!root.modelData)
            return;
        root.list.visibilities.launcher = false;
        Search.run(root.modelData.id, "");
    }

    implicitHeight: Tokens.sizes.launcher.itemHeight
    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.activate()
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.margins: Tokens.padding.small

        IconImage {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            implicitSize: root.iconSize
            source: Quickshell.iconPath(root.modelData?.icon ?? "")
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: parent.right
            anchors.verticalCenter: icon.verticalCenter

            implicitHeight: text.implicitHeight + subtext.implicitHeight

            StyledText {
                id: text

                width: parent.width
                text: root.modelData?.text ?? ""
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                id: subtext

                anchors.top: text.bottom
                width: parent.width
                text: (root.modelData?.subtext ?? "").replace(/\s+/g, " ").trim()
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }
}
