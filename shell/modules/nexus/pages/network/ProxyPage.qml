pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> modeItems: [
        MenuItem {
            text: qsTr("No proxy")
            value: "none"
        },
        MenuItem {
            text: qsTr("Manual")
            value: "manual"
        },
        MenuItem {
            text: qsTr("Automatic (PAC script)")
            value: "pac"
        },
        MenuItem {
            text: qsTr("Detect automatically")
            value: "auto"
        },
        MenuItem {
            text: qsTr("Use environment variables")
            value: "env"
        }
    ]

    readonly property string mode: Proxy.settings.mode ?? "none"
    readonly property bool manual: root.mode === "manual"

    function modeItem(): MenuItem {
        return root.modeItems.find(item => item.value === root.mode) ?? root.modeItems[0];
    }

    title: qsTr("Proxy")
    isSubPage: true

    Component.onCompleted: Proxy.refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SelectRow {
            label: qsTr("Mode")
            subtext: qsTr("How applications decide where to send requests")
            first: true
            last: !root.manual && root.mode !== "pac"
            menuItems: root.modeItems
            active: root.modeItem()
            fallbackText: root.mode
            onSelected: item => Proxy.setMode(item.value)
        }

        Repeater {
            model: root.manual
                ? [
                    { label: qsTr("HTTP proxy"), key: "http", hint: "http://host:port" },
                    { label: qsTr("HTTPS proxy"), key: "https", hint: "http://host:port" },
                    { label: qsTr("SOCKS proxy"), key: "socks", hint: "socks://host:port" },
                    { label: qsTr("No proxy for"), key: "noProxy", hint: qsTr("Comma separated hosts") }
                ]
                : root.mode === "pac"
                    ? [{ label: qsTr("Script address"), key: "pac", hint: "http://host/proxy.pac" }]
                    : []

            delegate: StyledRect {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: fieldLayout.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer

                ColumnLayout {
                    id: fieldLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: modelData.label
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
                    }

                    StyledInputField {
                        Layout.fillWidth: true

                        text: Proxy.settings[modelData.key] ?? ""
                        placeholderText: modelData.hint
                        horizontalAlignment: TextInput.AlignLeft
                        onEditingFinished: Proxy.set(modelData.key, text)
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            text: qsTr("Stored in kioslaverc, which KDE applications read: Plasma, Dolphin, Konsole and the rest. Programs started from a shell keep whatever their environment says until they are restarted.")
            color: Colours.palette.m3onSurfaceVariant
            font: NexusStyle.secondaryFont
            wrapMode: Text.Wrap
        }
    }
}
