pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    /// Filesystems grouped by the disk they sit on, because that is what ejecting acts
    /// on: udisks powers a disk off, never a partition.
    readonly property var groups: {
        const result = [];
        for (const entry of Disks.entries) {
            let group = result.find(candidate => candidate.disk === entry.disk);
            if (!group) {
                group = { disk: entry.disk, model: entry.model, removable: entry.removable, mounted: 0, entries: [] };
                result.push(group);
            }
            if (entry.mounted)
                group.mounted += 1;
            group.entries.push(entry);
        }
        return result;
    }

    function groupTitle(group: var): string {
        const name = group.model || group.disk.replace("/dev/", "");
        return group.removable ? qsTr("%1 (removable)").arg(name) : name;
    }

    function entryTitle(entry: var): string {
        return entry.label || entry.device;
    }

    function entryStatus(entry: var): string {
        const parts = entry.label ? [entry.device] : [];
        parts.push(entry.fstype.toUpperCase(), entry.size);
        if (entry.use)
            parts.push(qsTr("%1 used").arg(entry.use));
        if (entry.readOnly)
            parts.push(qsTr("read-only"));
        if (entry.mountpoints.length > 0)
            parts.push(entry.mountpoints.join(", "));
        return parts.join(" · ");
    }

    title: qsTr("Storage")

    // A stick can be plugged in while the page is open, so the list is re-read every
    // time the page is shown instead of trusting what was read last time.
    Component.onCompleted: Disks.refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            visible: Disks.lastError !== ""
            text: Disks.lastError
            color: Colours.palette.m3error
            font: NexusStyle.secondaryFont
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: Disks.loaded && root.groups.length === 0
            text: qsTr("No filesystems were reported by lsblk.")
            color: Colours.palette.m3onSurfaceVariant
            font: NexusStyle.secondaryFont
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.groups

            delegate: ColumnLayout {
                id: diskSection

                required property var modelData
                required property int index

                readonly property var group: diskSection.modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    first: diskSection.index === 0
                    text: root.groupTitle(diskSection.group)
                }

                Repeater {
                    model: diskSection.group.entries

                    delegate: ToggleRow {
                        id: filesystemRow

                        required property var modelData
                        required property int index

                        first: filesystemRow.index === 0
                        text: root.entryTitle(filesystemRow.modelData)
                        subtext: root.entryStatus(filesystemRow.modelData)
                        checked: filesystemRow.modelData.mounted
                        // A filesystem the system is running from is shown, not offered:
                        // unmounting / or /boot is never what the click meant.
                        enabled: !Disks.working && !filesystemRow.modelData.system
                        onToggled: filesystemRow.modelData.mounted ? Disks.unmount(filesystemRow.modelData) : Disks.mount(filesystemRow.modelData)
                    }
                }

                NavRow {
                    visible: diskSection.group.removable
                    last: true
                    icon: "eject"
                    label: qsTr("Eject")
                    status: diskSection.group.mounted > 0 ? qsTr("Unmount everything on this disk first") : qsTr("Power the disk off before unplugging it")
                    onClicked: {
                        if (diskSection.group.mounted === 0)
                            Disks.eject(diskSection.group.entries[0]);
                    }
                }
            }
        }
    }
}
