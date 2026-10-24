pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/// The proxy KDE applications use, as `kioslaverc` holds it.
///
/// Reading and writing belongs to `scripts/proxy.py`: the file has other sections and
/// comments that a parser would throw away, and environment variables would only reach
/// programs started after the change.
Singleton {
    id: root

    readonly property string selfAppName: "caelestia-shell"

    property var settings: ({})
    property bool loaded: false

    function refresh(): void {
        if (readProcess.running)
            return;
        readProcess.running = true;
    }

    function setMode(mode: string): void {
        root.run(["--set-mode", mode]);
    }

    function set(key: string, value: string): void {
        root.run(["--set", key, value]);
    }

    function run(args: list<string>): void {
        editProcess.command = ["python3", Quickshell.shellPath("scripts/proxy.py"), ...args];
        editProcess.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: readProcess

        command: ["python3", Quickshell.shellPath("scripts/proxy.py"), "--get"]

        stdout: StdioCollector {
            id: readOutput

            onStreamFinished: {
                try {
                    root.settings = JSON.parse(readOutput.text);
                } catch (error) {
                    root.settings = {};
                }
                root.loaded = true;
            }
        }
    }

    Process {
        id: editProcess

        onExited: root.refresh()
    }
}
