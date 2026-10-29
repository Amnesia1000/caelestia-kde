import QtQuick
import Caelestia.Config
import qs.components
import qs.modules.nexus

Item {
    id: root

    required property NexusState nState

    property int lastPageIdx
    property int animOff
    readonly property int animMovement: Tokens.padding.extraExtraLarge * 2
    property Item currentItem
    property int loadGeneration: 0

    function loadPage(idx: int): void {
        const generation = ++loadGeneration;

        if (currentItem) {
            currentItem.visible = false;
            currentItem.destroy();
            currentItem = null;
        }

        const comp = PageCompRegistry.pageComps[idx] ?? PageCompRegistry.placeholderComp;
        const incubator = comp.incubateObject(container, {
            nState,
            visible: false
        });

        const attach = () => {
            if (generation !== loadGeneration) {
                incubator.object.destroy();
                return;
            }

            incubator.object.anchors.fill = container;
            incubator.object.visible = true;
            currentItem = incubator.object;
        };

        if (incubator.status === Component.Ready)
            attach();
        else
            incubator.onStatusChanged = status => {
                if (status === Component.Ready)
                    attach();
                else if (status === Component.Error && incubator.object)
                    incubator.object.destroy();
            };
    }

    function activePage(): var {
        let item = root.currentItem;
        while (item) {
            if (item.contentChild !== undefined && item.flickable !== undefined)
                return item;
            item = item.currentItem ?? null;
        }
        return null;
    }

    function moveUp(): void {
        const page = activePage();
        if (page && typeof page.moveUp === "function")
            page.moveUp();
    }

    function moveDown(): void {
        const page = activePage();
        if (page && typeof page.moveDown === "function")
            page.moveDown();
    }

    function activateSelected(): void {
        const page = activePage();
        if (page && typeof page.activateSelected === "function")
            page.activateSelected();
    }

    function clearSelection(): void {
        const page = activePage();
        if (page && typeof page.clearSelection === "function")
            page.clearSelection();
    }

    Item {
        id: container

        objectName: "PageContainer"
        anchors.fill: parent
        layer.enabled: opacity < 1
        Component.onCompleted: root.loadPage(root.nState.currentPageIdx)
    }

    Connections {
        function onCurrentPageIdxChanged(): void {
            root.clearSelection();
            switchAnim.complete();
            root.animOff = root.animMovement * (root.nState.currentPageIdx > root.lastPageIdx ? 1 : -1);
            switchAnim.start();
            root.lastPageIdx = root.nState.currentPageIdx;
        }

        target: root.nState
    }

    SequentialAnimation {
        id: switchAnim

        Anim {
            target: container
            property: "opacity"
            to: 0
            type: Anim.DefaultEffects
        }
        ScriptAction {
            script: root.loadPage(root.nState.currentPageIdx)
        }
        PropertyAction {
            target: container.anchors
            property: "topMargin"
            value: root.animOff
        }
        PropertyAction {
            target: container.anchors
            property: "bottomMargin"
            value: -root.animOff
        }
        ParallelAnimation {
            Anim {
                target: container
                property: "opacity"
                from: 0
                to: 1
                type: Anim.SlowEffects
            }
            Anim {
                target: container.anchors
                properties: "topMargin,bottomMargin"
                to: 0
                type: Anim.SlowEffects
            }
        }
    }
}
