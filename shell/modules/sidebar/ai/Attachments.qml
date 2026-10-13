import QtQuick
import Quickshell
import Quickshell.Io
import "attachments.js" as AttachmentPaths

QtObject {
    id: root

    property var pending: []
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || ((Quickshell.env("HOME") || "") + "/.cache")) + "/caelestia/ai-attachments"

    readonly property Process pasteProc: Process {
        stdout: StdioCollector {}
        onExited: code => {
            const out = (root.pasteProc.stdout.text || "").trim();
            if (code === 0 && out !== "")
                root.add(out);
            else
                root.pasteText();
        }
    }

    signal pasteText

    function add(path: string): void {
        path = AttachmentPaths.localPath(path);
        if (path === "" || pending.some(a => a.path === path))
            return;
        pending = pending.concat([{ "path": path, "isImage": AttachmentPaths.isImagePath(path) }]);
    }

    function remove(path: string): void {
        pending = pending.filter(a => a.path !== path);
    }

    function take(): var {
        const paths = pending.map(a => a.path);
        pending = [];
        return paths;
    }

    function pasteImage(): void {
        if (pasteProc.running)
            return;
        const file = cacheDir + "/paste-" + Date.now() + ".png";
        const script = "t=$(wl-paste --list-types 2>/dev/null | grep -m1 '^image/') || exit 3; "
            + "mkdir -p \"$1\" && wl-paste --no-newline --type \"$t\" > \"$2\" && echo \"$2\"";
        pasteProc.command = ["sh", "-c", script, "--", cacheDir, file];
        pasteProc.running = true;
    }
}
