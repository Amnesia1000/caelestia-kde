pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// A script in `scripts/` whose answer is JSON, with its failure kept as a failure.
///
/// Every service that reads one otherwise repeats the same four steps: build the command,
/// collect stdout, survive a parse that throws, and decide what "nothing" means. Written
/// once, an empty answer or a script that broke stays an error, instead of becoming an
/// empty list that the view then reports as a fact.
Process {
    id: root

    required property string script
    property list<string> args: []
    property var result: null
    property string error: ""
    property bool loaded: false

    /// Runs the script again. A run already in flight is abandoned rather than queued:
    /// the newer arguments are the ones the caller is waiting for an answer about.
    function start(): void {
        root.error = "";
        root.loaded = false;
        if (running)
            running = false;
        running = true;
    }

    command: ["python3", Quickshell.shellPath(root.script), ...root.args]

    stdout: StdioCollector {
        id: output

        onStreamFinished: {
            root.result = null;
            const text = output.text.trim();
            if (text === "") {
                root.error = stderrOutput.text.trim() || qsTr("The script printed nothing.");
                return;
            }
            try {
                root.result = JSON.parse(text);
            } catch (exception) {
                root.error = qsTr("The script printed something that is not JSON.");
            }
        }
    }

    stderr: StdioCollector {
        id: stderrOutput
    }

    onExited: exitCode => {
        if (exitCode !== 0 && root.error === "")
            root.error = stderrOutput.text.trim() || qsTr("The script failed with exit code %1.").arg(exitCode);
        root.loaded = true;
    }
}
