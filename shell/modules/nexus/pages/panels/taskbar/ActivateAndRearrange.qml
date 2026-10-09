pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.bar.components as BarComponents

ColumnLayout {
    id: root

    required property var entriesOverride
    required property var writeEntries
    required property var nState

    readonly property var componentMeta: BarComponents.componentMeta

    property var entries: []

    function load(): void {
        const src = root.entriesOverride ?? [];
        root.entries = [];
        for (let i = 0; i < src.length; i++) {
            const e = src[i];
            if (e.id !== "spacer")
                root.entries.push({ id: e.id, enabled: e.enabled, zone: e.zone });
        }
    }

    function save(): void {
        if (root.writeEntries)
            root.writeEntries(root.entries);
    }

    function move(from: int, to: int): void {
        if (from < 0 || to < 0 || from >= root.entries.length || to >= root.entries.length || from === to)
            return;
        root.entries.move(from, to, 1);
        save();
    }

    function toggleEnabled(index: int): void {
        if (index < 0 || index >= root.entries.length)
            return;
        root.entries[index].enabled = !root.entries[index].enabled;
        save();
    }

    Component.onCompleted: load()

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: root.entries
        delegate: Item {
            width: ListView.view.width
            height: 50

            RowLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: root.componentMeta[modelData.id]?.icon ?? "widgets"
                    color: modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                }

                Text {
                    Layout.fillWidth: true
                    text: root.componentMeta[modelData.id]?.name ?? modelData.id
                    font: Tokens.font.body.small
                    color: modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                }

                ToggleButton {
                    checked: modelData.enabled
                    onToggled: root.toggleEnabled(index)
                }

                IconButton {
                    icon: "drag_indicator"
                    type: IconButton.Text
                    onPressed: {
                        // Drag to reorder - handled by ListView move
                    }
                }
            }

            Drag.active: Drag.active
            Drag.source: parent
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Drag.keys: ["component"]

            MouseArea {
                anchors.fill: parent
                drag.target: parent
                drag.axis: Drag.YAxis
                onReleased: {
                    // The move is handled by ListView.move in onMoved
                }
            }
        }

        move: Transition {
            Anim { properties: "y"; type: Anim.FastSpatial }
        }
        moveDisplaced: Transition {
            Anim { properties: "y"; type: Anim.FastSpatial }
        }
    }
}
