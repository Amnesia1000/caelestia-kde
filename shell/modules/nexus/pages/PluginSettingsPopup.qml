import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

Popup {
    id: root

    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: 450
    modal: true
    dim: true

    property string pluginId: ""

    property var settingsSchema: PluginLoader.settingsSchemaFor(root.pluginId)

    property string pluginName: ""

    Settings {
        id: pSettings

        category: "Plugin_" + root.pluginId
    }

    background: Rectangle {
        color: Colours.palette.m3surface
        radius: Tokens.rounding.large
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
    }

    contentItem: ColumnLayout {
        spacing: Tokens.spacing.large

        StyledText {
            text: root.pluginName + " " + qsTr("Settings")
            font: Tokens.font.title.large
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            Repeater {
                model: root.settingsSchema
                delegate: RowLayout {
                    id: delegateRow
                    Layout.fillWidth: true

                    required property var modelData

                    StyledText {
                        text: delegateRow.modelData.label
                        Layout.fillWidth: true
                        font: Tokens.font.body.medium
                    }

                    RowLayout {
                        visible: delegateRow.modelData.type === "enum"
                        spacing: Tokens.spacing.extraSmall

                        Repeater {
                            model: delegateRow.modelData.options
                            delegate: TextButton {
                                required property string modelData

                                text: modelData

                                property string currentVal: root.visible ? pSettings.value(delegateRow.modelData.id, delegateRow.modelData.default) : ""
                                enabled: currentVal !== modelData
                                onClicked: {
                                    pSettings.setValue(delegateRow.modelData.id, modelData);
                                    currentVal = modelData;
                                }
                            }
                        }
                    }

                    StyledSwitch {
                        visible: delegateRow.modelData.type === "toggle"
                        checked: root.visible ? pSettings.value(delegateRow.modelData.id, delegateRow.modelData.default ?? false) : false
                        onToggled: pSettings.setValue(delegateRow.modelData.id, checked)
                    }

                    StyledTextField {
                        visible: delegateRow.modelData.type === "text"
                        Layout.preferredWidth: 180
                        text: root.visible ? pSettings.value(delegateRow.modelData.id, delegateRow.modelData.default ?? "") : ""
                        placeholderText: delegateRow.modelData.placeholder ?? ""
                        onEditingFinished: pSettings.setValue(delegateRow.modelData.id, text)
                    }

                    CustomSpinBox {
                        visible: delegateRow.modelData.type === "number"
                        Layout.preferredWidth: 140
                        min: delegateRow.modelData.min ?? 0
                        max: delegateRow.modelData.max ?? 100
                        step: delegateRow.modelData.step ?? 1
                        value: root.visible ? Number(pSettings.value(delegateRow.modelData.id, delegateRow.modelData.default ?? 0)) : 0
                        onValueModified: v => pSettings.setValue(delegateRow.modelData.id, v)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            TextButton {
                text: qsTr("Done")
                onClicked: root.close()
            }
        }
    }
}
