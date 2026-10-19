pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components.controls
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    // The main bar keeps its own edge and a bar per edge is all that fits, so
    // the edges a bar can be put on are the ones nothing is sitting on.
    readonly property list<string> allEdges: ["top", "bottom", "left", "right"]
    readonly property bool hasSelection: root.selectedIndex >= 0 && root.selectedIndex < GlobalConfig.bar.panels.count
    readonly property var selectedPanel: root.hasSelection ? GlobalConfig.bar.panels.at(root.selectedIndex) : null

    readonly property var alignItems: root.buildAlignItems()
    readonly property var positionItems: root.edgeItems(root.selectedPanel?.position ?? "")
    readonly property var addableEdges: root.edgeDialogItems()
    readonly property var screenItems: root.buildScreenItems()

    readonly property Component menuItemComp: Component {
        MenuItem {}
    }

    // The length is written once the stepping stops, so dragging the control
    // does not rewrite the config on every step.
    readonly property Timer lengthTimer: Timer {
        interval: 250

        onTriggered: {
            if (root.lengthDraft >= 0 && root.selectedPanel)
                root.selectedPanel.lengthPercent = Math.round(root.lengthDraft);
            root.lengthDraft = -1;
        }
    }

    property int selectedIndex: 0
    property real lengthDraft: -1

    function buildAlignItems(): var {
        const values = ["start", "center", "end"];
        const items = [];
        for (let i = 0; i < values.length; ++i) {
            const value = values[i];
            items.push(root.menuItemComp.createObject(root, {
                value: value,
                text: root.alignLabel(value)
            }));
        }

        return items;
    }

    function alignLabel(align: string): string {
        switch (align) {
        case "start":
            return qsTr("Start");
        case "end":
            return qsTr("End");
        }

        return qsTr("Center");
    }

    function edgeLabel(edge: string): string {
        switch (edge) {
        case "top":
            return qsTr("Top");
        case "bottom":
            return qsTr("Bottom");
        case "left":
            return qsTr("Left");
        case "right":
            return qsTr("Right");
        }

        return edge;
    }

    function edgesInUse(): var {
        const used = [GlobalConfig.bar.position];
        for (let i = 0; i < GlobalConfig.bar.panels.count; ++i) {
            const panel = GlobalConfig.bar.panels.at(i);
            if (panel)
                used.push(panel.position);
        }

        return used;
    }

    function freeEdges(keep: string): var {
        const used = root.edgesInUse();
        const free = [];
        for (let i = 0; i < root.allEdges.length; ++i) {
            const edge = root.allEdges[i];
            if (edge === keep || used.indexOf(edge) === -1)
                free.push(edge);
        }

        return free;
    }

    function edgeItems(keep: string): var {
        const edges = root.freeEdges(keep);
        const items = [];
        for (let i = 0; i < edges.length; ++i) {
            items.push(root.menuItemComp.createObject(root, {
                value: edges[i],
                text: root.edgeLabel(edges[i])
            }));
        }

        return items;
    }

    // DialogSelectButton reads `id` and `label` off each entry, not `value`
    // and `text` the way a SelectRow does.
    function edgeDialogItems(): var {
        const free = root.freeEdges("");
        const items = [];
        for (let i = 0; i < free.length; ++i) {
            items.push({
                id: free[i],
                label: root.edgeLabel(free[i])
            });
        }

        return items;
    }

    function buildScreenItems(): var {
        const items = [root.menuItemComp.createObject(root, {
            value: "",
            text: qsTr("All screens")
        })];
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; ++i) {
            items.push(root.menuItemComp.createObject(root, {
                value: screens[i].name,
                text: screens[i].name
            }));
        }

        return items;
    }

    function itemFor(items: var, value: string): MenuItem {
        for (let i = 0; i < items.length; ++i) {
            if (items[i].value === value)
                return items[i];
        }

        return items.length > 0 ? items[0] : null;
    }

    function addBar(position: string): void {
        GlobalConfig.bar.panels.insert({
            name: qsTr("Bar %1").arg(GlobalConfig.bar.panels.count + 1),
            position: position,
            lengthPercent: 50,
            align: "center",
            persistent: true,
            showOnHover: true,
            screens: [],
            entries: []
        });
        root.selectedIndex = GlobalConfig.bar.panels.count - 1;
    }

    function removeSelected(): void {
        const index = root.selectedIndex;
        if (index < 0 || index >= GlobalConfig.bar.panels.count)
            return;

        GlobalConfig.bar.panels.remove(index);
        root.selectedIndex = Math.min(index, GlobalConfig.bar.panels.count - 1);
    }

    function queueLength(value: real): void {
        root.lengthDraft = value;
        root.lengthTimer.restart();
    }

    title: qsTr("Extra bars")
    isSubPage: true

    onSelectedIndexChanged: root.lengthDraft = -1

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Bars")
        }

        Repeater {
            model: GlobalConfig.bar.panels.values

            RowButton {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0
                last: index === GlobalConfig.bar.panels.count - 1
                icon: root.selectedIndex === index ? "radio_button_checked" : "radio_button_unchecked"
                text: modelData.name || qsTr("Bar %1").arg(index + 1)
                subtext: {
                    const screens = modelData.screens ?? [];
                    return root.edgeLabel(modelData.position) + " · " + (screens.length > 0 ? screens[0] : qsTr("All screens"));
                }
                onClicked: root.selectedIndex = index
            }
        }

        DialogSelectButton {
            rootParent: root.flickable

            visible: root.addableEdges.length > 0
            icon: "add"
            label: qsTr("Add bar")
            header: qsTr("Which edge?")
            acceptLabel: qsTr("Add")
            model: root.addableEdges
            onAccepted: {
                if (selectedItem)
                    root.addBar(selectedItem);
            }
        }

        RowButton {
            Layout.fillWidth: true

            visible: root.addableEdges.length === 0
            first: GlobalConfig.bar.panels.count === 0
            last: true
            icon: "info"
            text: qsTr("Every edge has a bar")
            subtext: qsTr("Move or remove one to free an edge")
        }

        SectionHeader {
            visible: root.hasSelection
            text: root.selectedPanel ? (root.selectedPanel.name || qsTr("Unnamed bar")) : ""
        }

        TextFieldRow {
            Layout.fillWidth: true

            visible: root.hasSelection
            first: true
            label: qsTr("Name")
            placeholderText: qsTr("Bar %1").arg(root.selectedIndex + 1)
            maximumLength: 40
            value: root.selectedPanel?.name ?? ""
            onEditingFinished: value => {
                if (root.selectedPanel)
                    root.selectedPanel.name = value;
            }
        }

        SelectRow {
            Layout.fillWidth: true

            visible: root.hasSelection
            label: qsTr("Position")
            subtext: qsTr("Only the edges without a bar are offered")
            menuItems: root.positionItems
            active: root.itemFor(root.positionItems, root.selectedPanel?.position ?? "")
            onSelected: item => {
                if (root.selectedPanel)
                    root.selectedPanel.position = item.value;
            }
        }

        SelectRow {
            Layout.fillWidth: true

            visible: root.hasSelection
            label: qsTr("Alignment")
            menuItems: root.alignItems
            active: root.itemFor(root.alignItems, root.selectedPanel?.align ?? "center")
            onSelected: item => {
                if (root.selectedPanel)
                    root.selectedPanel.align = item.value;
            }
        }

        StepperRow {
            Layout.fillWidth: true

            visible: root.hasSelection
            label: qsTr("Length")
            subtext: qsTr("Share of the edge the bar takes")
            from: 10
            to: 100
            stepSize: 5
            value: root.lengthDraft >= 0 ? root.lengthDraft : (root.selectedPanel?.lengthPercent ?? 50)
            onMoved: value => root.queueLength(value)
        }

        SelectRow {
            Layout.fillWidth: true

            visible: root.hasSelection
            label: qsTr("Screens")
            menuItems: root.screenItems
            active: root.itemFor(root.screenItems, root.selectedPanel && root.selectedPanel.screens.length > 0 ? root.selectedPanel.screens[0] : "")
            onSelected: item => {
                if (root.selectedPanel)
                    root.selectedPanel.screens = item.value ? [item.value] : [];
            }
        }

        ToggleRow {
            Layout.fillWidth: true

            visible: root.hasSelection
            text: qsTr("Enabled")
            checked: root.selectedPanel?.enabled ?? true
            onToggled: {
                if (root.selectedPanel)
                    root.selectedPanel.enabled = checked;
            }
        }

        ToggleRow {
            Layout.fillWidth: true

            visible: root.hasSelection
            text: qsTr("Always visible")
            subtext: qsTr("Keep the bar on screen instead of revealing it on hover")
            checked: root.selectedPanel?.persistent ?? true
            onToggled: {
                if (root.selectedPanel)
                    root.selectedPanel.persistent = checked;
            }
        }

        ToggleRow {
            Layout.fillWidth: true

            visible: root.hasSelection
            enabled: !(root.selectedPanel?.persistent ?? true)
            text: qsTr("Show on hover")
            checked: root.selectedPanel?.showOnHover ?? true
            onToggled: {
                if (root.selectedPanel)
                    root.selectedPanel.showOnHover = checked;
            }
        }

        RowButton {
            Layout.fillWidth: true

            visible: root.hasSelection
            last: true
            icon: "delete"
            text: qsTr("Remove this bar")
            onClicked: root.removeSelected()
        }
    }
}
