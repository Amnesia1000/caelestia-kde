pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

QtObject {
    readonly property string assetDir: "../../assets/whatsnew/"

    readonly property var list: [
        {
            "id": "shimeji-cat",
            "revision": 62,
            "icon": "pets",
            "title": qsTr("Shimeji Cat update"),
            "settingsPage": "plugins",
            "description": qsTr("Multiple Shimeji Cats can now be summoned at once. Also a fix regarding the cat hiding when clicking desktop has been pushed. Update from plugin store to access new features!")
        },
        {
            "id": "desktop_multimonitor",
            "revision": 63,
            "icon": "desktop_windows",
            "title": qsTr("Multi-Monitor Desktop Support"),
            "description": qsTr("Desktop icons and widgets now fully support multi-monitor setups with screen-aware positioning. Each connected display maintains its own grid layout and arrangement independently, ensuring widgets and icons stay pinned to their designated monitor across display reconnections and resolution changes without overlapping or shifting between screens.")
        },
        {
            "id": "desktop_widget_locking",
            "revision": 64,
            "icon": "lock",
            "title": qsTr("Widget Locking & Outlines"),
            "description": qsTr("Desktop widgets can now be locked individually or altogether directly from their context menus, preventing accidental dragging or resizing while interacting with them. In addition, a new widget outlines toggle highlights widget boundaries on your wallpaper, making it effortless to locate empty or conditionally hidden widgets across your desktop.")
        },
        {
            "id": "desktop_widget_edit_mode",
            "revision": 65,
            "icon": "edit",
            "title": qsTr("Desktop Widget Edit Mode"),
            "description": qsTr("Desktop widgets now have an edit mode of their own. The controls inside a widget step aside, so the whole card can be dragged from anywhere, every border resizes, the cells are outlined underneath, and each card names itself and its size. A toolbar adds widgets, locks or unlocks all of them, and ends the mode. Right-click the desktop and choose Widgets → Edit Widgets to start; Escape leaves it. Ctrl+C and Ctrl+V copy and paste widgets, and Delete removes them without touching your files.")
        }
    ]

    function mediaSource(entry: var): url {
        if (!entry || !entry.mediaUrl)
            return "";
        if (entry.mediaUrl.startsWith("root:"))
            return Qt.resolvedUrl(`${Quickshell.shellDir}${entry.mediaUrl.slice("root:".length)}`);
        return Qt.resolvedUrl(`${assetDir}${entry.mediaUrl}`);
    }
}
