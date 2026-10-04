import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    property string pluginCount

    property string quickshellVersion
    property string cliVersion
    property string exportStatus: qsTr("Save shell.json as YAML")

    function configDir(): string {
        return Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
    }

    function toYamlScalar(value: var): string {
        if (value === null || value === undefined)
            return "null";
        if (typeof value === "boolean" || typeof value === "number")
            return String(value);
        const text = String(value);
        if (/^[A-Za-z0-9_.-]+$/.test(text) && text !== "" && text !== "null" && text !== "true" && text !== "false")
            return text;
        return "\"" + text.replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n") + "\"";
    }

    function toYamlNode(value: var, indent: int): string {
        const pad = "  ".repeat(indent);
        if (Array.isArray(value)) {
            if (value.length === 0)
                return "[]";
            let out = "";
            for (let i = 0; i < value.length; i++) {
                const item = value[i];
                if (item !== null && typeof item === "object") {
                    out += pad + "-\n" + root.toYamlNode(item, indent + 1);
                } else {
                    out += pad + "- " + root.toYamlScalar(item) + "\n";
                }
            }
            return out;
        }
        if (value !== null && typeof value === "object") {
            const keys = Object.keys(value);
            if (keys.length === 0)
                return "{}";
            let out = "";
            for (let i = 0; i < keys.length; i++) {
                const item = value[keys[i]];
                if (item !== null && typeof item === "object") {
                    const nested = root.toYamlNode(item, indent + 1);
                    if (nested === "[]" || nested === "{}") {
                        out += pad + keys[i] + ": " + nested + "\n";
                    } else {
                        out += pad + keys[i] + ":\n" + nested;
                    }
                } else {
                    out += pad + keys[i] + ": " + root.toYamlScalar(item) + "\n";
                }
            }
            return out;
        }
        return root.toYamlScalar(value);
    }

    function exportYaml(): void {
        root.exportStatus = qsTr("Exporting...");
        exportReadProc.running = true;
    }

    title: qsTr("About")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            running: true
            command: ["quickshell", "--version"]
            stdout: StdioCollector {
                onStreamFinished: root.quickshellVersion = text.trim().split(" ")[1] ?? ""
            }
        }

        Process {
            id: exportReadProc

            command: ["cat", root.configDir() + "/caelestia/shell.json"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text);
                        exportWriteProc.yamlText = root.toYamlNode(data, 0);
                        exportWriteProc.yamlPath = root.configDir() + "/caelestia/shell.yaml";
                        exportWriteProc.running = true;
                    } catch (e) {
                        root.exportStatus = qsTr("Export failed");
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    root.exportStatus = qsTr("Export failed");
                }
            }
        }

        Process {
            id: exportWriteProc

            property string yamlText: ""
            property string yamlPath: ""

            command: ["python3", "-c", "import sys; open(sys.argv[1], 'w').write(sys.argv[2])", yamlPath, yamlText]
            onExited: code => {
                root.exportStatus = code === 0 ? qsTr("Saved to shell.yaml") : qsTr("Export failed");
            }
        }

        Process {
            running: true
            command: ["sh", "-c", "caelestia --version 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const m = text.match(/^caelestia\s+(\S+)/);
                    root.cliVersion = m ? m[1] : "";
                }
            }
        }
        Process {
            running: true
            command: ["caelestia", "shell", "plugins", "count"]
            stdout: StdioCollector {
                onStreamFinished: root.pluginCount = text.trim()
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: hero.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: hero

                anchors.centerIn: parent
                width: parent.width - Tokens.padding.largeIncreased * 2
                spacing: Tokens.spacing.small

                AnimatedLogo {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Tokens.spacing.small
                    text: "Caelestia"
                    font: Tokens.font.headline.builders.large.width(110).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: CUtils.version ? `v${CUtils.version}` : "…"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                }
            }
        }

        SectionHeader {
            text: qsTr("System")
        }

        InfoRow {
            first: true
            label: qsTr("Hostname")
            value: SysInfo.hostname
        }

        InfoRow {
            label: qsTr("Device")
            value: SysInfo.device
        }

        InfoRow {
            label: qsTr("Distro")
            value: SysInfo.osPrettyName || SysInfo.osName
        }

        InfoRow {
            label: qsTr("Kernel")
            value: SysInfo.kernel
        }

        InfoRow {
            last: true
            label: qsTr("Firmware")
            value: SysInfo.firmware
        }

        SectionHeader {
            text: qsTr("Software")
        }

        InfoRow {
            first: true
            label: qsTr("Shell")
            value: CUtils.version || "…"
        }

        InfoRow {
            label: qsTr("CLI")
            value: root.cliVersion || "…"
        }

        InfoRow {
            label: qsTr("Quickshell")
            value: root.quickshellVersion || "…"
        }

        InfoRow {
            last: true
            label: qsTr("Qt")
            value: CUtils.qtVersion || "…"
        }

        SectionHeader {
            text: qsTr("Plugins")
        }

        NavRow {
            first: true
            last: true
            icon: "extension"
            label: qsTr("Enabled plugins")
            status: root.pluginCount || "…"
            onClicked: {
                const index = PageRegistry.indexForKey("plugins");
                if (index >= 0)
                    root.nState.currentPageIdx = index;
            }
        }

        SectionHeader {
            text: qsTr("Advanced")
        }

        ToggleRow {
            first: true
            text: qsTr("Debug Mode")
            subtext: qsTr("Enable verbose debug logging for troubleshooting. Run 'caelestia shell -l' to view.")
            checked: GlobalConfig.general.debugLogs
            onClicked: GlobalConfig.general.debugLogs = !GlobalConfig.general.debugLogs
        }

        NavRow {
            last: true
            icon: "file_download"
            label: qsTr("Export configuration")
            status: root.exportStatus
            onClicked: root.exportYaml()
        }

        SectionHeader {
            text: qsTr("Uninstall")
        }

        NavRow {
            first: true
            last: true
            icon: "delete_forever"
            label: qsTr("Uninstall Caelestia")
            status: {
                if (Uninstaller.state === "probing")
                    return qsTr("Checking for the uninstaller…");
                if (Uninstaller.state === "script")
                    return qsTr("Remove the shell, its configs and its services");
                if (Uninstaller.state === "package")
                    return qsTr("This install belongs to a package. Remove it with: %1").arg(Uninstaller.manualCommand);
                return qsTr("No uninstaller was found. Remove the install with your package manager.");
            }
            onClicked: uninstallDialog.open()
        }

        UninstallDialog {
            id: uninstallDialog

            state: Uninstaller.state
            manualCommand: Uninstaller.manualCommand
            onConfirmed: Uninstaller.launch()
        }
    }
}
