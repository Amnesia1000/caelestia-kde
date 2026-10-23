pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Services

/// System-wide search through KRunner, for the launcher's search mode. The shell
/// has its own sources for apps, windows, emoji and clipboard; this is what
/// reaches the rest of the system (files, places, web shortcuts, definitions,
/// unit conversion, settings modules).
///
/// Results stream in as runners answer, so `results` grows until `busy` is false.
Singleton {
    id: root

    readonly property bool available: KRunnerBridge.available
    readonly property bool busy: KRunnerBridge.busy
    readonly property var results: KRunnerBridge.results

    function search(text: string): void {
        if (!root.available)
            return;

        if (!text || !text.trim()) {
            KRunnerBridge.clear();
            return;
        }

        KRunnerBridge.search(text);
    }

    function clear(): void {
        if (root.available)
            KRunnerBridge.clear();
    }

    function run(index: int, actionId: string): void {
        KRunnerBridge.run(index, actionId ?? "");
    }
}
