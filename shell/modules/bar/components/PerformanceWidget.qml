pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "performance"
import Caelestia.Config
import qs.components
import qs.services

// System stats entry: shows the stat pills picked in Nexus, the full data
// lives in the popout. Falls back to a single icon when no pill is picked.
StyledRect {
    id: root

    required property var popouts

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property var pills: (Config.bar.performance?.pills ?? []).map(p => String(p).trim().toLowerCase()).filter(p => p.length > 0)

    implicitWidth: isHorizontal ? Math.max(Tokens.sizes.bar.innerWidth, layout.implicitWidth) : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : Math.max(Tokens.sizes.bar.innerWidth, layout.implicitHeight)

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, 0)
    radius: Tokens.rounding.full

    visible: enabled

    GridLayout {
        id: layout

        anchors.centerIn: parent
        columns: root.isHorizontal ? -1 : 1
        flow: root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: Tokens.spacing.medium
        rowSpacing: Tokens.spacing.medium

        Repeater {
            model: root.pills

            delegate: DelegateChoice {
                roleValue: "cpu"
                delegate: PerfCpu {}
            }
            delegate: DelegateChoice {
                roleValue: "gpu"
                delegate: PerfGpu {}
            }
            delegate: DelegateChoice {
                roleValue: "memory"
                delegate: PerfMemory {}
            }
            delegate: DelegateChoice {
                roleValue: "storage"
                delegate: PerfStorage {}
            }
            delegate: DelegateChoice {
                roleValue: "network"
                delegate: PerfNetwork {}
            }
            delegate: DelegateChoice {
                roleValue: "battery"
                delegate: PerfBattery {}
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: "speed"
        color: Colours.palette.m3onSurface
        fontStyle: Tokens.font.icon.builders.medium.build()

        visible: root.pills.length === 0
    }

    MouseArea {
        id: contextArea

        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            root.popouts.currentName = "performancecontext";
            root.popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : (root.mapToItem(null, 0, root.implicitHeight / 2).y ?? 0);
            root.popouts.hasCurrent = true;
            mouse.accepted = true;
        }
    }
}
