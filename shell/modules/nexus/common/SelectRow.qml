import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property string icon
    property alias menuItems: splitButton.menuItems
    property alias active: splitButton.active
    property alias fallbackText: splitButton.fallbackText
    property alias fallbackIcon: splitButton.fallbackIcon
    property alias menuOnTop: splitButton.menuOnTop
    property bool highlight: false

    signal selected(item: MenuItem)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2
    clip: false
    z: (splitButton.expanded || root.highlight) ? 1 : 0
    color: root.highlight ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer

    Behavior on color {
        ColorAnimation {
            duration: Tokens.anim.durations.expressiveFastEffects
            easing: Tokens.anim.expressiveFastEffects
        }
    }

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        Loader {
            Layout.alignment: Qt.AlignVCenter
            active: !!root.icon
            visible: active

            sourceComponent: IconImage {
                implicitSize: Tokens.font.icon.large.pointSize * 1.5
                source: root.icon
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3onSurfaceVariant
                font: NexusStyle.secondaryFont
                elide: Text.ElideRight
            }
        }

        SplitButton {
            id: splitButton

            type: SplitButton.Tonal
            stateLayer.onClicked: splitButton.expanded = !splitButton.expanded
            menu.onItemSelected: item => root.selected(item)
        }
    }
}
