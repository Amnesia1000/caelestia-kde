pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.utils

Item {
    id: root

    readonly property int status: loader.item?.status ?? Image.Null // qmllint disable missing-property
    readonly property real actualSize: Math.min(width, height)
    property real implicitSize
    property url source

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Loader {
        id: loader

        active: root.source.toString() !== "" && root.width > 0 && root.height > 0
        asynchronous: true
        anchors.fill: parent
        sourceComponent: root.source.toString().startsWith("image://icon/") ? iconImage : cachingImage
    }

    Component {
        id: cachingImage

        CachingImage {
            path: Paths.toLocalFile(root.source)
            fillMode: Image.PreserveAspectFit
        }
    }

    Component {
        id: iconImage

        IconImage {
            source: root.source
            asynchronous: true
        }
    }
}
