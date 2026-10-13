import QtQuick
import Quickshell.Io
import qs.utils
import "claudecode.js" as ClaudeCode

Process {
    id: root

    property string chatId
    property string msgId
    property bool stopped: false
    readonly property var stream: ClaudeCode.createState()
    property real startedAt: 0
    property int outputTokens: 0
    property bool toolRunning: false

    signal textUpdated(text: string)
    signal thoughtUpdated(text: string)
    signal toolsUpdated(tools: var)
    signal toolStarted(name: string)
    signal toolsDone
    signal progressed(text: string)
    signal outputTokensUpdated(count: int)
    signal usageUpdated(usage: string)
    signal completed(reply: var)
    signal ended

    function stop(): void {
        stopped = true;
        running = false;
    }

    function dispatch(updates: var): void {
        for (let i = 0; i < updates.length; i++) {
            const u = updates[i];
            switch (u.type) {
            case "text": textUpdated(u.text); break;
            case "thought": thoughtUpdated(u.text); break;
            case "tools": toolsUpdated(u.tools); break;
            case "toolStarted": toolStarted(u.name); break;
            case "toolsDone": toolsDone(); break;
            case "progress": progressed(u.text); break;
            case "tokens": outputTokensUpdated(u.count); break;
            case "usage": usageUpdated(u.text); break;
            case "finished": completed(u.reply); break;
            }
        }
    }

    stdout: SplitParser {
        onRead: line => root.dispatch(ClaudeCode.handleLine(root.stream, line))
    }
    stderr: SplitParser {
        onRead: line => {
            const t = (line || "").trim();
            if (t === "")
                return;
            root.stream.errAcc += t + "\n";
            Logger.log("[ClaudeCode] " + t);
        }
    }

    onExited: code => {
        const reply = ClaudeCode.handleExit(root.stream, code, root.stopped);
        if (reply)
            completed(reply);
        ended();
    }
}
