import "cards"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property var props
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property matrix4x4 deformMatrix

    readonly property int visibleCards: [idleInhibit, capture, quickShare, toggles].filter(card => card.visible).length
    readonly property real nonAnimHeight: (idleInhibit.visible ? idleInhibit.nonAnimHeight : 0) + (capture.visible ? capture.nonAnimHeight : 0) + (quickShare.visible ? quickShare.nonAnimHeight : 0) + (toggles.visible ? toggles.implicitHeight : 0) + layout.spacing * Math.max(0, root.visibleCards - 1)

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        IdleInhibit {
            id: idleInhibit

            visible: Config.utilities.showKeepAwake
        }

        CaptureCard {
            id: capture

            visible: Config.utilities.showScreenRecorder

            props: root.props
            visibilities: root.visibilities
            z: 1
        }

        QuickShareList {
            id: quickShare

            visible: Config.utilities.showQuickShare && QuickShare.isEnabled

            props: root.props
            visibilities: root.visibilities
        }

        Toggles {
            id: toggles

            visible: Config.utilities.showQuickToggles

            visibilities: root.visibilities
            popouts: root.popouts
        }
    }

    RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }

    QuickShareDeviceSelector {
        props: root.props
        deformMatrix: root.deformMatrix
    }

    QuickShareDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }
}
