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

    readonly property var schedules: GlobalConfig.notifs.focusSchedules.values ?? []
    readonly property var allowlist: GlobalConfig.notifs.focusAllowlist ?? []
    readonly property var weekDays: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    property list<string> draftDays: []

    readonly property bool canAdd: nameField.field.text.trim() !== "" && Focus.parseTime(startField.field.text) >= 0 && Focus.parseTime(endField.field.text) >= 0

    function toggleDraftDay(day: string): void {
        const days = Array.from(root.draftDays);
        const index = days.indexOf(day);
        if (index >= 0)
            days.splice(index, 1);
        else
            days.push(day);
        root.draftDays = days;
    }

    function addSchedule(): void {
        if (!root.canAdd)
            return;

        GlobalConfig.notifs.focusSchedules.insert({
            name: nameField.field.text.trim(),
            days: Array.from(root.draftDays),
            start: startField.field.text.trim(),
            end: endField.field.text.trim()
        });
        GlobalConfig.save();

        nameField.clear();
        startField.clear();
        endField.clear();
        root.draftDays = [];
    }

    function removeSchedule(index: int): void {
        GlobalConfig.notifs.focusSchedules.remove(index);
        GlobalConfig.save();
    }

    function daySummary(schedule: var): string {
        const days = schedule.days ?? [];
        if (days.length === 0)
            return qsTr("Every day");
        if (days.length === 7)
            return qsTr("Every day");

        return days.join(", ");
    }

    function statusText(): string {
        if (!GlobalConfig.notifs.focusEnabled)
            return qsTr("Focus sessions are off");
        if (Focus.active)
            return qsTr("%1 until %2").arg(Focus.activeName || qsTr("Focus")).arg(Focus.activeEnd());

        return qsTr("No session running now");
    }

    function addAllowedApp(): void {
        const appName = allowInput.text.trim();
        if (appName === "" || root.allowlist.includes(appName))
            return;

        const apps = Array.from(root.allowlist);
        apps.push(appName);
        GlobalConfig.notifs.focusAllowlist = apps;
        GlobalConfig.save();
        allowInput.text = "";
    }

    function removeAllowedApp(appName: string): void {
        const apps = Array.from(root.allowlist).filter(name => name !== appName);
        GlobalConfig.notifs.focusAllowlist = apps;
        GlobalConfig.save();
    }

    title: qsTr("Focus sessions")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Focus")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Focus sessions")
            subtext: qsTr("Turn notifications off by themselves on a schedule")
            checked: GlobalConfig.notifs.focusEnabled
            onToggled: {
                GlobalConfig.notifs.focusEnabled = checked;
                GlobalConfig.save();
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: focusStatus.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: focusStatus

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: Focus.active ? "do_not_disturb_on" : "do_not_disturb"
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText()
                    color: Focus.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    font: NexusStyle.secondaryFont
                    elide: Text.ElideRight
                }
            }
        }

        SectionHeader {
            text: qsTr("Schedules")
        }

        Repeater {
            model: root.schedules

            delegate: ConnectedRect {
                id: scheduleRow

                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0 && root.schedules.length > 0
                implicitHeight: scheduleLayout.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: scheduleLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: scheduleRow.modelData.name || qsTr("Focus")
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${root.daySummary(scheduleRow.modelData)} · ${scheduleRow.modelData.start}–${scheduleRow.modelData.end}`
                            color: Colours.palette.m3onSurfaceVariant
                            font: NexusStyle.secondaryFont
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        font: Tokens.font.icon.small
                        onClicked: root.removeSchedule(scheduleRow.index)
                    }
                }
            }
        }

        TextFieldRow {
            id: nameField

            first: root.schedules.length === 0
            label: qsTr("Name")
            placeholderText: qsTr("Deep work")
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: dayPicker.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: dayPicker

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Days")
                    color: Colours.palette.m3onSurfaceVariant
                    font: NexusStyle.secondaryFont
                }

                Repeater {
                    model: root.weekDays

                    delegate: StyledRect {
                        id: dayChip

                        required property string modelData

                        implicitWidth: dayLabel.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: dayLabel.implicitHeight + Tokens.padding.extraSmall * 2
                        radius: Tokens.rounding.large
                        color: root.draftDays.includes(dayChip.modelData) ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainer, 2)

                        StyledText {
                            id: dayLabel

                            anchors.centerIn: parent
                            text: dayChip.modelData.slice(0, 3)
                            color: root.draftDays.includes(dayChip.modelData) ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            font: NexusStyle.secondaryFont
                        }

                        StateLayer {
                            onClicked: root.toggleDraftDay(dayChip.modelData)
                        }
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: addRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: addRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("From")
                    color: Colours.palette.m3onSurfaceVariant
                    font: NexusStyle.secondaryFont
                }

                StyledInputField {
                    id: startField

                    text: "09:00"
                    implicitWidth: 70
                }

                StyledText {
                    text: qsTr("to")
                    color: Colours.palette.m3onSurfaceVariant
                    font: NexusStyle.secondaryFont
                }

                StyledInputField {
                    id: endField

                    text: "17:00"
                    implicitWidth: 70
                }

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    text: qsTr("Add")
                    type: root.canAdd ? TextButton.Filled : TextButton.Tonal
                    enabled: root.canAdd
                    onClicked: root.addSchedule()
                }
            }
        }

        SectionHeader {
            text: qsTr("Allowed through")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            implicitHeight: allowHelper.implicitHeight + Tokens.padding.medium * 2

            StyledText {
                id: allowHelper

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                text: qsTr("Notifications from these apps still pop up during a focus session. Names have to match the application name the notification carries.")
                color: Colours.palette.m3onSurfaceVariant
                font: NexusStyle.secondaryFont
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledInputField {
                id: allowInput

                Layout.fillWidth: true
                onEditingFinished: root.addAllowedApp()
            }

            TextButton {
                text: qsTr("Add")
                enabled: allowInput.text.trim() !== ""
                onClicked: root.addAllowedApp()
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.allowlist

                delegate: StyledRect {
                    id: allowChip

                    required property string modelData

                    width: implicitWidth
                    height: implicitHeight
                    implicitWidth: chipLayout.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: chipLayout.implicitHeight + Tokens.padding.extraSmall * 2
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    radius: Tokens.rounding.large

                    RowLayout {
                        id: chipLayout

                        x: Tokens.padding.medium
                        y: Tokens.padding.extraSmall
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            text: allowChip.modelData
                        }

                        MaterialIcon {
                            text: "close"
                            font: Tokens.font.icon.small

                            StateLayer {
                                onClicked: root.removeAllowedApp(allowChip.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
