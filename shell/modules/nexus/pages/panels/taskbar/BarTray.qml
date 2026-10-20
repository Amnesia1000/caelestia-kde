pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    function stateLabel(state: string): string {
        switch (state) {
        case "visible":
            return qsTr("Always visible");
        case "hidden":
            return qsTr("Hidden");
        default:
            return qsTr("Collapse");
        }
    }

    function stateIcon(state: string): string {
        switch (state) {
        case "visible":
            return "push_pin";
        case "hidden":
            return "visibility_off";
        default:
            return "expand_more";
        }
    }

    title: qsTr("Tray")
    isSubPage: true
    scrollLocked: orderList.dragging

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: qsTr("Background")
            reset: ({ node: GlobalConfig.bar.tray, setting: "background" })
            checked: Config.bar.tray.background
            onToggled: GlobalConfig.bar.tray.background = checked
        }

        ToggleRow {
            text: qsTr("Recolor icons")
            reset: ({ node: GlobalConfig.bar.tray, setting: "recolour" })
            checked: Config.bar.tray.recolour
            onToggled: GlobalConfig.bar.tray.recolour = checked
        }

        ToggleRow {
            text: qsTr("Compact")
            reset: ({ node: GlobalConfig.bar.tray, setting: "compact" })
            checked: Config.bar.tray.compact
            onToggled: GlobalConfig.bar.tray.compact = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Popout on hover")
            subtext: qsTr("Show the tray menu popout when hovering")
            reset: ({ node: GlobalConfig.bar.popouts, setting: "tray" })
            checked: Config.bar.popouts.tray
            onToggled: GlobalConfig.bar.popouts.tray = checked
        }

        SectionHeader {
            text: qsTr("Icons")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !Config.bar.tray.compact
            text: qsTr("Collapsing is off, so every icon already stays on the bar. These choices apply once Compact is on.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        TrayOrderList {
            id: orderList

            entries: TrayRegistry.entries
            onMoved: keys => TrayRegistry.setOrder(keys)

            delegate: Item {
                id: slot

                required property int index
                required property string trayId
                required property string trayKey
                required property string title
                required property string trayIcon
                required property bool running

                width: orderList.width
                height: row.implicitHeight
                z: orderList.dragIndex === slot.index ? 1 : 0
                transform: Translate {
                    y: orderList.dragIndex === slot.index ? orderList.dragTop - slot.y : 0
                }

                SelectRow {
                    id: row

                    anchors.fill: parent
                    highlight: orderList.dragIndex === slot.index
                    first: slot.index === 0
                    last: slot.index === orderList.count - 1
                    label: slot.title
                    subtext: slot.running ? slot.trayId : qsTr("%1 (not running)").arg(slot.trayId)
                    icon: Icons.getTrayIcon(slot.trayKey, slot.trayIcon, slot.trayId)
                    active: menuItems.find(item => item.value === TrayRegistry.stateOf(slot.trayKey)) ?? null
                    fallbackText: root.stateLabel(TrayRegistry.stateOf(slot.trayKey))
                    fallbackIcon: root.stateIcon(TrayRegistry.stateOf(slot.trayKey))
                    menuOnTop: slot.index === orderList.count - 1
                    onSelected: item => {
                        if (item.value === "forget")
                            TrayRegistry.forget(slot.trayKey);
                        else
                            TrayRegistry.setState(slot.trayKey, item.value);
                    }

                    menuItems: [
                        MenuItem {
                            text: root.stateLabel("visible")
                            icon: root.stateIcon("visible")
                            value: "visible"
                        },
                        MenuItem {
                            text: root.stateLabel("collapsed")
                            icon: root.stateIcon("collapsed")
                            value: "collapsed"
                        },
                        MenuItem {
                            text: root.stateLabel("hidden")
                            icon: root.stateIcon("hidden")
                            value: "hidden"
                        },
                        MenuItem {
                            visible: !slot.running
                            text: qsTr("Forget")
                            icon: "delete"
                            value: "forget"
                        }
                    ]
                }

                Item {
                    id: grip

                    width: gripIcon.implicitWidth + Tokens.padding.small
                    height: slot.height
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.small / 4

                    MaterialIcon {
                        id: gripIcon

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "drag_indicator"
                        fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: Qt.OpenHandCursor
                        onPressed: mouse => orderList.press(slot.trayKey, grip.mapToItem(null, mouse.x, mouse.y).y)
                        onPositionChanged: mouse => {
                            if (pressed)
                                orderList.drag(grip.mapToItem(null, mouse.x, mouse.y).y);
                        }
                        onReleased: orderList.release()
                        onCanceled: orderList.release()
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: orderList.count === 0
            text: qsTr("No tray icons have been seen yet.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: orderList.count > 1
            text: qsTr("Drag a row to change the order")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}