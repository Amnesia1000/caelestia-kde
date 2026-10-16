pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar
    required property DrawerVisibilities visibilities
    // Frame thickness each full-edge panel takes on its side (the panel edges of
    // the content window). It is reserved even while the panels are collapsed,
    // so opening the overview does not resize the maximised windows.
    required property var panelEdges
    // A pinned sidebar reserves its width so maximised windows sit beside it
    // rather than under it. It stays reserved while hidden for a fullscreen window
    // so the other windows are not resized back and forth.
    readonly property bool reserveSidebar: Visibilities.sidebarPinned && Config.sidebar.enabled
        && (visibilities.sidebar || visibilities.sidebarSuspended)
    // Follows the sidebar width, but only once a resize drag ends: reserving every
    // step of the drag would resize maximised windows on each frame. The default
    // comes from the bar, which has the screen's tokens.
    property real sidebarWidth

    // The space the full-edge panels take on the given side, besides the plain
    // border the frame always keeps.
    function panelReservation(side: string): real {
        return root.panelEdges ? (root.panelEdges[side] ?? 0) : 0;
    }

    Binding on sidebarWidth {
        value: Visibilities.sidebarWidthFor(root.bar.Tokens.sizes.sidebar.width)
        when: !Visibilities.sidebarResizing
        restoreMode: Binding.RestoreNone
    }

    ExclusionZone {
        anchors.left: true
        exclusiveZone: Math.max(root.bar.position === "left" ? root.bar.exclusiveZone : Config.border.thickness, root.panelReservation("left"))
            + (root.reserveSidebar && root.bar.position === "right" ? root.sidebarWidth : 0)
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.top: true
        exclusiveZone: Math.max(root.bar.position === "top" ? root.bar.exclusiveZone : Config.border.thickness, root.panelReservation("top"))
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.right: true
        exclusiveZone: Math.max(root.bar.position === "right" ? root.bar.exclusiveZone : Config.border.thickness, root.panelReservation("right"))
            + (root.reserveSidebar && root.bar.position !== "right" ? root.sidebarWidth : 0)
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.bottom: true
        exclusiveZone: Math.max(root.bar.position === "bottom" ? root.bar.exclusiveZone : Config.border.thickness, root.panelReservation("bottom"))
        Config.screen: root.screen.name
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
        Config.screen: root.screen.name
    }
}
