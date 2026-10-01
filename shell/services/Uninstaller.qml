pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    readonly property var candidatePaths: [
        Quickshell.env("CAELESTIA_DIR") ? Quickshell.env("CAELESTIA_DIR") + "/uninstall.sh" : "",
        root.home + "/caelestia-kde/uninstall.sh",
        root.home + "/.config/caelestia-update/repo/uninstall.sh",
        root.home + "/.cache/caelestia-update-repo/uninstall.sh"
    ].filter(p => p !== "")

    property bool probed: false
    property string scriptPath: ""
    property string manualCommand: ""

    readonly property bool scriptFound: scriptPath !== ""

    function launch(): void {
        if (!scriptFound)
            return;

        Quickshell.execDetached({
            command: [...GlobalConfig.general.apps.terminal,
                Quickshell.shellDir + "/assets/wrap_term_launch.sh",
                "bash", scriptPath]
        });
    }

    Process {
        id: probe

        command: ["sh", "-c", `
for candidate in "$@"; do
    if [ -f "$candidate" ]; then
        printf 'SCRIPT %s\n' "$candidate"
        exit 0
    fi
done
if command -v pacman >/dev/null 2>&1; then
    echo "MANUAL sudo pacman -Rns caelestia-kde"
elif command -v dnf >/dev/null 2>&1; then
    echo "MANUAL sudo dnf remove caelestia-kde"
elif command -v apt-get >/dev/null 2>&1; then
    echo "MANUAL sudo apt-get remove caelestia-kde"
else
    echo MANUAL
fi`, "--", ...root.candidatePaths]
        stdout: StdioCollector {
            onStreamFinished: {
                const script = text.split("\n").find(l => l.startsWith("SCRIPT "));
                const manual = text.split("\n").find(l => l.startsWith("MANUAL"));
                if (script)
                    root.scriptPath = script.slice("SCRIPT ".length).trim();
                if (manual)
                    root.manualCommand = manual.slice("MANUAL ".length).trim();
                root.probed = true;
            }
        }
    }
}
