pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.components.filedialog
import qs.services

Loader {
    id: root

    required property var props
    required property matrix4x4 deformMatrix

    function closeSelector(): void {
        root.props.quickShareDeviceSelectorOpen = false;
    }

    asynchronous: true
    anchors.fill: parent

    opacity: root.props.quickShareDeviceSelectorOpen ? 1 : 0
    active: opacity > 0

    onActiveChanged: {
        if (active)
            QuickShare.startBleWakeupBroadcast();
        else
            QuickShare.stopBleWakeupBroadcast();
    }

    sourceComponent: MouseArea {
        id: selector

        hoverEnabled: true
        onClicked: root.closeSelector()

        DrawerScrim {
            deformMatrix: root.deformMatrix
        }

        StyledRect {
            anchors.centerIn: parent
            radius: Tokens.rounding.extraLarge
            color: Colours.palette.m3surfaceContainerHigh

            scale: 0
            Component.onCompleted: scale = Qt.binding(() => root.props.quickShareDeviceSelectorOpen ? 1 : 0)

            width: Math.min(parent.width - Tokens.padding.extraLargeIncreased, implicitWidth)
            implicitWidth: selectorLayout.implicitWidth + Tokens.padding.extraExtraLarge
            implicitHeight: selectorLayout.implicitHeight + Tokens.padding.extraExtraLarge

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
                id: selectorLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large * 1.5
                spacing: Tokens.spacing.medium

                StyledText {
                    text: qsTr("Send a file")
                    font: Tokens.font.body.large
                }

                StyledText {
                    Layout.fillWidth: true
                    text: QuickShare.nearbyDevices.length === 0 ? qsTr("Looking for nearby devices that have Quick Share open.") : qsTr("Choose a nearby device to send the file to.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    animate: true
                }

                StyledListView {
                    id: deviceList

                    Layout.fillWidth: true
                    implicitWidth: 300
                    implicitHeight: count > 0 ? Math.min(count * 48, 200) : 0
                    visible: count > 0
                    clip: true

                    model: QuickShare.nearbyDevices

                    delegate: WrapperMouseArea {
                        required property var modelData

                        width: deviceList.width
                        height: 48

                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            fileDialog.targetDeviceId = modelData.id;
                            fileDialog.open();
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                Layout.alignment: Qt.AlignVCenter
                                text: "smartphone"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.large
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.topMargin: Tokens.spacing.medium
                    Layout.alignment: Qt.AlignRight
                    spacing: Tokens.spacing.medium

                    TextButton {
                        text: qsTr("Cancel")
                        type: TextButton.Text
                        onClicked: root.closeSelector()
                    }
                }
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    FileDialog {
        id: fileDialog

        property string targetDeviceId

        title: qsTr("Select a file to send")
        onAccepted: path => {
            if (fileDialog.targetDeviceId !== "")
                QuickShare.sendFile(fileDialog.targetDeviceId, path.toString().replace("file://", ""));
            root.closeSelector();
        }
        onRejected: root.closeSelector()
    }
}
