pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.nexus.common

Popup {
    id: root

    property var entry: null
    property var rows: []

    signal saved(var children)

    function move(from, to): void {
        if (to < 0 || to >= root.rows.length)
            return;
        const next = root.rows.slice();
        next.splice(to, 0, next.splice(from, 1)[0]);
        root.rows = next;
    }

    width: 340
    padding: 24
    height: contentColumn.implicitHeight + 48
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: Overlay.overlay

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    enter: DialogTransition { }
    exit: DialogTransition {
        exiting: true
    }

    onOpened: root.rows = root.entry && root.entry.children ? JSON.parse(JSON.stringify(root.entry.children)) : []

    background: Item {
        Elevation {
            anchors.fill: bgRect
            level: 3
            radius: bgRect.radius
        }
        Rectangle {
            id: bgRect

            anchors.fill: parent
            color: Colours.palette.m3surfaceContainerHigh
            radius: Tokens.rounding.large
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
        }
    }

    contentItem: ColumnLayout {
        id: contentColumn

        spacing: Tokens.spacing.small

        Text {
            text: qsTr("Order the submenu")
            font: Tokens.font.body.large
            color: Colours.palette.m3onSurface
            Layout.fillWidth: true
        }

        Text {
            text: qsTr("Drag them nowhere: use the arrows to change the order they unfold in.")
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.padding.small
        }

        Repeater {
            model: root.rows

            delegate: StyledRect {
                id: rowRow

                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: 44
                radius: Tokens.rounding.medium
                color: Colours.palette.m3surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.extraSmall
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: rowRow.modelData.icon || "widgets"
                        color: Colours.palette.m3onSurface
                    }

                    Text {
                        Layout.fillWidth: true
                        text: rowRow.modelData.label || ""
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    TextButton {
                        text: "↑"
                        enabled: rowRow.index > 0
                        onClicked: root.move(rowRow.index, rowRow.index - 1)
                    }

                    TextButton {
                        text: "↓"
                        enabled: rowRow.index < root.rows.length - 1
                        onClicked: root.move(rowRow.index, rowRow.index + 1)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.padding.small

            TextButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }

            Item { Layout.fillWidth: true }

            TextButton {
                text: qsTr("Save")
                onClicked: {
                    root.saved(root.rows);
                    root.close();
                }
            }
        }
    }
}
