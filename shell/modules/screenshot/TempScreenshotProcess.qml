import QtQuick
import Quickshell
import Quickshell.Io

Process {
    id: screenshotProc

    running: true

    property string screenshotDir: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/caelestia-screenshot`

    required property ShellScreen screen

    property string screenshotPath: `${screenshotDir}/image-${screen.name}.png`

    readonly property string _safeDir: screenshotDir.split("'").join("'\\''")

    readonly property string _safePath: screenshotPath.split("'").join("'\\''")

    // Safety net: the backend hangs instead of exiting when the portal is
    // broken, which would leave the exclusive-focus selector up forever.
    // `timeout` kills it so onExited fires (124) and the caller backs out.
    // Normal captures take well under a second.
    property int timeoutSeconds: 15

    command: ["bash", "-c", `mkdir -p '${_safeDir}' && exec timeout ${timeoutSeconds} spectacle -b -n -m -o '${_safePath}'`]
}
