import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components
import qs.services
import qs.services.api
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

    function stateDir(): string {
        return Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state");
    }

    function exportYaml(): void {
        const plugins = [];
        for (let i = 0; i < CaelestiaApi.plugins.available.count; i++) {
            const p = CaelestiaApi.plugins.available.get(i);
            plugins.push({
                id: p.id || p.name,
                version: p.version || "",
                enabled: p.enabled !== false,
                source: p.source || ""
            });
        }
        exportProc.pluginsJson = JSON.stringify(plugins);
        root.exportStatus = qsTr("Exporting...");
        exportProc.running = true;
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
            id: exportProc

            property string pluginsJson: "[]"

            command: ["python3", "-c", "import json, os, sys\nconfig_dir, state_dir, plugins_json = sys.argv[1:4]\ndef load_json(path, default):\n    try:\n        with open(path) as f:\n            return json.load(f)\n    except Exception:\n        return default\ndef load_text(path):\n    try:\n        with open(path) as f:\n            content = f.read()\n        try:\n            return json.loads(content)\n        except Exception:\n            return content\n    except Exception:\n        return None\ndef scalar(v):\n    import re\n    if v is None:\n        return "null"\n    if isinstance(v, bool):\n        return "true" if v else "false"\n    if isinstance(v, (int, float)):\n        return str(v)\n    t = str(v)\n    if t != "" and re.match(r"^[A-Za-z0-9_.\\-]+$", t) and t not in ("null", "true", "false"):\n        return t\n    return "\\"" + t.replace("\\\\", "\\\\\\\\").replace("\\"", "\\\\\\"").replace("\\n", "\\\\n") + "\\""\ndef dump(v, ind):\n    pad = "  " * ind\n    if isinstance(v, dict):\n        if not v:\n            return "{}\\n"\n        out = ""\n        for k, item in v.items():\n            if isinstance(item, (dict, list)):\n                nested = dump(item, ind + 1)\n                if nested in ("[]\\n", "{}\\n"):\n                    out += pad + str(k) + ": " + nested\n                else:\n                    out += pad + str(k) + ":\\n" + nested\n            else:\n                out += pad + str(k) + ": " + scalar(item) + "\\n"\n        return out\n    if isinstance(v, list):\n        if not v:\n            return "[]\\n"\n        out = ""\n        for item in v:\n            if isinstance(item, (dict, list)):\n                out += pad + "-\\n" + dump(item, ind + 1)\n            else:\n                out += pad + "- " + scalar(item) + "\\n"\n        return out\n    return scalar(v)\nout = {}\nout["shell"] = load_json(os.path.join(config_dir, "caelestia", "shell.json"), {})\nout["keybinds"] = load_json(os.path.join(config_dir, "caelestia", "keybinds.json"), {})\nout["cli"] = load_json(os.path.join(config_dir, "caelestia", "cli.json"), {})\nout["notes"] = load_json(os.path.join(state_dir, "caelestia", "notes_tab.json"), [])\nmonitors = {}\nmon_dir = os.path.join(config_dir, "caelestia", "monitors")\ntry:\n    for name in sorted(os.listdir(mon_dir)):\n        v = load_text(os.path.join(mon_dir, name))\n        if v is not None:\n            monitors[name] = v\nexcept Exception:\n    pass\nout["monitors"] = monitors\ntry:\n    out["plugins"] = json.loads(plugins_json)\nexcept Exception:\n    out["plugins"] = []\nwith open(os.path.join(config_dir, "caelestia", "shell.yaml"), "w") as f:\n    f.write(dump(out, 0))\nprint("DONE")", root.configDir(), root.stateDir(), pluginsJson]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.exportStatus = qsTr("Saved to shell.yaml");
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    root.exportStatus = qsTr("Export failed");
                }
            }
            onExited: code => {
                if (code !== 0)
                    root.exportStatus = qsTr("Export failed");
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
