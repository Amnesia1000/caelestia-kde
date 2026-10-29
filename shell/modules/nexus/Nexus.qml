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

    readonly property NexusState nState: NexusState {
        id: nState

        currentPageIdx: root.initialPageIdx
        Component.onCompleted: {
            if (root.initialSubPageIdx !== -1 && root.initialSubPageIdx !== undefined && root.initialSubPageIdx !== "")
                openSubPage(root.initialSubPageIdx);
        }

        onClose: root.requestClose()
        onCurrentPageIdxChanged: {
            if (root.navigatingFromSearch)
                return;
            root.activePane = 0;
            pages.clearSelection();
        }
    }
    property color blobColour: Colours.tPalette.m3surfaceContainerLow
    property int activePane: 0
    property bool navigatingFromSearch: false
    readonly property bool hasActiveInputField: root.isInputField(Window.window ? Window.window.activeFocusItem : null)

    signal close

    function requestClose(): void {
        root.close();
    }

    function isInputField(item: var): bool {
        let cur = item;
        while (cur) {
            if (cur.cursorPosition !== undefined || cur.inputMethodHints !== undefined || cur.capturedKey !== undefined)
                return true;
            cur = cur.parent ?? null;
        }
        return false;
    }

    function focusSearchBar(): void {
        root.activePane = 0;
        pages.clearSelection();
        navPane.focusSearchBar();
    }

    function clearSearchFocus(): void {
        navPane.clearSearchFocus();
        root.forceActiveFocus();
    }

    function moveUp(): void {
        if (root.activePane === 1)
            pages.moveUp();
        else
            navPane.moveUp();
    }

    function moveDown(): void {
        if (root.activePane === 1)
            pages.moveDown();
        else
            navPane.moveDown();
    }

    function activateSelected(): void {
        if (root.activePane === 1) {
            pages.activateSelected();
        } else {
            navPane.activateSelected();
            root.activePane = 1;
        }
    }

    function goLeft(): void {
        if (root.activePane === 1 && pages.stepLeft())
            return;
        if (root.nState.subPageIdxStack.length > 0) {
            WindowFactory.goBack();
        } else if (root.activePane === 1) {
            root.activePane = 0;
            pages.clearSelection();
        }
    }

    function goRight(): void {
        if (root.activePane === 1) {
            if (!pages.stepRight())
                pages.activateSelected();
        } else {
            navPane.activateSelected();
            root.activePane = 1;
        }
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
        if (event.x <= navPane.x + navPane.width)
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

    implicitWidth: implicitHeight * Tokens.sizes.nexus.ratio
    implicitHeight: nState.screen.height * Tokens.sizes.nexus.heightMult

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

        borderLeft: navPane.width + navPane.anchors.margins * 2
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
        width: Math.min(Tokens.sizes.nexus.maxNavWidth, Math.round(root.width / 3))

        onSearchResultSelected: (entry) => {
            root.navigatingFromSearch = true;
            root.activePane = 1;
            navPane.clearSelection();
            pages.selectEntry(entry);
            root.navigatingFromSearch = false;
        }
    }

    Pages {
        id: pages

        anchors.left: navPane.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: navPane.anchors.margins + anchors.margins
        anchors.margins: Tokens.padding.extraLarge

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

    TapHandler {
        id: outsideTapHandler

        enabled: navPane.isSearchActive

        onPressedChanged: {
            if (pressed && !navPane.isInsideSearchRegion(root, point.position.x, point.position.y))
                root.clearSearchFocus();
        }

        onTapped: (eventPoint, button) => {
            if (!navPane.isInsideSearchRegion(root, eventPoint.position.x, eventPoint.position.y))
                root.clearSearchFocus();
        }
    }

    Shortcut {
        sequence: "/"
        enabled: root.windowActive && !root.hasActiveInputField
        autoRepeat: false

        onActivated: root.focusSearchBar()
    }

    Shortcut {
        sequences: ["Up", "k"]
        enabled: root.windowActive && !root.hasActiveInputField
        autoRepeat: true

        onActivated: root.moveUp()
    }

    Shortcut {
        sequences: ["Down", "j"]
        enabled: root.windowActive && !root.hasActiveInputField
        autoRepeat: true

        onActivated: root.moveDown()
    }

    TapHandler {
        parent: navPane

        onTapped: {
            root.activePane = 0;
            pages.clearSelection();
        }
    }

    TapHandler {
        parent: pages

        onTapped: {
            root.activePane = 1;
            navPane.clearSelection();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.windowActive && !root.hasActiveInputField
        autoRepeat: false

        onActivated: {
            if (pages.handleEscape())
                return;
            if (root.nState.subPageIdxStack.length > 0) {
                WindowFactory.goBack();
            } else if (root.activePane === 1) {
                root.activePane = 0;
                pages.clearSelection();
            } else {
                root.requestClose();
            }
        }
    }

    Shortcut {
        sequence: "Backspace"
        enabled: root.windowActive && !root.hasActiveInputField && (root.nState.subPageIdxStack.length > 0 || root.activePane === 1)
        autoRepeat: false

        onActivated: {
            if (pages.handleEscape())
                return;
            if (root.nState.subPageIdxStack.length > 0) {
                WindowFactory.goBack();
            } else if (root.activePane === 1) {
                root.activePane = 0;
                pages.clearSelection();
            }
        }
    }

    Shortcut {
        sequence: "Delete"
        enabled: root.windowActive && !root.hasActiveInputField && root.activePane === 1
        autoRepeat: false

        onActivated: {
            if (pages.handleDelete())
                return;
        }
    }

    Shortcut {
        sequences: ["Left", "h"]
        enabled: root.windowActive && !root.hasActiveInputField
        autoRepeat: true

        onActivated: root.goLeft()
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: root.windowActive && !root.hasActiveInputField
        autoRepeat: false

        onActivated: root.activateSelected()
    }

    Shortcut {
        sequences: ["Right", "l"]
        enabled: root.windowActive && !root.hasActiveInputField
        autoRepeat: true

        onActivated: root.goRight()
    }
}
