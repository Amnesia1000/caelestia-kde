pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    function addApp() {
        const appName = appInput.text.trim();
        if (appName === "")
            return;

        const mutedApps = Array.from(GlobalConfig.audio.sounds.disabledNotifApps);
        if (!mutedApps.includes(appName)) {
            mutedApps.push(appName);
            GlobalConfig.audio.sounds.disabledNotifApps = mutedApps;
            GlobalConfig.save();
        }
        appInput.text = "";
    }

    title: qsTr("Muted notification apps")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Muted apps")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledInputField {
                id: appInput

                Layout.fillWidth: true
                onEditingFinished: root.addApp()
            }

            IconTextButton {
                text: qsTr("Add")
                icon: "add"
                onClicked: root.addApp()
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: GlobalConfig.audio.sounds.disabledNotifApps

                delegate: RemovableChip {
                    required property string modelData

                    label: modelData
                    onRemoved: {
                        const mutedApps = Array.from(GlobalConfig.audio.sounds.disabledNotifApps);
                        mutedApps.splice(mutedApps.indexOf(modelData), 1);
                        GlobalConfig.audio.sounds.disabledNotifApps = mutedApps;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
