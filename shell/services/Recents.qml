pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/// The documents an application opened recently, for the dock's jump list.
///
/// Parsing `recently-used.xbel` belongs to `scripts/recents.py`. `load()` takes the
/// names the caller knows the application by, because a desktop entry id, an app class
/// and the name the file records are rarely spelled the same way.
Singleton {
    id: root

    property var entries: []
    property bool loaded: false

    function load(apps: list<string>): void {
        root.entries = [];
        root.loaded = false;
        readProcess.command = ["python3", Quickshell.shellPath("scripts/recents.py"), "--limit", "5"];
        for (const app of apps)
            readProcess.command.push("--app", app);
        readProcess.running = false;
        readProcess.running = true;
    }

    Process {
        id: readProcess

        stdout: StdioCollector {
            id: readOutput

            onStreamFinished: {
                try {
                    root.entries = JSON.parse(readOutput.text);
                } catch (error) {
                    root.entries = [];
                }
                root.loaded = true;
            }
        }
    }
}
