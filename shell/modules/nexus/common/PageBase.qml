pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus

ColumnLayout {
    id: root

    readonly property bool isPageBase: true
    required property string title
    required property NexusState nState
    property bool isSubPage
    property bool scrollable: true
    property bool showTitle: true
    readonly property int cappedWidth: Math.min(Tokens.sizes.nexus.maxContentWidth, width)
    readonly property alias flickable: flickable
    property list<Item> headerActions

    default property Item contentChild

    spacing: root.showTitle ? Tokens.spacing.extraSmall : Tokens.spacing.medium

    Item {
        id: headerBand

        z: 1
        visible: true
        implicitWidth: header.implicitWidth
        implicitHeight: 46
        Layout.preferredHeight: 46
        Layout.fillWidth: true

        RowLayout {
            id: header

            anchors.fill: parent
            spacing: Tokens.spacing.largeIncreased

            Loader {
                visible: active
                active: root.isSubPage && root.nState.subPageIdxStack.length > 0
                asynchronous: true
                sourceComponent: IconButton {
                    icon: "arrow_back"
                    font: Tokens.font.icon.medium
                    type: IconButton.Tonal
                    isRound: true
                    inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant
                    onClicked: root.nState.closeSubPage()
                }
            }

            StyledText {
                visible: root.showTitle && root.title.length > 0
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.title
                font: Tokens.font.title.large
                elide: Text.ElideRight
            }

            Item {
                visible: !root.showTitle || root.title.length === 0
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.small
                children: root.headerActions
            }
        }
    }

    VerticalFadeFlickable {
        id: flickable

        interactive: root.scrollable
        Layout.fillWidth: true
        Layout.fillHeight: true

        topMargin: 0
        bottomMargin: Tokens.padding.large

        contentHeight: root.scrollable ? (root.contentChild?.implicitHeight ?? 0) : height
        contentItem.children: [root.contentChild]
    }
}
