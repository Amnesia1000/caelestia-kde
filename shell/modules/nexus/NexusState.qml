import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    property ShellScreen screen
    property bool isWindow
    property bool animatingContainer
    property int currentPageIdx
    property list<int> subPageIdxStack
    property bool searchOpen
    property string searchQuery

    property string selectedWallpaperCategory
    property BluetoothDevice selectedBtDevice
    property DesktopEntry selectedApp
    property int editingVpnIndex: -1
    property string selectedNetworkSsid
    property string selectedNetworkUuid
    property string selectedEthernetInterface
    property bool networkDetailsFromSaved

    property string pendingNetworkSsid: ""

    property int pendingSubPageIdx: -1

    // Which bar the components page edits: -1 is the main bar, anything else
    // indexes `bar.panels`.
    property int barComponentsTarget: -1

    // Set when the editor was opened straight from a bar's context menu: its
    // Back button then goes to the extra bars list, which is not stacked under
    // it, instead of the main panels page.
    property bool backToExtraBars: false

    signal close
    signal subPageOpened(idx: int)
    signal subPageClosed

    function openSubPage(idx: int): void {
        subPageIdxStack.push(idx);
        subPageOpened(idx);
    }

    // Navigation that changes page, such as a search result. Landing on the
    // page that is already showing still opens immediately: nothing to wait for.
    function goToSubPage(pageIdx: int, subPageIdx: int): void {
        if (pageIdx === currentPageIdx) {
            pendingSubPageIdx = -1;
            if (subPageIdx >= 0)
                openSubPage(subPageIdx);
            return;
        }
        currentPageIdx = pageIdx;
        pendingSubPageIdx = subPageIdx;
    }

    function closeSubPage(): void {
        subPageClosed();
        subPageIdxStack.pop();
    }

    function openNetworkDetail(ssid: string, uuid: string, fromSaved: bool): void {
        selectedNetworkSsid = ssid;
        selectedNetworkUuid = uuid;
        networkDetailsFromSaved = fromSaved;
        openSubPage(3);
    }

    onCurrentPageIdxChanged: {
        subPageIdxStack.length = 0;
        pendingSubPageIdx = -1;
        barComponentsTarget = -1;
        backToExtraBars = false;
    }
}
