pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.Services.QuickShare
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

    opacity: root.props.quickShareConfirmDeletePath ? 1 : 0
    active: opacity > 0

    sourceComponent: DrawerModal {
        // The props are cleared as soon as the modal is dismissed, but the card keeps
        // naming the file while it fades out. The entry is named by its path and time
        // rather than by a position the transfer list can shift.
        property string path
        property real timestamp

        function clearConfirmation(): void {
            root.props.quickShareConfirmDeletePath = "";
            root.props.quickShareConfirmDeleteTimestamp = 0;
        }

        deformMatrix: root.deformMatrix
        open: root.props.quickShareConfirmDeletePath !== ""
        onDismissed: clearConfirmation()

        Component.onCompleted: {
            path = root.props.quickShareConfirmDeletePath;
            timestamp = root.props.quickShareConfirmDeleteTimestamp;
        }

        StyledText {
            text: qsTr("Delete file?")
            font: Tokens.font.body.large
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("'%1' will be permanently deleted.").arg(path)
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
                onClicked: clearConfirmation()
            }

            TextButton {
                text: qsTr("Delete")
                type: TextButton.Text
                onClicked: {
                    if (path !== "") {
                        CUtils.deleteFile(Qt.resolvedUrl(path));
                        QuickShareService.removeHistoryEntry(path, timestamp);
                    }
                    clearConfirmation();
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
