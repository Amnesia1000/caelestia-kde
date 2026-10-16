pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.popouts

Item {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property var bar
    required property real borderThickness
    required property DrawerVisibilities visibilities

    readonly property alias content: content
    readonly property bool isHorizontal: bar.isHorizontal
    // A popout grows along the axis of the edge it comes out of, which is not
    // always the bar's own axis: a panel can put a vertical edge on a screen
    // whose bar is horizontal.
    readonly property bool verticalEdge: root.edge === "left" || root.edge === "right"
    // The frame edge the popout grows out of: the bar's own side by default,
    // or the side of the panel band that opened it.
    readonly property string edge: content.currentEdge
    property real offsetScale: content.isDetached || content.hasCurrent ? 0 : 1
    // Where x is heading; x itself animates towards it.
    readonly property real targetX: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;
        if (!root.verticalEdge) {
            if (content.sidebarOpen && !content.isDockPopout)
                return parent.width - content.nonAnimWidth;

            // An item left of the open sidebar gets its popout kept clear of it, so
            // the sidebar doesn't have to be pushed out of the way.
            const right = root.visibilities.sidebar && !content.underSidebar ? parent.width - Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width) - Tokens.spacing.extraLarge : parent.width;
            const off = content.currentCenter - parent.leftMargin - content.nonAnimWidth / 2;
            const diff = right - Math.floor(off + content.nonAnimWidth);
            if (diff < 0)
                return Math.max(off + diff, 0);
            return Math.max(off, 0);
        }
        if (root.edge === "right")
            return parent.width - implicitWidth - content.currentInset;
        return content.currentInset;
    }

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: root.verticalEdge ? content.implicitWidth * (1 - offsetScale) : content.implicitWidth
    implicitHeight: root.verticalEdge ? content.implicitHeight : content.implicitHeight * (1 - offsetScale)

    x: targetX
    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;
        if (!root.verticalEdge) {
            if (root.edge === "bottom")
                return parent.height - implicitHeight - content.currentInset;
            return content.currentInset;
        }

        const off = content.currentCenter - parent.topMargin - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        enabled: content.isDetached || !root.verticalEdge

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: content.isDetached || (root.verticalEdge && root.offsetScale < 1)

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale
        visibilities: root.visibilities
        underSidebar: !root.isHorizontal || content.currentCenter - root.parent.leftMargin >= root.parent.width - Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width)

        anchors.leftMargin: root.edge === "left" ? (-implicitWidth - 5) * root.offsetScale : 0
        anchors.rightMargin: root.edge === "right" ? (-implicitWidth - 5) * root.offsetScale : 0
        anchors.topMargin: root.edge === "top" ? (-implicitHeight - 5) * root.offsetScale : 0
        anchors.bottomMargin: root.edge === "bottom" ? (-implicitHeight - 5) * root.offsetScale : 0

        states: [
            State {
                name: "left"
                when: root.edge === "left"

                AnchorChanges {
                    target: content
                    anchors.left: parent.left
                    anchors.right: undefined
                    anchors.top: undefined
                    anchors.bottom: undefined
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: undefined
                }
            },
            State {
                name: "right"
                when: root.edge === "right"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: parent.right
                    anchors.top: undefined
                    anchors.bottom: undefined
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: undefined
                }
            },
            State {
                name: "top"
                when: root.edge === "top"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: undefined
                    anchors.top: parent.top
                    anchors.bottom: undefined
                    anchors.verticalCenter: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            },
            State {
                name: "bottom"
                when: root.edge === "bottom"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: undefined
                    anchors.top: undefined
                    anchors.bottom: parent.bottom
                    anchors.verticalCenter: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        ]
    }
}
