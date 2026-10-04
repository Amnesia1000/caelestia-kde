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
    required property var overlayExtents
    // A pinned sidebar reserves its width so maximised windows sit beside it
    // rather than under it. It stays reserved while hidden for a fullscreen window
    // so the other windows are not resized back and forth.
    readonly property bool reserveSidebar: Visibilities.sidebarPinned && Config.sidebar.enabled
        && (visibilities.sidebar || visibilities.sidebarSuspended)

    ExclusionZone {
        anchors.left: true
        exclusiveZone: (root.bar.position === "left" ? root.bar.exclusiveZone + root.overlayExtents.left : Math.max(Config.border.thickness, root.overlayExtents.left))
            + (root.reserveSidebar && root.bar.position === "right" ? Tokens.sizes.sidebar.width : 0)
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.top: true
        exclusiveZone: root.bar.position === "top" ? root.bar.exclusiveZone + root.overlayExtents.top : Math.max(Config.border.thickness, root.overlayExtents.top)
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.right: true
        exclusiveZone: (root.bar.position === "right" ? root.bar.exclusiveZone + root.overlayExtents.right : Math.max(Config.border.thickness, root.overlayExtents.right))
            + (root.reserveSidebar && root.bar.position !== "right" ? Tokens.sizes.sidebar.width : 0)
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.bottom: true
        exclusiveZone: root.bar.position === "bottom" ? root.bar.exclusiveZone + root.overlayExtents.bottom : Math.max(Config.border.thickness, root.overlayExtents.bottom)
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
