import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    readonly property real nonAnimHeight: content.implicitHeight + Tokens.padding.large * 2

    function begin(seconds: int): void {
        if (seconds <= 0)
            return;

        Timers.start(seconds, messageField.text);
        durationField.text = "";
        messageField.text = "";
    }

    Layout.fillWidth: true
    implicitHeight: nonAnimHeight
    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    ColumnLayout {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Tokens.padding.large

                radius: Tokens.rounding.full
                color: Timers.count > 0 ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: "timer"
                    color: Timers.count > 0 ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Timers")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Timers.count === 0 ? qsTr("Nothing running") : qsTr("%1 running").arg(Timers.count)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }

        Repeater {
            model: [...Timers.list]

            delegate: StyledRect {
                id: timerRow

                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: timerLayout.implicitHeight + Tokens.padding.small * 2

                radius: Tokens.rounding.medium
                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                RowLayout {
                    id: timerLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: Units.formatDuration(Timers.remaining(timerRow.modelData))
                        font: Tokens.font.title.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: timerRow.modelData.message || qsTr("Timer")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "close"
                        onClicked: Timers.cancel(timerRow.modelData.id)
                        Accessible.name: qsTr("Cancel this timer")
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Timers.count > 0 ? Tokens.spacing.extraSmall : 0
            spacing: Tokens.spacing.small

            StyledInputField {
                id: durationField

                Layout.preferredWidth: 84
                placeholderText: qsTr("25m")
                onEditingFinished: root.begin(Timers.parseDuration(text))
            }

            StyledInputField {
                id: messageField

                Layout.fillWidth: true
                horizontalAlignment: TextInput.AlignLeft
                placeholderText: qsTr("What is it for?")
                onEditingFinished: root.begin(Timers.parseDuration(durationField.text))
            }

            IconButton {
                icon: "play_arrow"
                enabled: Timers.parseDuration(durationField.text) > 0
                onClicked: root.begin(Timers.parseDuration(durationField.text))
                Accessible.name: qsTr("Start the timer")
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: [5, 10, 25, 45]

                delegate: TextButton {
                    required property int modelData

                    text: qsTr("%1m").arg(modelData)
                    type: TextButton.Tonal
                    onClicked: root.begin(modelData * 60)
                }
            }
        }
    }
}
