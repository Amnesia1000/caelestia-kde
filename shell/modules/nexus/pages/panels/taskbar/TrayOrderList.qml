pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

// A vertical list whose rows can be dragged into a new order. `entries` holds the
// rows; `moved` reports their key order once per drop, after the held row settles
// into its slot.
ListView {
    id: root

    property var entries: []
    property int dragIndex: -1
    property real grabDy: 0
    property real dragTop: 0
    property real landingY: 0
    property bool landing: false
    readonly property bool dragging: root.dragIndex >= 0

    signal moved(var keys)

    function sync(): void {
        if (root.dragging)
            return;

        const entries = root.entries;
        if (entries.length === rows.count) {
            let same = true;
            for (let i = 0; i < entries.length && same; i++) {
                const entry = entries[i];
                const row = rows.get(i);
                same = row.trayId === entry.id && row.trayKey === entry.alias && row.title === entry.title && row.trayIcon === entry.icon && row.running === entry.running;
            }
            if (same)
                return;
        }

        rows.clear();
        for (const entry of entries)
            rows.append({
                trayId: entry.id,
                trayKey: entry.alias,
                title: entry.title,
                trayIcon: entry.icon,
                running: entry.running
            });
    }

    function indexOf(key: string): int {
        for (let i = 0; i < rows.count; i++)
            if (rows.get(i).trayKey === key)
                return i;
        return -1;
    }

    // Grabs the row under the pointer. `sceneY` is a scene coordinate so the row can
    // be followed from a handle that is not the delegate itself.
    function press(key: string, sceneY: real): void {
        const index = root.indexOf(key);
        const content = root.contentItem;
        if (index < 0 || !content)
            return;

        root.landing = false;
        landAnim.stop();

        const item = root.itemAtIndex(index);
        const y = content.mapFromItem(null, 0, sceneY).y;
        root.dragIndex = index;
        root.grabDy = item ? y - item.y : 0;
        root.dragTop = y - root.grabDy;
    }

    function drag(sceneY: real): void {
        if (root.dragIndex < 0)
            return;

        const content = root.contentItem;
        if (!content)
            return;

        const y = content.mapFromItem(null, 0, sceneY).y;
        root.dragTop = y - root.grabDy;

        const target = root.indexAt(root.width / 2, y);
        if (target < 0 || target === root.dragIndex)
            return;

        const item = root.itemAtIndex(target);
        if (!item)
            return;

        const mid = item.mapToItem(content, 0, 0).y + item.height / 2;
        if (root.dragIndex < target ? y < mid : y > mid)
            return;

        rows.move(root.dragIndex, target, 1);
        root.dragIndex = target;
    }

    function release(): void {
        if (root.dragIndex < 0)
            return;

        const item = root.itemAtIndex(root.dragIndex);
        root.landingY = item ? item.y : 0;
        root.landing = true;
        landAnim.start();
    }

    Layout.fillWidth: true
    Layout.preferredHeight: contentHeight
    interactive: false
    clip: false
    spacing: Tokens.spacing.extraSmall / 2
    model: rows

    Component.onCompleted: root.sync()

    onEntriesChanged: root.sync()

    move: Transition {
        Anim {
            properties: "x,y"
            type: Anim.FastSpatial
        }
    }

    displaced: Transition {
        Anim {
            properties: "x,y"
            type: Anim.FastSpatial
        }
    }

    ListModel {
        id: rows
    }

    Anim {
        id: landAnim

        target: root
        property: "dragTop"
        to: root.landingY
        type: Anim.FastSpatial
        onStopped: {
            if (!root.landing)
                return;

            root.landing = false;
            const keys = [];
            for (let i = 0; i < rows.count; i++)
                keys.push(rows.get(i).trayKey);
            root.dragIndex = -1;
            root.grabDy = 0;
            root.dragTop = 0;
            root.moved(keys);
        }
    }
}