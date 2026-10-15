pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import "../../utilities/cards"
import qs.services
import qs.modules.nexus

// Keep awake popout: the utilities card, reused as is.
ColumnLayout {
    id: root

    required property var popouts

    width: Math.max(360, keepAwakeView.implicitWidth)
    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Keep Awake")
            font: Tokens.font.body.medium
        }

        IconButton {
            icon: "tune"
            type: IconButton.Text
            onClicked: {
                root.popouts.hasCurrent = false;
                WindowFactory.create(null, {
                    initialPageIdx: PageRegistry.indexForKey("panels"),
                    initialSubPageIdx: 23
                });
            }
        }
    }

    IdleInhibit {
        id: keepAwakeView

        Layout.fillWidth: true
    }
}
