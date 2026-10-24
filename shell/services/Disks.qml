pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/// The filesystems the Storage page can mount, unmount and eject.
///
/// Deciding what is worth showing belongs to `scripts/disks.py`, which reads the same
/// `lsblk` data udisks does. Mounting goes through `udisksctl` rather than mounting
/// ourselves: it is the polkit-checked path, so the answer is a prompt or a refusal
/// instead of a half-mounted filesystem.
Singleton {
    id: root

    property var entries: []
    property bool loaded: false
    property bool working: false
    property string lastError: ""

    function refresh(): void {
        if (listProcess.running)
            return;
        root.working = true;
        listProcess.running = true;
    }

    function mount(entry: var): void {
        root.act(["udisksctl", "mount", "-b", entry.device]);
    }

    function unmount(entry: var): void {
        root.act(["udisksctl", "unmount", "-b", entry.device]);
    }

    /// Ejecting is per disk, not per filesystem: udisks refuses to power a disk off
    /// while anything on it is still mounted, which is the protection worth having.
    function eject(entry: var): void {
        root.act(["udisksctl", "power-off", "-b", entry.disk]);
    }

    function act(command: list<string>): void {
        root.lastError = "";
        root.working = true;
        actionProcess.command = command;
        actionProcess.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: listProcess

        command: ["python3", Quickshell.shellPath("scripts/disks.py")]

        stdout: StdioCollector {
            id: listOutput

            onStreamFinished: {
                try {
                    root.entries = JSON.parse(listOutput.text).devices ?? [];
                } catch (error) {
                    root.entries = [];
                }
                root.loaded = true;
                root.working = false;
            }
        }
    }

    Process {
        id: actionProcess

        stderr: StdioCollector {
            id: actionError
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.lastError = actionError.text.trim();
            root.refresh();
        }
    }
}