pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

VerticalFadeListView {
    id: root

    required property NexusState nState
    readonly property string normalizedQuery: root.nState.searchQuery.trim().toLowerCase()

    function moveUp(): void {
        if (count === 0) return;
        currentIndex = Math.max(0, currentIndex - 1);
        positionViewAtIndex(currentIndex, ListView.Contain);
    }

    function moveDown(): void {
        if (count === 0) return;
        currentIndex = Math.min(count - 1, currentIndex + 1);
        positionViewAtIndex(currentIndex, ListView.Contain);
    }

    function executeSelected(): void {
        if (count > 0 && currentIndex >= 0 && currentIndex < count) {
            const entry = model[currentIndex];
            root.nState.goToSubPage(entry.pageIdx, entry.subPageIdx);
            root.nState.searchQuery = "";
        }
    }

    model: PageRegistry.fuzzyEntries(root.normalizedQuery)
    currentIndex: 0

    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.large
    spacing: Tokens.spacing.extraSmall
    clip: true
    reuseItems: true

    focus: true

    onNormalizedQueryChanged: currentIndex = 0

    Keys.onUpPressed: moveUp()
    Keys.onDownPressed: moveDown()
    Keys.onReturnPressed: executeSelected()

    delegate: StyledRect {
        id: item

        required property var modelData
        required property int index

        readonly property string settingLabel: modelData.settingLabel
        readonly property string pageLabel: modelData.pageLabel
        readonly property string pageIcon: modelData.pageIcon
        readonly property int pageIdx: modelData.pageIdx
        readonly property int subPageIdx: modelData.subPageIdx

        readonly property bool isSelected: index === root.currentIndex

        width: root.width
        implicitHeight: {
            const h = layout.implicitHeight + layout.anchors.margins * 2;
            return h % 2 === 0 ? h : h + 1;
        }

        color: isSelected ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
        radius: Tokens.rounding.extraSmall

        StateLayer {
            id: stateLayer

            anchors.fill: parent
            radius: parent.radius

            onClicked: {
                root.currentIndex = item.index;
                root.nState.goToSubPage(item.pageIdx, item.subPageIdx);
                root.nState.searchQuery = "";
            }
        }

        RowLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.fillHeight: true
                Layout.topMargin: -1
                Layout.bottomMargin: -1
                implicitWidth: height

                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Centering.pixelAlign(parent.height, height)

                    text: item.pageIcon
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                    grade: 25
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: item.settingLabel
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("in ") + item.pageLabel
                    color: Colours.palette.m3onSurfaceVariant
                    font: NexusStyle.secondaryFont
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                text: "chevron_right"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }
        }
    }
}
