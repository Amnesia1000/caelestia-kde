pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<string> allEdges: ["top", "bottom", "left", "right"]
    readonly property bool hasSelection: root.selectedIndex >= 0 && root.selectedIndex < GlobalConfig.bar.panels.count
    readonly property var selectedPanel: root.hasSelection ? GlobalConfig.bar.panels.at(root.selectedIndex) : null
    readonly property var alignItems: root.itemsOf(alignInstantiator)
    readonly property var positionItems: root.itemsOf(edgeInstantiator)
    readonly property var screenItems: root.itemsOf(screenInstantiator)
    readonly property var addableEdges: root.allEdges.map(edge => ({
        id: edge,
        label: root.edgeLabel(edge)
    }))
    readonly property var screenModel: [{
        name: "",
        label: qsTr("All screens")
    }].concat(Quickshell.screens.map(s => ({
        name: s.name,
        label: s.name
    })))

    property int selectedIndex: 0
    property real lengthDraft: -1

    readonly property Timer lengthTimer: Timer {
        interval: 250

        onTriggered: {
            if (root.lengthDraft >= 0 && root.selectedPanel)
                root.selectedPanel.lengthPercent = Math.round(root.lengthDraft);

            root.lengthDraft = -1;
        }
    }

    function itemsOf(instantiator: var): var {
        const items = [];

        for (let i = 0; i < instantiator.count; ++i)
            items.push(instantiator.objectAt(i));

        return items;
    }
    function alignLabel(align: string): string {
        if (align === "start")
            return qsTr("Start");
        if (align === "end")
            return qsTr("End");
        return qsTr("Center");
    }
    function edgeLabel(edge: string): string {
        if (edge === "top")
            return qsTr("Top");
        if (edge === "bottom")
            return qsTr("Bottom");
        if (edge === "left")
            return qsTr("Left");
        if (edge === "right")
            return qsTr("Right");
        return edge;
    }
    function itemFor(items: var, value: string): MenuItem {
        for (let i = 0; i < items.length; ++i)
            if (items[i].value === value)
                return items[i];

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

    Instantiator {
        id: alignInstantiator

        model: ["start", "center", "end"]

        delegate: MenuItem {
            required property string modelData

            value: modelData
            text: root.alignLabel(modelData)
        }
    }
    Instantiator {
        id: edgeInstantiator

        model: root.allEdges

        delegate: MenuItem {
            required property string modelData

            value: modelData
            text: root.edgeLabel(modelData)
        }
    }
    Instantiator {
        id: screenInstantiator

        model: root.screenModel

        delegate: MenuItem {
            required property var modelData

            value: modelData.name
            text: modelData.label
        }
    }

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
            icon: "widgets"
            text: qsTr("Widgets of this bar")
            subtext: qsTr("Pick the components it shows")
            onClicked: {
                root.nState.barComponentsTarget = root.selectedIndex;
                root.nState.openSubPage(6);
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
