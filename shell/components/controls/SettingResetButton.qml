pragma ComponentBehavior: Bound

import QtQuick
import qs.components.controls

IconButton {
    id: root

    property var options

    readonly property bool active: root.options !== null && root.options !== undefined

    visible: root.active && root.options.node.overrides.includes(root.options.setting)
    icon: "restart_alt"
    type: IconButton.Text
    onClicked: root.options.node.resetOption(root.options.setting)
}
