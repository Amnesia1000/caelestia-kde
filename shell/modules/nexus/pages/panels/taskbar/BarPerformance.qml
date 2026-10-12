pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> pillItems: [MenuItem {
        text: qsTr("CPU")
    }, MenuItem {
        text: qsTr("GPU")
    }, MenuItem {
        text: qsTr("Memory")
    }, MenuItem {
        text: qsTr("Storage")
    }, MenuItem {
        text: qsTr("Network")
    }, MenuItem {
        text: qsTr("Battery")
    }, MenuItem {
        text: qsTr("Icon only")
    }]
    readonly property list<string> pillValues: ["cpu", "gpu", "memory", "storage", "network", "battery", ""]
    readonly property string pill: String(Config.bar.performance?.pill ?? "").trim().toLowerCase()
    readonly property int pillIndex: Math.max(0, root.pillValues.indexOf(root.pill))
    readonly property list<MenuItem> styleItems: [MenuItem {
        text: qsTr("Classic")
    }, MenuItem {
        text: qsTr("Compact")
    }]
    readonly property list<string> styleValues: ["classic", "compact"]
    readonly property string pillStyle: String(Config.bar.performance?.pillStyle ?? "classic").trim().toLowerCase()
    readonly property int styleIndex: Math.max(0, root.styleValues.indexOf(root.pillStyle))

    title: qsTr("Performance")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Widget")
        }

        SelectRow {
            first: true
            label: qsTr("Pill")
            subtext: qsTr("Stat shown in the bar, the full data is in the popout")
            menuItems: root.pillItems
            active: root.pillItems[root.pillIndex]
            onSelected: item => {
                GlobalConfig.bar.performance.pill = root.pillValues[root.pillItems.indexOf(item)];
                GlobalConfig.save();
            }
        }

        SelectRow {
            label: qsTr("Pill style")
            subtext: qsTr("Classic keeps the current pills, compact is smaller with rounded corners")
            menuItems: root.styleItems
            active: root.styleItems[root.styleIndex]
            onSelected: item => {
                GlobalConfig.bar.performance.pillStyle = root.styleValues[root.styleItems.indexOf(item)];
                GlobalConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Show values")
            subtext: qsTr("Show the value next to the icon in each pill")
            reset: ({ node: GlobalConfig.bar.performance, setting: "showText" })
            checked: Config.bar.performance.showText
            onToggled: {
                GlobalConfig.bar.performance.showText = checked;
                GlobalConfig.save();
            }
        }
    }
}
