pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Spotify")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Configuration")
        }

        ToggleRow {
            first: true
            text: qsTr("Background")
            subtext: qsTr("Render a solid background behind the widget")
            checked: Config.bar.spotify.background
            onToggled: {
                GlobalConfig.bar.spotify.background = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show visualiser")
            subtext: qsTr("Display animated frequency bars next to the title")
            checked: Config.bar.spotify.showVisualiser
            onToggled: {
                GlobalConfig.bar.spotify.showVisualiser = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Inverted text direction")
            subtext: qsTr("Rotate the title the opposite way when the bar is vertical")
            checked: Config.bar.spotify.inverted
            onToggled: {
                GlobalConfig.bar.spotify.inverted = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Auto-hide")
            subtext: qsTr("Hide the widget when no media source is available")
            checked: Config.bar.spotify.autoHide
            onToggled: {
                GlobalConfig.bar.spotify.autoHide = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Horizontal volume slider")
            subtext: qsTr("Place the volume slider below the controls in the popout")
            checked: Config.bar.spotify.horizontalVolume
            onToggled: {
                GlobalConfig.bar.spotify.horizontalVolume = checked;
                GlobalConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Widget")
        }

        StepperRow {
            first: true
            last: true
            label: qsTr("Max title length")
            subtext: qsTr("Character count before the track title is cut off")
            value: Config.bar.spotify.maxTitleLength
            from: 5
            to: 100
            stepSize: 1
            onMoved: v => {
                GlobalConfig.bar.spotify.maxTitleLength = Math.round(v);
                GlobalConfig.save();
            }
        }
    }
}
