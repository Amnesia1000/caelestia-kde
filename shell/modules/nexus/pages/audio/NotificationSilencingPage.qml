pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    /// The two per-app policies, side by side because they answer different questions:
    /// one app sends nothing at all, the other still sends, quietly.
    readonly property var sections: [
        {
            kind: "muted",
            title: qsTr("Notifications turned off"),
            description: qsTr("Nothing arrives from these applications: no banner, no sound, and nothing added to the notification list."),
            apps: GlobalConfig.notifs.mutedApps
        },
        {
            kind: "silent",
            title: qsTr("Notifications without sound"),
            description: qsTr("These applications still show their notifications. Only the sound is skipped."),
            apps: GlobalConfig.audio.sounds.disabledNotifApps
        }
    ]

    function appsFor(kind: string): var {
        return kind === "muted" ? GlobalConfig.notifs.mutedApps : GlobalConfig.audio.sounds.disabledNotifApps;
    }

    function setApps(kind: string, apps: var): void {
        if (kind === "muted")
            GlobalConfig.notifs.mutedApps = apps;
        else
            GlobalConfig.audio.sounds.disabledNotifApps = apps;
        GlobalConfig.save();
    }

    function add(kind: string, name: string): void {
        const wanted = name.trim();
        if (wanted === "")
            return;

        const apps = Array.from(root.appsFor(kind));
        if (!apps.includes(wanted))
            apps.push(wanted);
        root.setApps(kind, apps);
    }

    function remove(kind: string, name: string): void {
        root.setApps(kind, Array.from(root.appsFor(kind)).filter(app => app !== name));
    }

    title: qsTr("Muted apps")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Repeater {
            model: root.sections

            delegate: ColumnLayout {
                id: section

                required property var modelData
                required property int index

                readonly property string kind: section.modelData.kind
                readonly property var apps: section.modelData.apps

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    first: section.index === 0
                    text: section.modelData.title
                }

                ConnectedRect {
                    Layout.fillWidth: true
                    first: true
                    implicitHeight: helper.implicitHeight + Tokens.padding.medium * 2

                    StyledText {
                        id: helper

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        text: section.modelData.description
                        color: Colours.palette.m3onSurfaceVariant
                        font: NexusStyle.secondaryFont
                        wrapMode: Text.Wrap
                    }
                }

                AppPickerRow {
                    last: true
                    icon: "add"
                    label: qsTr("Add an application")
                    status: section.kind === "muted" ? qsTr("Turn its notifications off completely") : qsTr("Keep its notifications, drop the sound")
                    exclude: Array.from(section.apps)
                    onSelected: name => root.add(section.kind, name)
                }

                Flow {
                    Layout.fillWidth: true
                    visible: section.apps.length > 0
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: section.apps

                        delegate: RemovableChip {
                            required property string modelData

                            label: modelData
                            onRemoved: root.remove(section.kind, modelData)
                        }
                    }
                }
            }
        }
    }
}
