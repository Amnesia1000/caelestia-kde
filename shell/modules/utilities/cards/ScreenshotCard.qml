pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

StyledRect {
    id: root

    required property var props
    required property DrawerVisibilities visibilities
    readonly property real nonAnimHeight: btnLayout.implicitHeight + shotsList.implicitHeight + layout.spacing + layout.anchors.margins * 2

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            id: btnLayout

            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Tokens.padding.small * 2

                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Centering.pixelAlign(parent.height, height)
                    text: "photo_camera"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Screenshot")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Capture, OCR and image search")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                    animate: true
                }
            }

            SplitButton {
                active: captureItem

                menuItems: [
                    MenuItem {
                        id: captureItem

                        icon: "screenshot_region"
                        text: qsTr("Capture region")
                        activeText: qsTr("Capture")
                        onClicked: {
                            root.visibilities.utilities = false;
                            if (!Visibilities.sidebarPinned)
                                root.visibilities.sidebar = false;
                            Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "region", "screenshot"]);
                        }
                    },
                    MenuItem {
                        icon: "fullscreen"
                        text: qsTr("Capture fullscreen")
                        activeText: qsTr("Fullscreen")
                        onClicked: {
                            root.visibilities.utilities = false;
                            if (!Visibilities.sidebarPinned)
                                root.visibilities.sidebar = false;
                            const pad = n => String(n).padStart(2, "0");
                            const now = new Date();
                            const file = `${GlobalConfig.paths.screenshotsDir}/screenshot-${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}.${pad(now.getMinutes())}.${pad(now.getSeconds())}.png`;
                            Quickshell.execDetached(["spectacle", "-b", "-f", "-o", file]);
                        }
                    },
                    MenuItem {
                        icon: "select_window"
                        text: qsTr("Capture active window")
                        activeText: qsTr("Window")
                        onClicked: {
                            root.visibilities.utilities = false;
                            if (!Visibilities.sidebarPinned)
                                root.visibilities.sidebar = false;
                            const pad2 = n => String(n).padStart(2, "0");
                            const now2 = new Date();
                            const file2 = `${GlobalConfig.paths.screenshotsDir}/screenshot-${now2.getFullYear()}-${pad2(now2.getMonth() + 1)}-${pad2(now2.getDate())}_${pad2(now2.getHours())}.${pad2(now2.getMinutes())}.${pad2(now2.getSeconds())}.png`;
                            Quickshell.execDetached(["spectacle", "-b", "-a", "-o", file2]);
                        }
                    },
                    MenuItem {
                        icon: "text_fields"
                        text: qsTr("Recognize text")
                        activeText: qsTr("Recognize")
                        onClicked: {
                            root.visibilities.utilities = false;
                            if (!Visibilities.sidebarPinned)
                                root.visibilities.sidebar = false;
                            Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "region", "ocr"]);
                        }
                    },
                    MenuItem {
                        icon: "image_search"
                        text: qsTr("Search image")
                        activeText: qsTr("Search")
                        onClicked: {
                            root.visibilities.utilities = false;
                            if (!Visibilities.sidebarPinned)
                                root.visibilities.sidebar = false;
                            Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "region", "search"]);
                        }
                    },
                    MenuItem {
                        icon: "screenshot_monitor"
                        text: qsTr("Use Spectacle")
                        activeText: qsTr("Spectacle")
                        onClicked: {
                            root.visibilities.utilities = false;
                            if (!Visibilities.sidebarPinned)
                                root.visibilities.sidebar = false;
                            Quickshell.execDetached(["spectacle"]);
                        }
                    }
                ]
            }
        }

        ScreenshotList {
            id: shotsList

            props: root.props
            visibilities: root.visibilities
        }
    }
}
