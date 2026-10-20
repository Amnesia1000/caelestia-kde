import QtQuick

QtObject {
    property string text: ""
    property string icon
    property string trailingIcon
    property string activeIcon: icon
    property string activeText: text
    property bool visible: true
    // Entries of a nested menu: when there are any, the row unfolds them beside
    // the menu instead of running an action of its own.
    property var submenu: []
    property var value

    signal clicked
}
