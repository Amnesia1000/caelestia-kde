pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

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

        TextFieldRow {
            first: true
            label: qsTr("Pills")
            subtext: qsTr("Stats shown in the bar, comma-separated: cpu, gpu, memory, storage, network, battery. Empty shows a single icon")
            value: (Config.bar.performance.pills || []).join(", ")
            onEditingFinished: value => {
                GlobalConfig.bar.performance.pills = value.split(",").map(s => s.trim().toLowerCase()).filter(s => s.length > 0);
                GlobalConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Show values")
            subtext: qsTr("Show the value next to the icon in each pill")
            checked: Config.bar.performance.showText
            onToggled: {
                GlobalConfig.bar.performance.showText = checked;
                GlobalConfig.save();
            }
        }
    }
}
