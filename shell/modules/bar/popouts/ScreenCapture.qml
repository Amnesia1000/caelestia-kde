pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import "../../utilities/cards"
import qs.services
import qs.modules.nexus

// Screen capture popout: the utilities card, reused as is.
ColumnLayout {
    id: root

    required property var popouts
    required property DrawerVisibilities visibilities

    width: Math.max(360, captureView.implicitWidth)
    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Screen Capture")
            font: Tokens.font.body.medium
        }

        IconButton {
            icon: "tune"
            type: IconButton.Text
            onClicked: {
                root.popouts.hasCurrent = false;
                WindowFactory.create(null, {
                    initialPageIdx: PageRegistry.indexForKey("panels"),
                    initialSubPageIdx: 22
                });
            }
        }
    }

    CaptureCard {
        id: captureView

        Layout.fillWidth: true
        visibilities: root.visibilities
        props: cardProps
    }

    PersistentProperties {
        id: cardProps

        property string captureMode: "shot"
        property string recordingMode
    }
}
