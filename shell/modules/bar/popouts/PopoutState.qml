import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    // True while the open popout was triggered from a top overlay panel,
    // so it drops downward instead of rising from the primary bar.
    property bool fromTopPanel: false
    property var dockModel: null
    property var tasksModel: null
    property string selectedClientAddress: ""
    property bool sidebarOpen: false
    property bool isHorizontal: true

    signal detachRequested(mode: string)
}
