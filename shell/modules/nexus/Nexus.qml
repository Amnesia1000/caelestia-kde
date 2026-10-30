pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.nexus

Item {
    id: root

    property int initialPageIdx: 0
    property var initialSubPageIdx: -1
    readonly property bool windowActive: Window.window ? Window.window.active : false
    readonly property bool compact: root.width < 1120

    readonly property NexusState nState: NexusState {
        id: nState

        compact: root.compact
        currentPageIdx: root.initialPageIdx
        Component.onCompleted: {
            if (root.initialSubPageIdx !== -1 && root.initialSubPageIdx !== undefined && root.initialSubPageIdx !== "")
                openSubPage(root.initialSubPageIdx);
        }

        onClose: root.requestClose()
    }
    property color blobColour: Colours.tPalette.m3surfaceContainerLow

    signal close

    function requestClose(): void {
        root.close();
    }

    function currentFlickable(): var {
        let item = pages.currentItem;
        while (item) {
            if (item.flickable !== undefined)
                return item.flickable;
            item = item.currentItem ?? null;
        }
        return null;
    }

    function scrollCurrentPage(event: var): bool {
        if (event.x <= subcategoryPane.x + subcategoryPane.width)
            return false;

        const f = root.currentFlickable();
        if (!f || !f.interactive)
            return false;

        // The page already handles the wheel when the cursor is over it.
        const pos = f.mapFromItem(root, event.x, event.y);
        if (pos.x >= 0 && pos.y >= 0 && pos.x <= f.width && pos.y <= f.height)
            return false;

        const maxY = Math.max(0, f.contentHeight - f.height);
        if (maxY <= 0)
            return false;

        f.contentY = Math.max(0, Math.min(maxY, f.contentY - event.angleDelta.y));
        return true;
    }

    readonly property var targetScreen: nState.screen ?? Window.window?.screen ?? Quickshell.screens[0]
    implicitHeight: (targetScreen ? targetScreen.height : 1080) * Tokens.sizes.nexus.heightMult
    implicitWidth: implicitHeight * Tokens.sizes.nexus.ratio

    Behavior on blobColour {
        CAnim {}
    }

    BlobGroup {
        id: blobGroup

        smoothing: root.Tokens.rounding.medium
        color: root.blobColour
    }

    BlobInvertedRect {
        anchors.fill: parent
        group: blobGroup
        opacity: root.blobColour.a
        radius: Tokens.rounding.large

        borderLeft: pages.x - Tokens.padding.small
        borderRight: Tokens.padding.medium
        borderTop: Tokens.padding.medium
        borderBottom: Tokens.padding.medium
    }

    NavPane {
        id: navPane

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: Tokens.padding.large

        nState: nState
        width: root.compact ? Math.min(340, Math.round(root.width * 0.45)) : Math.min(285, Math.round(root.width * 0.21))
        opacity: root.compact && root.nState.compactSubcategories ? 0 : 1
        enabled: opacity > 0.5

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    SubcategoryPane {
        id: subcategoryPane

        anchors.left: root.compact ? parent.left : navPane.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: Tokens.padding.large
        anchors.topMargin: navPane.anchors.margins
        anchors.bottomMargin: navPane.anchors.margins

        width: root.compact ? Math.min(340, Math.round(root.width * 0.45)) : Math.min(300, Math.round(root.width * 0.22))
        opacity: root.compact && !root.nState.compactSubcategories ? 0 : 1
        enabled: opacity > 0.5
        z: 1
        nState: nState

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Pages {
        id: pages

        anchors.left: subcategoryPane.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: Tokens.padding.large
        anchors.topMargin: navPane.anchors.margins
        anchors.bottomMargin: navPane.anchors.margins
        anchors.rightMargin: navPane.anchors.margins

        nState: nState
    }

    // The page margins around the content are outside the page flickable, so
    // the wheel did nothing there. Forward it to the current page.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (root.scrollCurrentPage(event))
                event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ExtraButton1
        preventStealing: true

        onPressed: mouse => {
            WindowFactory.goBack();
            mouse.accepted = true;
        }
    }
}
