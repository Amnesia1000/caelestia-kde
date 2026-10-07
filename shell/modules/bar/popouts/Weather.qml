pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.dashboard.dash

// Weather popout reusing the dashboard SmallWeather block.
ColumnLayout {
    id: root

    required property var popouts

    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    width: 280
    spacing: Tokens.spacing.small

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 150

        SmallWeather {
        }
    }
}
