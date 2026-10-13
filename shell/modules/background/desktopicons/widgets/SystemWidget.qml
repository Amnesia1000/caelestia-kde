pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property var frame
    property var controller

    readonly property int cols: frame?.span.w ?? 3
    readonly property bool tall: (frame?.span.h ?? 2) >= 3
    readonly property int tier: cols <= 2 ? 0 : cols === 3 ? 1 : 2
    readonly property bool hasGpu: Gpu.type !== Gpu.None && !isNaN(Gpu.percentage)

    function percent(value: real): string {
        return `${Math.round((isNaN(value) ? 0 : value) * 100)}%`;
    }

    function temp(celsius: real): string {
        return celsius > 0 ? Units.formatSensorTemp(celsius) : "";
    }

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Gpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Storage
    }

    ServiceRef {
        service: NetworkUsage
    }

    GridLayout {
        anchors.fill: parent
        visible: root.tier === 0
        columns: 2
        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small

        Ring {
            label: qsTr("CPU")
            value: Cpu.percentage
        }

        Ring {
            visible: root.hasGpu
            label: qsTr("GPU")
            value: Gpu.percentage
        }

        Ring {
            label: qsTr("Memory")
            value: Memory.percentage
        }

        Ring {
            label: qsTr("Disk")
            value: Storage.percentage
        }
    }

    RowLayout {
        anchors.fill: parent
        visible: root.tier > 0
        spacing: Tokens.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            Meter {
                icon: "memory"
                label: qsTr("CPU")
                value: Cpu.percentage
                extra: root.temp(Cpu.temperature)
                detail: Cpu.name.replace(/\s*(\d+-Core\s*)?Processor\s*$/i, "")
            }

            Meter {
                visible: root.hasGpu
                icon: "developer_board"
                label: qsTr("GPU")
                value: Gpu.percentage
                extra: root.temp(Gpu.temperature)
                detail: Gpu.name
            }

            Meter {
                readonly property string usage: Memory.total > 0 ? Units.formatKibUsage(Memory.used, Memory.total) : ""

                icon: "memory_alt"
                label: qsTr("Memory")
                value: Memory.percentage
                extra: root.tier === 2 && !root.tall ? usage : ""
                detail: usage
            }

            Meter {
                readonly property string usage: Storage.primaryDisk ? Units.formatKibUsage(Storage.primaryDisk.used, Storage.primaryDisk.total) : ""

                icon: "hard_disk"
                label: qsTr("Disk")
                value: Storage.percentage
                extra: root.tier === 2 && !root.tall ? usage : ""
                detail: usage
            }

            Speeds {
                Layout.fillWidth: true
                visible: root.tier === 1 && root.tall
            }
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: root.width * 0.4
            Layout.maximumWidth: root.width * 0.4
            visible: root.tier === 2
            spacing: Tokens.spacing.small

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                SparklineItem {
                    id: sparkline

                    property real targetMax: 1024
                    property real smoothMax: targetMax

                    anchors.fill: parent
                    visible: parent.height > 40
                    line1: NetworkUsage.uploadBuffer
                    line1Color: Colours.palette.m3tertiary
                    line1FillAlpha: 0.15
                    line2: NetworkUsage.downloadBuffer
                    line2Color: Colours.palette.m3secondary
                    line2FillAlpha: 0.2
                    maxValue: smoothMax
                    historyLength: NetworkUsage.historyLength

                    Connections {
                        function onValuesChanged(): void {
                            sparkline.targetMax = Math.max(NetworkUsage.downloadBuffer.maximum, NetworkUsage.uploadBuffer.maximum, 1024);
                            slideAnim.restart();
                        }

                        target: NetworkUsage.downloadBuffer
                    }

                    NumberAnimation {
                        id: slideAnim

                        target: sparkline
                        property: "slideProgress"
                        from: 0
                        to: 1
                        easing.type: Easing.Linear
                        duration: GlobalConfig.dashboard.resourceUpdateInterval
                    }

                    Behavior on smoothMax {
                        Anim {}
                    }
                }
            }

            Speeds {
                Layout.fillWidth: true
                stacked: true
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.tall
                elide: Text.ElideRight
                text: `↓${Units.formatBytes(NetworkUsage.downloadTotal ?? 0)} ↑${Units.formatBytes(NetworkUsage.uploadTotal ?? 0)}`
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }

    component Ring: ColumnLayout {
        id: ring

        required property string label
        required property real value

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            CircularProgress {
                id: progress

                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                value: ring.value
                strokeWidth: Math.max(3, Math.round(width / 14))
                fgColour: ring.value > 0.85 ? Colours.palette.m3error : Colours.palette.m3primary
                bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.15)

                Behavior on clampedVal {
                    Anim {}
                }

                StyledText {
                    anchors.centerIn: parent
                    text: root.percent(ring.value)
                    font: progress.width > 56 ? Tokens.font.label.large : Tokens.font.label.small
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: ring.label
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }

    component Meter: RowLayout {
        id: meter

        required property string icon
        required property string label
        required property real value
        property string extra
        property string detail

        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: meter.icon
            color: Colours.palette.m3primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.minimumWidth: implicitWidth
                    text: meter.label
                    font: Tokens.font.label.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: meter.extra.length > 0 ? `${meter.extra} · ${root.percent(meter.value)}` : root.percent(meter.value)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: meter.detail.length > 0 && root.tall
                elide: Text.ElideRight
                text: meter.detail
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Qt.alpha(Colours.palette.m3onSurface, 0.15)

                StyledRect {
                    width: parent.width * Math.max(0, Math.min(1, isNaN(meter.value) ? 0 : meter.value))
                    height: parent.height
                    radius: parent.radius
                    color: meter.value > 0.85 ? Colours.palette.m3error : Colours.palette.m3primary

                    Behavior on width {
                        Anim {}
                    }
                }
            }
        }
    }

    component Speeds: GridLayout {
        property bool stacked: false

        columns: stacked ? 2 : 4
        rowSpacing: 2
        columnSpacing: Tokens.spacing.medium

        MaterialIcon {
            text: "download"
            color: Colours.palette.m3secondary
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Units.formatBytes(NetworkUsage.downloadSpeed ?? 0, true)
            font: Tokens.font.label.medium
        }

        MaterialIcon {
            text: "upload"
            color: Colours.palette.m3tertiary
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Units.formatBytes(NetworkUsage.uploadSpeed ?? 0, true)
            font: Tokens.font.label.medium
        }
    }
}
