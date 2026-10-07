pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Loader {
    id: root

    required property var props
    required property matrix4x4 deformMatrix

    asynchronous: true
    anchors.fill: parent

    opacity: root.props.recordingConfirmDelete ? 1 : 0
    active: opacity > 0

    sourceComponent: DrawerModal {
        // The prop is cleared as soon as the modal is dismissed, but the card keeps
        // naming the recording while it fades out.
        property string path

        deformMatrix: root.deformMatrix
        open: root.props.recordingConfirmDelete !== ""
        onDismissed: root.props.recordingConfirmDelete = ""

        Component.onCompleted: path = root.props.recordingConfirmDelete

        StyledText {
            text: qsTr("Delete recording?")
            font: Tokens.font.body.large
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Recording '%1' will be permanently deleted.").arg(path)
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
                onClicked: root.props.recordingConfirmDelete = ""
            }

            TextButton {
                text: qsTr("Delete")
                type: TextButton.Text
                onClicked: {
                    CUtils.deleteFile(Qt.resolvedUrl(path));
                    root.props.recordingConfirmDelete = "";
                }
            }
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
