pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

// Toolbar for the desktop widget edit mode. It carries the way out and the two
// actions that would otherwise need a right-click on a widget, and it says which
// mode the desktop is in, since the cards themselves look almost unchanged.
Variants {
    model: Screens.screens

    StyledWindow {
        id: win

        required property ShellScreen modelData
        readonly property var controller: DesktopLayout.controllerFor(win.modelData.name)
        readonly property int barZone: Visibilities.bars.get(win.modelData.name)?.visualThickness ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
        readonly property int topMargin: Config.bar.position === "top" ? Tokens.spacing.large + barZone : Tokens.spacing.large
        readonly property bool shouldShow: DesktopLayout.widgetEditMode && win.controller !== null

        screen: modelData
        Tokens.screen: modelData.name
        Config.screen: modelData.name
        name: "widget-edit-overlay"
        WlrLayershell.namespace: "overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        visible: win.shouldShow || pill.opacity > 0.01
        color: "transparent"

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        mask: win.shouldShow ? pillRegion : emptyRegion

        Region {
            id: pillRegion

            x: pill.x
            y: pill.y
            width: pill.width
            height: pill.height
        }

        Region {
            id: emptyRegion

            width: 0
            height: 0
        }

        StyledRect {
            id: pill

            y: win.shouldShow ? win.topMargin : (win.topMargin - 16)
            opacity: win.shouldShow ? 1 : 0
            scale: win.shouldShow ? 1 : 0.9

            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: row.implicitWidth + Tokens.padding.extraLarge * 2
            implicitHeight: row.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainerHigh
            border.width: Math.max(1, Config.border.thickness)
            border.color: Colours.palette.m3outlineVariant

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                opacity: parent.opacity
                z: -1
                level: 3
            }

            RowLayout {
                id: row

                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "widgets"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.title.small
                }

                StyledText {
                    text: qsTr("Editing widgets")
                    font: Tokens.font.label.large
                    color: Colours.palette.m3onSurface
                }

                StyledRect {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Tokens.padding.large
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: Tokens.spacing.small
                    Layout.rightMargin: Tokens.spacing.small
                    color: Qt.alpha(Colours.palette.m3outline, 0.4)
                }

                IconTextButton {
                    type: IconTextButton.Text
                    icon: "add"
                    text: qsTr("Add widget")
                    onClicked: DesktopLayout.addWidgetRequested(win.modelData.name, win.width / 2, win.height / 3)
                }

                IconTextButton {
                    type: IconTextButton.Text
                    icon: DesktopLayout.anyWidgetUnlocked() ? "lock_open" : "lock"
                    text: DesktopLayout.anyWidgetUnlocked() ? qsTr("Lock all") : qsTr("Unlock all")
                    onClicked: DesktopLayout.setAllWidgetsLocked(DesktopLayout.anyWidgetUnlocked())
                }

                TextButton {
                    type: TextButton.Filled
                    text: qsTr("Done")
                    onClicked: DesktopLayout.setWidgetEditMode(false)
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Behavior on y {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }
    }
}
