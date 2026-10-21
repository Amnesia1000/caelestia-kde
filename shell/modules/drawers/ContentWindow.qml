pragma ComponentBehavior: Bound

import "blur"
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import qs.modules.background
import qs.modules.bar
import qs.modules.overview as Overview
import qs.modules.background.desktopicons

StyledWindow {
    id: root

    property real blurOffsetTop: 0
    property real blurOffsetBottom: 0
    property real blurOffsetLeft: 0
    property real blurOffsetRight: 0
    property alias overviewAnimConfig: animConfig
    readonly property alias bar: bar
    readonly property alias interactionWrapper: interactions
    readonly property alias visibilities: visibilities
    // The per-screen state object the drawers share. The dashboard's tab and the
    // month its calendar is showing live in it, which is where upstream keeps
    // them, so both survive the dashboard closing and a shell reload.
    readonly property ScreenState screenState: ShellState.forScreen(screen)
    readonly property var monitor: Kwin.monitorFor(screen)
    // Reference Kwin.activeWsId so QML re-evaluates this binding whenever the
    // active workspace changes — hasFullscreenOn() filters by workspace, but
    // a plain function call only re-runs when its direct property deps change.
    readonly property bool actualFullscreen: (Kwin.activeWsId, Kwin.hasFullscreenOn(screen?.name ?? ""))
    readonly property bool transientOverlayOpen: panels.popouts.isDetached || panels.popouts.isContextPopout || desktopContextMenu.expanded || desktopIconContextMenu.expanded || dropMenu.expanded || viewOptions.open || widgetGallery.open || visibilities.overview || Visibilities.launcherOpen || visibilities.dashboard || visibilities.session || visibilities.utilities
    readonly property bool hasOpenOverlay: focusGrabState.active || transientOverlayOpen || visibilities.sidebar
    readonly property bool hasFullscreen: actualFullscreen && !hasOpenOverlay
    // The launcher is one panel across outputs: a screen that does not show it
    // still takes input, so that a press there dismisses it.
    readonly property bool foreignLauncherOpen: Visibilities.launcherOpen && !visibilities.launcher
    // A context menu on another screen still needs this layer to take the dismiss
    // click; it must not lift the fullscreen suppression above, which is per screen.
    readonly property bool capturesOverlayInput: hasOpenOverlay || Visibilities.contextPopoutOpen

    // The sidebar is the only thing open and it is pinned (or one of the shell's
    // file dialogs is up): take input only over the panels, not the whole screen,
    // so clicks outside reach other windows instead of closing the sidebar.
    readonly property bool sidebarPassthrough: visibilities.sidebar && (Visibilities.sidebarPinned || Visibilities.openDialogs > 0)
        && !(transientOverlayOpen || (panels.popouts.currentName.startsWith("traymenu") && (panels.popouts.current as StackView)?.depth > 1))
    property real fsTransitionProg: hasFullscreen ? 1 : 0
    readonly property real sdfBorderOffset: 2 * fsTransitionProg
    readonly property real overviewBorderThickness: Math.min(root.width, root.height) * 0.15
    property real dynamicBorderThickness: visibilities.overview ? overviewBorderThickness : Config.border.thickness
    property real overviewVerticalOffset: {
        if (!visibilities.overview) return 0;
        const grid = panels && panels.overview ? panels.overview.windowGrid : null;
        return grid ? grid.verticalOffset : 0;
    }
    readonly property real borderThickness: dynamicBorderThickness * (1 - fsTransitionProg)
    // Secondary panels: a full-edge panel thickens the frame on its edge and
    // hosts its own widget band there (see panelLayer below). The thickness is
    // the bar's own, so a panel and the bar stay visually identical.
    readonly property int panelThickness: bar.contentWidth
    // The thickness each full-edge panel takes on its edge right now: a panel
    // that slides away gives its thickness back, so the frame mask, its blur
    // corners and the drawers' insets all follow it while it moves.
    readonly property var panelEdges: {
        const panelEdge = edge => panelLayer.thicknessOn(edge);
        return {
            left: panelEdge("left"),
            right: panelEdge("right"),
            top: panelEdge("top"),
            bottom: panelEdge("bottom")
        };
    }
    // What the exclusion zones reserve on each side: a panel that stays on
    // screen keeps its space whether it spans the whole edge or only part of
    // it, so maximised windows stop at the panel instead of sliding under it.
    // A panel that slid away takes no space, and one that was pulled open takes
    // its space back while it is out.
    readonly property var panelReservations: {
        const panelEdge = edge => panelLayer.takesSpaceOn(edge) ? root.panelThickness : 0;
        return {
            left: panelEdge("left"),
            right: panelEdge("right"),
            top: panelEdge("top"),
            bottom: panelEdge("bottom")
        };
    }
    // Single source of truth for the frame's thickness per screen side: on the
    // side the bar sits on, the frame is as thick as the bar itself, everywhere
    // else it is the plain border or the panel that thickens it. The frame
    // mask, its blur corners and the panel insets all derive from this, so the
    // numbers cannot drift apart.
    readonly property var frameEdges: {
        // While the overview is up or a window is fullscreen the bar and the
        // panels collapse, so they take no thickness from the frame.
        const collapsed = visibilities.overview || root.hasFullscreen;
        const panelEdge = edge => collapsed ? 0 : root.panelEdges[edge];
        return {
            left: Math.max(bar.position === "left" ? bar.implicitWidth : 0, root.borderThickness, panelEdge("left")),
            right: Math.max(bar.position === "right" ? bar.implicitWidth : 0, root.borderThickness, panelEdge("right")),
            top: Math.max(bar.position === "top" ? bar.implicitHeight : 0, root.borderThickness, panelEdge("top")),
            bottom: Math.max(bar.position === "bottom" ? bar.implicitHeight : 0, root.borderThickness, panelEdge("bottom"))
        };
    }
    // Every panel enabled on this screen, with the index it holds in the global
    // list: the ones spanning a whole edge thicken the frame there, the rest are
    // drawn as islands over it. The index is what lets a panel open the page
    // that edits its own widgets.
    readonly property var screenPanels: {
        const panels = GlobalConfig.bar.panels?.values ?? [];
        const shown = [];
        for (let i = 0; i < panels.length; ++i) {
            const panel = panels[i];
            if (panel.enabled === false)
                continue;
            if ((panel.screens ?? []).length > 0 && !Strings.testRegexList(panel.screens, screen.name))
                continue;
            shown.push({
                panel,
                index: i
            });
        }
        return shown;
    }
    // Islands already keep the bar away from the screen edge, so a panel does
    // the same there; without them a panel hugs the edge and merges with it.
    readonly property int panelInset: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
    // Where each panel sits, in window coordinates. A partial panel takes the
    // bar's thickness but only part of its edge, placed by `align`, and never
    // reserves space: the exclusion zones only know about full-edge panels.
    readonly property var panelRects: {
        const rects = [];
        for (const entry of root.screenPanels) {
            const panel = entry.panel;
            const edge = panel.position ?? "top";
            const horizontal = edge === "top" || edge === "bottom";
            const total = horizontal ? root.width : root.height;
            const usable = Math.max(0, total - root.panelInset * 2);
            const percent = Math.max(0, Math.min(100, panel.lengthPercent ?? 100));
            const full = percent >= 100;
            const length = full ? usable : Math.round(usable * percent / 100);
            if (length <= 0) continue;
            const align = panel.align ?? "center";
            const along = full || align === "center" ? Math.round((total - length) / 2) : (align === "end" ? total - root.panelInset - length : root.panelInset);
            const thickness = root.panelThickness;
            rects.push({
                panel,
                panelIndex: entry.index,
                edge,
                horizontal,
                full,
                x: horizontal ? along : edge === "left" ? root.panelInset : root.width - root.panelInset - thickness,
                y: horizontal ? (edge === "top" ? root.panelInset : root.height - root.panelInset - thickness) : along,
                width: horizontal ? length : thickness,
                height: horizontal ? thickness : length
            });
        }
        return rects;
    }
    // The bands themselves, handed out as they are: they are what slides, and
    // reading their animated geometry keeps the repeater that draws the islands
    // following them in and out instead of snapping. With the islands off only
    // the partial panels get one, the full-edge ones are part of the frame.
    readonly property var panelBands: panelLayer.bands(!GlobalConfig.appearance.islands)
    // The plain, snapped rectangles the compositor reads: the background blur
    // and the input mask. They sit where a band rests - its rect while it is
    // out, the border strip at its edge while it is away - and change once per
    // transition. Feeding those regions the animated geometry instead would
    // have the compositor resample them every frame, which shows up as a
    // shimmer over the whole drawer window while a panel slides.
    readonly property var partialPanelStrips: panelLayer.strips(true)
    readonly property bool panelsVisible: root.panelRects.length > 0 && !visibilities.overview && !root.hasFullscreen
    readonly property real borderRounding: Config.border.rounding * (1 - fsTransitionProg)
    readonly property real shadowOpacity: 0.7 * (1 - fsTransitionProg)
    readonly property real borderLayoutThickness: hasFullscreen ? 0 : dynamicBorderThickness
    property color surfaceColour: Colours.tPalette.m3surface
    readonly property int dragMaskPadding: {
        if (focusGrabState.active || panels.popouts.isDetached)
            return 0;
        if (!monitor || monitor.lastIpcObject?.specialWorkspace?.name || monitor.activeWorkspace?.lastIpcObject === undefined || monitor.activeWorkspace.lastIpcObject.windows > 0)
            return 0;
        const thresholds = [];
        for (const panel of ["dashboard", "launcher", "session", "sidebar"])
            if (Config[panel].enabled)
                thresholds.push(Config[panel].dragThreshold);
        return Math.max(...thresholds);
    }

    readonly property bool wantsKeyboard: visibilities.launcher || visibilities.session || visibilities.dashboard || visibilities.sidebar || visibilities.overview || (panels.popouts.hasCurrent && !panels.popouts.isDockPopout)

    property string focusReturn: ""
    property int workspaceReturn: -1

    onHasFullscreenChanged: {
        if (!hasFullscreen)
            return;
        visibilities.launcher = false;
        visibilities.session = false;
        visibilities.dashboard = false;
        panels.popouts.close();
    }

    name: "drawers"

    WlrLayershell.namespace: "dock"
    mask: {
        if (capturesOverlayInput && !sidebarPassthrough) return fullRegion;
        if (hasFullscreen) return emptyRegion;
        return regions;
    }
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: !wantsKeyboard && (capturesOverlayInput || (actualFullscreen && fsTransitionProg < 1) || (fsTransitionProg > 0 && Config.general.showOverFullscreen) || (panels.notifications.visible && panels.notifications.height > 0 && GlobalConfig.notifs.fullscreen === "on") || (((monitor?.lastIpcObject?.specialWorkspace?.name?.length ?? 0) > 0) && (monitor?.activeWorkspace?.toplevels?.values?.some(t => (t?.lastIpcObject?.fullscreen ?? 0) > 1) ?? false))) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // A pinned sidebar gets out of the way of fullscreen windows (games, video)
    // and comes back once fullscreen ends.
    onActualFullscreenChanged: {
        if (actualFullscreen) {
            if (visibilities.sidebar && Visibilities.sidebarPinned) {
                visibilities.sidebarSuspended = true;
                visibilities.sidebar = false;
            }
        } else if (visibilities.sidebarSuspended) {
            visibilities.sidebarSuspended = false;
            if (Visibilities.sidebarPinned)
                visibilities.sidebar = true;
        }
    }
    onWantsKeyboardChanged: {
        if (wantsKeyboard) {
            focusReturn = Kwin.activeWindow?.address ?? "";
            workspaceReturn = Kwin.activeWsId;
            return;
        }

        const pending = Kwin.pendingFocusAddress ?? "";
        const addr = (Kwin.activeWindow?.address ?? "") || focusReturn;
        const oldWorkspace = workspaceReturn;
        focusReturn = "";
        workspaceReturn = -1;

        if (pending) {
            return;
        }

        const currentWorkspace = Kwin.activeWsId;
        if (oldWorkspace !== -1 && currentWorkspace !== oldWorkspace) {
            return;
        }

        if (addr)
            Kwin.focusWindow(addr);
    }

    Overview.Anim {
        id: animConfig
    }
    Settings {
        id: borderBlurSettings

        property int blurQuality: 20

        category: "Blur"
    }
    Behavior on dynamicBorderThickness { NumberAnimation { duration: animConfig.blobDuration; easing.type: animConfig.easingType } }
    Behavior on overviewVerticalOffset { NumberAnimation { duration: animConfig.blobDuration; easing.type: animConfig.easingType } }
    Behavior on fsTransitionProg {
        Anim {}
    }
    Behavior on surfaceColour {
        CAnim {}
    }
    Region {
        id: emptyRegion

        x: panels.notifications.x + panels.leftMargin
        y: panels.notifications.y + panels.topMargin
        width: panels.notifications.width
        height: panels.notifications.height

        Region {
            x: root.width - width
            y: panels.osdWrapper.y + panels.topMargin
            width: panels.osdWrapper.width * (1 - panels.osd.offsetScale) + panels.topMargin
            height: panels.osd.height
        }
    }
    Regions {
        id: regions

        bar: bar
        panels: panels
        frameEdges: root.frameEdges
        win: root
        partialPanelStrips: root.partialPanelStrips
    }
    Region {
        id: fullRegion

        x: 0
        y: 0
        width: root.width
        height: root.height
    }
    QtObject {
        id: focusGrabState

        property bool active: (visibilities.launcher && Config.launcher.enabled) || (visibilities.session && Config.session.enabled) || (visibilities.sidebar && Config.sidebar.enabled) || (!Config.dashboard.showOnHover && visibilities.dashboard && Config.dashboard.enabled) || (!Config.utilities.showOnHover && visibilities.utilities && Config.utilities.enabled) || (panels.popouts.currentName.startsWith("traymenu") && (panels.popouts.current as StackView)?.depth > 1)

        function clear() {
            visibilities.launcher = false;
            visibilities.session = false;
            if (!Visibilities.sidebarPinned)
                visibilities.sidebar = false;
            visibilities.dashboard = false;
            visibilities.utilities = false;
            Visibilities.setOverview(false);
            Visibilities.closeContextPopouts();
            panels.popouts.close();
            bar.closeTray();
        }

        onActiveChanged: {
        }
    }
    StyledRect {
        property bool _wasActive: false

        anchors.fill: parent
        opacity: (visibilities.session && Config.session.enabled) || panels.popouts.detachedMode !== "" ? 0.5 : 0
        color: Colours.palette.m3scrim

        Timer {
            id: kdeFocusGrab

            interval: 100
            repeat: true
            running: focusGrabState.active || panels.popouts.isDetached
            onRunningChanged: {
                if (!running) {
                    parent._wasActive = false;
                }
            }
            onTriggered: {
                // Focus moved to one of the shell's own file dialogs: keep the
                // drawers open, and wait for the shell to be focused again before
                // treating focus loss as a reason to close them.
                if (Visibilities.openDialogs > 0) {
                    parent._wasActive = false;
                    return;
                }

                let anyActive = root.active || root.activeFocusItem !== null;

                if (anyActive) {
                    parent._wasActive = true;
                } else if (parent._wasActive && !anyActive) {
                    parent._wasActive = false;
                    focusGrabState.clear();
                    if (panels.popouts.isDetached) panels.popouts.close();
                }
            }
        }
        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }
    Item {
        id: overviewWallpaperLayer

        property bool active: visibilities.overview || warming
        property bool keepAlive: false
        property bool warming: false
        property real _maxBorder: Math.max(1, Math.min(root.width, root.height) * 0.15)
        property real bgScale: 1.0 + (dynamicBorderThickness / _maxBorder) * 0.1

        onActiveChanged: {
            if (active)
                keepAlive = true;
        }

        anchors.fill: parent
        visible: active || opacity > 0
        layer.enabled: true
        opacity: warming ? 0.004 : ((visibilities.overview && wallpaperLoader.status === Loader.Ready) ? 1 : 0)

        Behavior on opacity { NumberAnimation { duration: overviewWallpaperLayer.warming ? 0 : animConfig.wallpaperDuration; easing.type: animConfig.easingType } }
        Timer {
            running: true
            interval: 2500
            onTriggered: { overviewWallpaperLayer.warming = true; warmDone.start(); }
        }
        Timer {
            id: warmDone

            interval: 400
            onTriggered: overviewWallpaperLayer.warming = false
        }
        Item {
            id: scaledWallpaperContainer

            anchors.fill: parent

            Loader {
                id: wallpaperLoader

                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                scale: overviewWallpaperLayer.bgScale
                active: overviewWallpaperLayer.active || overviewWallpaperLayer.opacity > 0
                        || (overviewWallpaperLayer.keepAlive && wallpaperLoader.item && !wallpaperLoader.item.isVideo(wallpaperLoader.item.source))
                sourceComponent: Component {
                    Wallpaper {
                        screen: root.screen
                        skipTransition: true
                        source: {
                            const cur = Wallpapers.current;
                            if (Images.isVideo(cur)) {
                                const hifi = Wallpapers.thumbHifi(cur);
                                return hifi !== "" ? hifi : Wallpapers.getThumbnailHifiPath(cur);
                            }
                            return cur;
                        }
                    }
                }
            }
        }
        Item {
            id: maskContainer

            anchors.fill: parent

            BlobGroup {
                id: overviewBlurMask

                color: "white"
            }
            BlobInvertedRect {
                anchors.fill: parent
                anchors.margins: -50
                group: overviewBlurMask
                radius: root.borderRounding
                borderLeft: root.frameEdges.left - anchors.margins - root.sdfBorderOffset
                borderRight: root.frameEdges.right - anchors.margins - root.sdfBorderOffset
                borderTop: root.frameEdges.top - root.overviewVerticalOffset - anchors.margins - root.sdfBorderOffset
                borderBottom: root.frameEdges.bottom + root.overviewVerticalOffset - anchors.margins - root.sdfBorderOffset
                Config.screen: root.screen.name
            }
        }
        ShaderEffectSource {
            id: overviewWallpaperSource

            sourceItem: scaledWallpaperContainer
            anchors.fill: parent
            hideSource: false
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: overviewWallpaperSource
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: ShaderEffectSource {
                sourceItem: maskContainer
                hideSource: true
            }
            blurEnabled: GlobalConfig.appearance.blur && GlobalConfig.overview.enableOverviewBlur
            blurMax: 64
            blur: 1.0
        }
    }
    Item {
        id: layoutContainer

        anchors.fill: parent
        opacity: GlobalConfig.appearance.pitchBlack ? 1 : (Colours.transparency.enabled ? Colours.transparency.base : 1.0)
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, root.shadowOpacity))
        }

        BlobGroup {
            id: blobGroup

            color: GlobalConfig.appearance.pitchBlack ? "#000000" : root.surfaceColour
            smoothing: Config.border.smoothing
        }
        BlobInvertedRect {
            anchors.fill: parent
            anchors.margins: -50
            group: GlobalConfig.appearance.islands ? null : blobGroup
            visible: !GlobalConfig.appearance.islands
            radius: root.borderRounding
            borderLeft: root.frameEdges.left - anchors.margins - root.sdfBorderOffset
            borderRight: root.frameEdges.right - anchors.margins - root.sdfBorderOffset
            borderTop: root.frameEdges.top - root.overviewVerticalOffset - anchors.margins - root.sdfBorderOffset
            borderBottom: root.frameEdges.bottom + root.overviewVerticalOffset - anchors.margins - root.sdfBorderOffset
            Config.screen: root.screen.name
        }
        BlobRect {
            visible: GlobalConfig.appearance.islands
            group: GlobalConfig.appearance.islands ? blobGroup : null
            x: bar.x
            y: bar.y
            implicitWidth: bar.width
            implicitHeight: bar.height
            radius: Tokens.rounding.extraLarge
            deformScale: (GlobalConfig.appearance.blurMask || !GlobalConfig.appearance.transparency.enabled) ? ((0.1 * Config.appearance.deformScale) / 10000) : 0
        }
        Repeater {
            model: root.panelBands

            delegate: BlobRect {
                required property var modelData

                group: root.panelsVisible && !modelData.islandAway ? blobGroup : null
                visible: root.panelsVisible && !modelData.islandAway
                x: modelData.x
                y: modelData.y
                implicitWidth: modelData.width
                implicitHeight: modelData.height
                radius: Tokens.rounding.extraLarge
                deformScale: (GlobalConfig.appearance.blurMask || !GlobalConfig.appearance.transparency.enabled) ? ((0.1 * Config.appearance.deformScale) / 10000) : 0
                Config.screen: root.screen.name
            }
        }
        PanelBg {
            id: dashBg

            panel: panels.dashboard
            deformAmount: 0.1
        }
        PanelBg {
            id: launcherBg

            panel: panels.launcher
            deformAmount: 0.1
        }
        PanelBg {
            id: sessionBg

            panel: panels.sessionWrapper
            deformAmount: 0.2
            x: panels.sessionWrapper.x + panels.leftMargin
            implicitWidth: panels.sessionWrapper.width
        }
        PanelBg {
            id: sidebarBg

            property bool connectedToPopout: (bar.position === "top" || bar.position === "bottom") && panels.popouts.sidebarOpen && panels.popouts.implicitWidth <= Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width) + 1 && !panels.popouts.isDockPopout

            panel: panels.sidebar
            deformAmount: Visibilities.sidebarResizing ? 0 : 0.03
            implicitHeight: panel.height * (1 / rawDeformMatrix.m22) + 2
            exclude: {
                let arr = [];
                if (panels.sidebar.offsetScale <= 0.08) arr.push(utilsBg);
                if (connectedToPopout) arr.push(popoutBg);
                return arr;
            }
            topLeftRadius: GlobalConfig.appearance.islands ? radius : ((bar.position === "top" && connectedToPopout) ? 0 : (bar.position === "bottom" ? Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius : radius))
            topRightRadius: GlobalConfig.appearance.islands ? radius : ((bar.position === "top" && connectedToPopout) ? 0 : (bar.position === "bottom" ? Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius : radius))
            bottomLeftRadius: GlobalConfig.appearance.islands ? radius : ((bar.position === "bottom" && connectedToPopout) ? 0 : (bar.position === "right" ? radius : Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius))
            bottomRightRadius: GlobalConfig.appearance.islands ? radius : ((bar.position === "bottom" && connectedToPopout) ? 0 : (bar.position === "right" ? Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius : radius))
        }
        PanelBg {
            id: osdBg

            panel: panels.osdWrapper
            deformAmount: 0.25
            x: panels.osdWrapper.x + panels.leftMargin
            implicitWidth: panels.osdWrapper.width
        }
        PanelBg {
            id: notifsBg

            panel: panels.notifications
        }
        PanelBg {
            id: utilsBg

            panel: panels.utilities
            deformAmount: panels.sidebar.visible ? 0.1 : 0.15
            exclude: panels.sidebar.offsetScale > 0.08 ? [] : [sidebarBg]
            topLeftRadius: GlobalConfig.appearance.islands ? radius : (bar.position === "right" ? radius : (bar.position === "bottom" ? radius : Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius))
            topRightRadius: GlobalConfig.appearance.islands ? radius : (bar.position === "right" ? Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius : (bar.position === "bottom" ? radius : Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius))
            bottomLeftRadius: GlobalConfig.appearance.islands ? radius : (bar.position === "bottom" ? Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius : radius)
            bottomRightRadius: GlobalConfig.appearance.islands ? radius : (bar.position === "bottom" ? Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius : radius)
        }
        PanelBg {
            id: contextMenuBg

            panel: desktopContextMenu.backgroundItem
            // Stay up while the closing animation runs, not just while expanded.
            visible: desktopContextMenu.visible && panel.width > 0
            x: panel.x
            y: panel.y
        }
        PanelBg {
            id: popoutBg

            // The side the popout grows out of: the bar's side, or the side of
            // the panel band whose item opened it.
            readonly property string edge: panels.popoutsWrapper.edge
            property real extraShift: panels.popouts.isDetached ? 0 : 0.2
            property bool connectedToSidebar: (edge === "top" || edge === "bottom") && panels.popouts.sidebarOpen && panels.popouts.implicitWidth <= Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width) + 1 && !panels.popouts.isDockPopout

            panel: panels.popoutsWrapper
            deformAmount: connectedToSidebar ? 0.03 : (panels.popouts.isDetached ? 0.05 : panels.popouts.hasCurrent ? 0.15 : 0.1)
            exclude: connectedToSidebar ? [sidebarBg] : []
            x: {
                const baseX = panels.popoutsWrapper.x + panels.popouts.x + panels.leftMargin;
                if (edge === "left")
                    return baseX - panels.popouts.implicitWidth * extraShift;
                return baseX;
            }
            implicitWidth: {
                if (edge === "left" || edge === "right")
                    return panels.popouts.implicitWidth * (1 + extraShift);
                return panels.popouts.implicitWidth;
            }
            bottomLeftRadius: GlobalConfig.appearance.islands ? radius : ((edge === "top" && connectedToSidebar) ? 0 : radius)
            bottomRightRadius: GlobalConfig.appearance.islands ? radius : ((edge === "top" && connectedToSidebar) ? 0 : radius)
            topLeftRadius: GlobalConfig.appearance.islands ? radius : ((edge === "bottom" && connectedToSidebar) ? 0 : radius)
            topRightRadius: GlobalConfig.appearance.islands ? radius : ((edge === "bottom" && connectedToSidebar) ? 0 : radius)
            y: {
                const baseY = panels.popoutsWrapper.y + panels.popouts.y + panels.topMargin;
                if (edge === "top")
                    return baseY - panels.popouts.implicitHeight * extraShift;
                if (edge === "bottom" && connectedToSidebar)
                    return baseY - Tokens.spacing.extraLarge - 10;
                return baseY;
            }
            implicitHeight: {
                if (edge === "top" || edge === "bottom") {
                    let h = panels.popouts.implicitHeight * (1 + extraShift);
                    if (connectedToSidebar) h += Tokens.spacing.extraLarge + 10;
                    return h;
                }
                return panels.popouts.implicitHeight;
            }

            Behavior on extraShift {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }
    }
    DrawerVisibilities {
        id: visibilities

        onOverviewChanged: {
            if (overview && !GlobalConfig.overview.enabled) {
                overview = false;
            }
        }
        Component.onCompleted: Visibilities.load(root.screen, this)
        Component.onDestruction: Visibilities.unload(this)
    }
    Interactions {
        id: interactions

        screen: root.screen
        popouts: panels.popouts
        visibilities: visibilities
        dismissLauncher: root.foreignLauncherOpen
        panels: panels
        bar: bar
        barPanels: panelLayer
        borderThickness: root.borderLayoutThickness
        fullscreen: root.hasFullscreen
        capturesDismissClick: root.capturesOverlayInput
        focusGrab: focusGrabState
        states: [
            State {
                name: "left"
                when: bar.position === "left"

                AnchorChanges {
                    target: bar
                    anchors.left: parent.left
                    anchors.right: undefined
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: bar
                    width: bar.implicitWidth
                    height: undefined
                    anchors.topMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.bottomMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.leftMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.rightMargin: 0
                }
            },
            State {
                name: "right"
                when: bar.position === "right"

                AnchorChanges {
                    target: bar
                    anchors.left: undefined
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: bar
                    width: bar.implicitWidth
                    height: undefined
                    anchors.topMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.bottomMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.leftMargin: 0
                    anchors.rightMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                }
            },
            State {
                name: "top"
                when: bar.position === "top"

                AnchorChanges {
                    target: bar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: undefined
                }
                PropertyChanges {
                    target: bar
                    width: undefined
                    height: bar.implicitHeight
                    anchors.leftMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.rightMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.topMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.bottomMargin: 0
                }
            },
            State {
                name: "bottom"
                when: bar.position === "bottom"

                AnchorChanges {
                    target: bar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: undefined
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: bar
                    width: undefined
                    height: bar.implicitHeight
                    anchors.leftMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.rightMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.bottomMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
                    anchors.topMargin: 0
                }
            }
        ]

        MouseArea {
            anchors.fill: parent
            visible: visibilities.overview
            onClicked: Visibilities.setOverview(false)
        }
        // One widget band per panel, sitting where `panelRects` puts it: a
        // full-edge panel thickens the frame on its edge, a partial one rides
        // the island drawn over it. Each band draws the same Bar the primary
        // bar uses, so the widgets and the spacing stay identical all around
        // the frame. The bands live in the interactions (like the primary bar)
        // so their widgets receive the pointer, but before the drawers and
        // popouts so those still cover the frame when they open.
        Item {
            id: panelLayer

            // The band under the given point, so the pointer interactions can
            // be routed to it exactly like they are routed to the bar.
            function bandAt(x: real, y: real): var {
                for (let i = 0; i < panelRepeater.count; i++) {
                    const band = panelRepeater.itemAt(i);

                    if (band && band.contains(band.mapFromItem(null, x, y)))
                        return band;
                }

                return null;
            }
            // Clears the hover state of every band, mirroring bar.resetHover().
            function resetHover(): void {
                for (let i = 0; i < panelRepeater.count; i++) {
                    const band = panelRepeater.itemAt(i);

                    if (band)
                        band.resetHover();
                }
            }
            // The thickness a full-edge panel takes on the given side right now,
            // read off the band itself so it follows the slide animation.
            function thicknessOn(side: string): real {
                let thickness = 0;

                for (let i = 0; i < panelRepeater.count; i++) {
                    const band = panelRepeater.itemAt(i);

                    if (band && band.full && band.edge === side)
                        thickness = Math.max(thickness, band.thickness);
                }

                return thickness;
            }
            // Whether a panel on the given side keeps its space taken: one that
            // stays on screen does, one that went away does not.
            function takesSpaceOn(side: string): bool {
                for (let i = 0; i < panelRepeater.count; i++) {
                    const band = panelRepeater.itemAt(i);

                    if (band && band.edge === side && band.takesSpace)
                        return true;
                }

                return false;
            }
            // Where the bands sit right now, handed out as they are: they are
            // what moves, and reading their geometry keeps everything that
            // follows them - the repeater that draws the islands included -
            // following them instead of snapping. `partialOnly` leaves the
            // full-edge ones out, as with the islands off those are drawn as
            // part of the frame.
            function bands(partialOnly = false): var {
                const bands = [];

                for (let i = 0; i < panelRepeater.count; i++) {
                    const band = panelRepeater.itemAt(i);

                    if (band && (!partialOnly || !band.full))
                        bands.push(band);
                }

                return bands;
            }
            // The plain, snapped rectangles the compositor reads: the blur
            // region and the input mask. They sit where a band rests - its rect
            // while it is out, the border strip at its edge while it is away -
            // and change once per transition. Reading the animated geometry
            // here instead would have the compositor resample those regions
            // every frame, which shimmers over the whole drawer window.
            function strips(partialOnly = false): var {
                const strips = [];

                for (let i = 0; i < panelRepeater.count; i++) {
                    const band = panelRepeater.itemAt(i);

                    if (band && (!partialOnly || !band.full))
                        strips.push(band.place);
                }

                return strips;
            }
            // Reveals and hides the bands whose panel does not stay on screen: a
            // panel that follows the pointer comes out while the pointer is on
            // the strip it keeps at its edge, and one that does not has to be
            // dragged open from that same strip, exactly like the bar.
            function updateReveal(x: real, y: real, pressed: bool, dragStart: point, dragX: real, dragY: real): void {
                if (!root.panelsVisible) return;

                for (let i = 0; i < panelRepeater.count; i++) {
                    const band = panelRepeater.itemAt(i);

                    if (!band || band.persistent) continue;

                    if (band.revealOnHover) {
                        if (band.inStrip(x, y))
                            band.hovered = true;

                        continue;
                    }

                    if (pressed && band.inStrip(dragStart.x, dragStart.y)) {
                        // Dragging inwards past the threshold pulls the panel
                        // open, dragging back out closes it again.
                        const inward = band.horizontal ? (band.edge === "top" ? dragY : -dragY) : (band.edge === "left" ? dragX : -dragX);

                        if (inward > Config.bar.dragThreshold)
                            band.pulled = true;
                        else if (inward < -Config.bar.dragThreshold)
                            band.pulled = false;
                    }
                }
            }
            // Hides again every band that came out on hover, mirroring what the
            // bar does when the pointer leaves the frame.
            function clearReveal(): void {
                for (let i = 0; i < panelRepeater.count; i++) {
                    const band = panelRepeater.itemAt(i);

                    if (band)
                        band.hovered = false;
                }
            }

            anchors.fill: parent
            // Like the bar, the panels collapse while the overview is up or a
            // window is fullscreen (the frame edges already do the same).
            visible: root.panelsVisible

            Repeater {
                id: panelRepeater

                model: root.panelRects

                delegate: Item {
                    id: band

                    required property var modelData

                    readonly property string edge: modelData.edge
                    readonly property bool horizontal: modelData.horizontal
                    readonly property bool full: modelData.full
                    // A panel stays on screen unless it says otherwise, and then
                    // it either follows the pointer or waits for a drag.
                    readonly property bool persistent: modelData.panel.persistent !== false
                    readonly property bool revealOnHover: modelData.panel.showOnHover !== false
                    // Whether it came out because the pointer is on it, or
                    // because it was pulled open from its edge.
                    property bool hovered
                    property bool pulled
                    readonly property bool revealed: band.persistent || band.hovered || band.pulled
                    // A panel that is away leaves the plain border at its edge,
                    // like the bar does when it is not persistent.
                    readonly property real hiddenThickness: Config.border.thickness
                    readonly property real thickness: band.horizontal ? band.height : band.width
                    // A band that settled at its edge leaves the plain border
                    // there, which the frame already draws in the group's own
                    // colour. Keeping its island would not show it - it sits
                    // inside the border - but the group's smooth union would
                    // bulge the border inward around it, which showed up as a
                    // sliver of the panel sticking out of the frame. It stays
                    // in while the band slides, so the movement is unchanged.
                    readonly property bool islandAway: !band.revealed && band.thickness <= band.hiddenThickness + 0.5
                    readonly property real triggerThickness: Math.max(Config.border.minThickness, band.thickness)
                    // A panel takes its space away from the windows while it is
                    // on screen, or held open by a drag, but not while it only
                    // follows the pointer.
                    readonly property bool takesSpace: band.persistent || band.pulled
                    // The plain rectangles the window's regions - the island
                    // blobs, the background blur and the input mask - follow.
                    // They are snapped to whether the panel is out or away, so
                    // they change once per transition instead of every frame.
                    readonly property var revealedRect: ({
                        x: modelData.x,
                        y: modelData.y,
                        width: modelData.width,
                        height: modelData.height
                    })
                    readonly property var restingRect: band.horizontal ? ({
                        x: modelData.x,
                        y: band.edge === "top" ? 0 : root.height - Config.border.thickness,
                        width: modelData.width,
                        height: Config.border.thickness
                    }) : ({
                        x: band.edge === "left" ? 0 : root.width - Config.border.thickness,
                        y: modelData.y,
                        width: Config.border.thickness,
                        height: modelData.height
                    })
                    readonly property var place: band.revealed ? band.revealedRect : band.restingRect

                    // Whether the given point is on the strip the panel keeps at
                    // its edge, measured from the screen edge so a panel that is
                    // away is still reachable.
                    function inStrip(x: real, y: real): bool {
                        const along = band.horizontal ? x >= band.x && x <= band.x + band.width : y >= band.y && y <= band.y + band.height;

                        if (!along) return false;

                        return band.horizontal ? (band.edge === "top" ? y <= band.triggerThickness : y >= root.height - band.triggerThickness) : (band.edge === "left" ? x <= band.triggerThickness : x >= root.width - band.triggerThickness);
                    }

                    // The popouts grow out of the frame edge, so the band tells
                    // the wrapper which edge opened them and how far past the
                    // frame its own inner side sits: a full-edge panel needs
                    // neither, a partial one starts at its island's inner side.
                    function applyPopoutContext(): void {
                        const host = band.edge === "top" ? panels.topMargin : band.edge === "bottom" ? panels.bottomMargin : band.edge === "left" ? panels.leftMargin : panels.rightMargin;
                        const inner = band.horizontal ? (band.edge === "top" ? band.y + band.height : root.height - band.y) : (band.edge === "left" ? band.x + band.width : root.width - band.x);

                        panels.popouts.currentEdge = band.edge;
                        panels.popouts.currentInset = Math.max(0, inner - host);
                    }
                    // Mirrors what the bar wrapper forwards to its Bar: the
                    // position along the band's edge, which is the window
                    // coordinate on that axis brought into the band.
                    function checkPopout(x: real, y: real): void {
                        band.applyPopoutContext();
                        bandBar.checkPopout(band.horizontal ? x - band.x : y - band.y);
                    }
                    function resetHover(): void {
                        bandBar.resetHover();
                    }
                    function handleWheel(x: real, y: real, angleDelta: point): void {
                        bandBar.handleWheel(band.horizontal ? x - band.x : y - band.y, angleDelta);
                    }

                    x: modelData.x
                    y: modelData.y
                    width: modelData.width
                    height: modelData.height

                    // The band slides in and out of the frame edge like the bar
                    // does: it keeps its place while its panel stays on screen,
                    // and otherwise leaves nothing but the border strip behind.
                    clip: true
                    visible: band.horizontal ? band.height > Config.border.thickness : band.width > Config.border.thickness

                    states: State {
                        name: "hidden"
                        when: !band.revealed

                        PropertyChanges {
                            target: band

                            x: band.horizontal ? band.modelData.x : (band.edge === "left" ? 0 : root.width - band.hiddenThickness)
                            y: band.horizontal ? (band.edge === "top" ? 0 : root.height - band.hiddenThickness) : band.modelData.y
                            width: band.horizontal ? band.modelData.width : band.hiddenThickness
                            height: band.horizontal ? band.hiddenThickness : band.modelData.height

                            // The rows fade with the slide instead of vanishing
                            // in one step the moment the band reaches the edge,
                            // and at rest nothing of them is left drawn under
                            // the frame.
                            opacity: 0
                        }
                    }
                    transitions: [
                        Transition {
                            from: ""
                            to: "hidden"

                            Anim {
                                target: band
                                property: band.horizontal ? "height" : "width"
                                type: Anim.Emphasized
                            }
                            Anim {
                                target: band
                                property: band.horizontal ? "y" : "x"
                                type: Anim.Emphasized
                            }
                            Anim {
                                target: band
                                property: "opacity"
                                type: Anim.Emphasized
                            }
                        },
                        Transition {
                            from: "hidden"
                            to: ""

                            Anim {
                                target: band
                                property: band.horizontal ? "height" : "width"
                                type: Anim.DefaultSpatial
                            }
                            Anim {
                                target: band
                                property: band.horizontal ? "y" : "x"
                                type: Anim.DefaultSpatial
                            }
                            Anim {
                                target: band
                                property: "opacity"
                                type: Anim.DefaultSpatial
                            }
                        }
                    ]

                    Bar {
                        id: bandBar

                        anchors.fill: parent
                        anchors.topMargin: band.horizontal ? 0 : bar.padding
                        anchors.bottomMargin: band.horizontal ? 0 : bar.padding
                        anchors.leftMargin: band.horizontal ? bar.padding : 0
                        anchors.rightMargin: band.horizontal ? bar.padding : 0

                        position: band.edge
                        panelIndex: band.modelData.panelIndex
                        entries: band.modelData.panel.entries
                        screen: root.screen
                        visibilities: root.visibilities
                        popouts: panels.popouts
                        fullscreen: root.hasFullscreen
                    }
                }
            }
        }
        Panels {
            id: panels

            screen: root.screen
            screenState: root.screenState
            visibilities: visibilities
            bar: bar
            borderThickness: root.borderThickness
            overviewBorderThickness: root.overviewBorderThickness
            frameEdges: root.frameEdges
            overviewAnimConfig: root.overviewAnimConfig
            utilities.horizontalStretch: (sidebarBg.rawDeformMatrix.m11 - 1) / 2 + 1
            utilities.deformMatrix: utilsBg.rawDeformMatrix
            dashboard.transform: Matrix4x4 {
                matrix: dashBg.deformMatrix
            }
            launcher.transform: Matrix4x4 {
                matrix: launcherBg.deformMatrix
            }
            session.transform: Matrix4x4 {
                matrix: sessionBg.deformMatrix
            }
            sidebar.transform: Matrix4x4 {
                matrix: sidebarBg.deformMatrix
            }
            osd.transform: Matrix4x4 {
                matrix: osdBg.deformMatrix
            }
            notifications.transform: Matrix4x4 {
                matrix: notifsBg.deformMatrix
            }
            utilities.transform: Matrix4x4 {
                matrix: utilsBg.deformMatrix
            }
            popouts.transform: Matrix4x4 {
                matrix: popoutBg.deformMatrix
            }
            cursorPos: Qt.point(interactions.mouseX, interactions.mouseY)
        }
        BarWrapper {
            id: bar

            property string vAnchor: (bar.position === "left" || bar.position === "right") ? "both" : (bar.position === "top" ? "top" : "bottom")
            property string hAnchor: (bar.position === "top" || bar.position === "bottom") ? "both" : (bar.position === "left" ? "left" : "right")

            screen: root.screen
            visibilities: visibilities
            popouts: panels.popouts
            fullscreen: root.hasFullscreen
            Component.onCompleted: Visibilities.registerBar(root.screen, this)
        }
        Connections {
            function onOpenDesktopContextMenu(x, y, screenName) {
                if (ContextMenuStore.editMode || Config.background.disableQuickshellDesktop)
                    return;
                if (root.screen.name === screenName) {
                    desktopContextMenuAnchor.x = x;
                    desktopContextMenuAnchor.y = y;
                    // Already open: jump to the new spot and unfold again
                    // instead of closing and waiting before reopening.
                    if (desktopContextMenu.expanded)
                        desktopContextMenu.reopen();
                    else
                        desktopContextMenu.expanded = true;
                }
            }

            target: ContextMenuStore
        }
        Connections {
            function onOpenIconContextMenu(screenName: string, x: real, y: real, keys: var, inGroup: string): void {
                if (root.screen.name === screenName) {
                    desktopIconContextMenu.openAt(x, y, keys, inGroup);
                }
            }

            function onOpenDropMenu(screenName: string, x: real, y: real, urls: var, target: string, cell: var): void {
                if (root.screen.name === screenName) {
                    dropMenu.openAt(x, y, urls, target, cell);
                }
            }

            function onViewOptionsRequested(screenName: string, x: real, y: real): void {
                if (root.screen.name === screenName) {
                    viewOptions.openAt(x, y);
                }
            }

            function onAddWidgetRequested(screenName: string, x: real, y: real): void {
                if (root.screen.name === screenName) {
                    const ctrl = DesktopLayout.controllerFor(screenName);
                    widgetGallery.openAt(x, y, ctrl ? ctrl.cellAt(x, y) : null);
                }
            }

            target: DesktopLayout
        }
        Item {
            id: desktopContextMenuAnchor
        }
        DesktopContextMenu {
            id: desktopContextMenu

            attachTo: desktopContextMenuAnchor
            screenName: root.screen.name
            z: 9999
        }
        DesktopIconContextMenu {
            id: desktopIconContextMenu

            controller: DesktopLayout.controllerFor(root.screen.name)
            z: 9999
        }
        DropMenu {
            id: dropMenu

            controller: DesktopLayout.controllerFor(root.screen.name)
            z: 9999
        }
        ViewOptions {
            id: viewOptions

            controller: DesktopLayout.controllerFor(root.screen.name)
            z: 10000
        }
        WidgetGallery {
            id: widgetGallery

            controller: DesktopLayout.controllerFor(root.screen.name)
            z: 10000
        }
    }

    Config.screen: screen.name
    BackgroundEffect.blurRegion: Region {
        Region { x: -10; y: -10; width: 1; height: 1 }
        Region {
            x: 0; y: 0
            width: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur) ? root.frameEdges.left : 0
            height: root.height
            intersection: Intersection.Combine
        }
        Region {
            x: root.width - root.frameEdges.right; y: 0
            width: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur) ? root.frameEdges.right : 0
            height: root.height
            intersection: Intersection.Combine
        }
        Region {
            x: 0; y: 0
            width: root.width
            height: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur) ? root.frameEdges.top : 0
            intersection: Intersection.Combine
        }
        Region {
            x: 0; y: root.height - root.frameEdges.bottom
            width: root.width
            height: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur) ? root.frameEdges.bottom : 0
            intersection: Intersection.Combine
        }
        // A partial panel is drawn over the frame instead of inside it, so its
        // strip needs the same background blur as the edge it hangs from. The
        // slots mirror the cutouts in the input region (see Regions.qml).
        PanelBlur {
            rect: root.partialPanelStrips[0] ?? null
        }
        PanelBlur {
            rect: root.partialPanelStrips[1] ?? null
        }
        PanelBlur {
            rect: root.partialPanelStrips[2] ?? null
        }
        PanelBlur {
            rect: root.partialPanelStrips[3] ?? null
        }
        PanelBlur {
            rect: root.partialPanelStrips[4] ?? null
        }
        PanelBlur {
            rect: root.partialPanelStrips[5] ?? null
        }
        PanelBlur {
            rect: root.partialPanelStrips[6] ?? null
        }
        PanelBlur {
            rect: root.partialPanelStrips[7] ?? null
        }
        Region {
            x: root.frameEdges.left
            y: root.frameEdges.top
            width: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur && GlobalConfig.appearance.blurMask) ? root.borderRounding : 0
            height: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur && GlobalConfig.appearance.blurMask) ? root.borderRounding : 0
            intersection: Intersection.Combine
        }
        Region {
            x: root.width - root.frameEdges.right - root.borderRounding
            y: root.frameEdges.top
            width: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur && GlobalConfig.appearance.blurMask) ? root.borderRounding : 0
            height: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur && GlobalConfig.appearance.blurMask) ? root.borderRounding : 0
            intersection: Intersection.Combine
        }
        Region {
            x: root.frameEdges.left
            y: root.height - root.frameEdges.bottom - root.borderRounding
            width: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur && GlobalConfig.appearance.blurMask) ? root.borderRounding : 0
            height: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur && GlobalConfig.appearance.blurMask) ? root.borderRounding : 0
            intersection: Intersection.Combine
        }
        Region {
            x: root.width - root.frameEdges.right - root.borderRounding
            y: root.height - root.frameEdges.bottom - root.borderRounding
            width: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur && GlobalConfig.appearance.blurMask) ? root.borderRounding : 0
            height: (!GlobalConfig.appearance.islands && GlobalConfig.appearance.blur && GlobalConfig.appearance.blurMask) ? root.borderRounding : 0
            intersection: Intersection.Combine
        }
        BlurCorners {
            intersection: Intersection.Subtract
            vAnchor: "none"
            hAnchor: "none"
            blurQuality: borderBlurSettings.blurQuality
            inLeft: root.frameEdges.left + root.borderRounding
            inRight: root.width - root.frameEdges.right - root.borderRounding
            inTop: root.frameEdges.top + root.borderRounding
            inBottom: root.height - root.frameEdges.bottom - root.borderRounding
            rTop: !GlobalConfig.appearance.islands ? root.borderRounding : 0
            rBottom: !GlobalConfig.appearance.islands ? root.borderRounding : 0
            rLeft: !GlobalConfig.appearance.islands ? root.borderRounding : 0
            rRight: !GlobalConfig.appearance.islands ? root.borderRounding : 0
        }
        BlurMask {
            target: bar
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: bar.vAnchor
            hAnchor: bar.hAnchor
        }
        BlurMask {
            target: panels.sidebar
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: panels.sidebar.vAnchor
            hAnchor: panels.sidebar.hAnchor
            offsetScale: panels.sidebar.offsetScale
            deformMatrix: sidebarBg.deformMatrix
        }
        BlurMask {
            target: panels.notifications
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: panels.notifications.vAnchor
            hAnchor: panels.notifications.hAnchor
            deformMatrix: notifsBg.deformMatrix
        }
        BlurMask {
            target: panels.osdWrapper
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: panels.osdWrapper.vAnchor
            hAnchor: panels.osdWrapper.hAnchor
            offsetScale: panels.osd.offsetScale
            deformMatrix: osdBg.deformMatrix
        }
        BlurMask {
            target: panels.sessionWrapper
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: panels.sessionWrapper.vAnchor
            hAnchor: panels.sessionWrapper.hAnchor
            offsetScale: panels.session.offsetScale
            deformMatrix: sessionBg.deformMatrix
        }
        BlurMask {
            target: panels.launcher
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: panels.launcher.vAnchor
            hAnchor: panels.launcher.hAnchor
            offsetScale: panels.launcher.offsetScale
            deformMatrix: launcherBg.deformMatrix
        }
        BlurMask {
            target: panels.dashboard
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: panels.dashboard.vAnchor
            hAnchor: panels.dashboard.hAnchor
            offsetScale: panels.dashboard.offsetScale
            deformMatrix: dashBg.deformMatrix
        }
        BlurMask {
            target: panels.popoutsWrapper
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop - (popoutBg.connectedToSidebar ? Tokens.spacing.extraLarge + 10 + Tokens.rounding.extraLarge : 0)
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: panels.popoutsWrapper.vAnchor
            hAnchor: panels.popoutsWrapper.hAnchor
            offsetScale: panels.popoutsWrapper.offsetScale
            deformMatrix: popoutBg.deformMatrix
        }
        BlurMask {
            target: panels.utilities
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: panels.utilities.vAnchor
            hAnchor: panels.utilities.hAnchor
            offsetScale: panels.utilities.offsetScale
            deformMatrix: utilsBg.deformMatrix
        }
        BlurMask {
            target: desktopContextMenu.visible ? desktopContextMenu.backgroundItem : null
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft + 1
            blurOffsetRight: root.blurOffsetRight
            vAnchor: desktopContextMenu.backgroundItem.vAnchor
            hAnchor: desktopContextMenu.backgroundItem.hAnchor
            offsetScale: desktopContextMenu.backgroundItem.offsetScale
            deformMatrix: contextMenuBg.deformMatrix
        }
        BlurMask {
            target: (visibilities.overview && !GlobalConfig.overview.disableWallpaperBlur) ? panels.overview : null
            contentItem: root.contentItem
            blurOffsetTop: root.blurOffsetTop
            blurOffsetBottom: root.blurOffsetBottom
            blurOffsetLeft: root.blurOffsetLeft
            blurOffsetRight: root.blurOffsetRight
            vAnchor: "both"
            hAnchor: "both"
        }
    }

    component PanelBlur: Region {
        required property var rect

        x: rect && !GlobalConfig.appearance.islands && GlobalConfig.appearance.blur ? rect.x : 0
        y: rect && !GlobalConfig.appearance.islands && GlobalConfig.appearance.blur ? rect.y : 0
        width: rect && !GlobalConfig.appearance.islands && GlobalConfig.appearance.blur ? rect.width : 0
        height: rect && !GlobalConfig.appearance.islands && GlobalConfig.appearance.blur ? rect.height : 0
        intersection: Intersection.Combine
    }

    component PanelBg: BlobRect {
        required property Item panel
        property real deformAmount: 0.15

        group: panel.visible ? blobGroup : null
        visible: panel.visible
        x: panel.x + panels.leftMargin
        y: panel.y + panels.topMargin
        implicitWidth: panel.width
        implicitHeight: panel.height
        radius: Tokens.rounding.extraLarge
        deformScale: (GlobalConfig.appearance.blurMask || !GlobalConfig.appearance.transparency.enabled) ? ((deformAmount * Config.appearance.deformScale) / 10000) : 0
        Config.screen: root.screen.name
    }
}
