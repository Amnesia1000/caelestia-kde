pragma Singleton

import QtQuick
import Caelestia.Config

/// The bar panels live in one list, so every place that adds or removes one has to agree on
/// which edges are taken. Both the bar context menu and the Nexus page go through here.
Singleton {
    id: root

    readonly property list<string> edges: ["top", "bottom", "left", "right"]

    function edgesInUse(): var {
        const used = [Config.bar.position];

        for (let i = 0; i < GlobalConfig.bar.panels.count; ++i) {
            const panel = GlobalConfig.bar.panels.at(i);

            if (panel)
                used.push(panel.position);
        }

        return used;
    }
    function freeEdges(keep: string): var {
        const used = root.edgesInUse();

        return root.edges.filter(edge => edge === keep || used.indexOf(edge) === -1);
    }
    function addPanel(position: string): void {
        GlobalConfig.bar.panels.insert({
            name: qsTr("Bar %1").arg(GlobalConfig.bar.panels.count + 2),
            position: position,
            lengthPercent: 100,
            align: "center",
            persistent: true,
            showOnHover: true,
            screens: [],
            entries: []
        });
    }
    function removePanel(index: int): void {
        if (index < 0 || index >= GlobalConfig.bar.panels.count)
            return;

        GlobalConfig.bar.panels.remove(index);
    }
}
