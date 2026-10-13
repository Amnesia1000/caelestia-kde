pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls

DrawerModal {
    id: root

    required property string title
    required property string message
    required property string confirmText

    signal confirmed()

    StyledText {
        text: root.title
        font: Tokens.font.body.large
    }

    StyledText {
        Layout.fillWidth: true
        text: root.message
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    RowLayout {
        Layout.topMargin: Tokens.spacing.medium
        Layout.alignment: Qt.AlignRight
        spacing: Tokens.spacing.medium

        TextButton {
            text: qsTr("Cancel")
            type: TextButton.Text
            onClicked: root.dismissed()
        }

        TextButton {
            text: root.confirmText
            type: TextButton.Text
            onClicked: {
                root.confirmed();
                root.dismissed();
            }
        }
    }
}
