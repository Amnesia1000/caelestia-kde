import QtQuick
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property var bar

    // Size of the glyph. The bar reads it from its label font; the dock overrides
    // it so the logo matches the size of its tiles.
    property real iconSize: Math.round(Tokens.font.body.large.pointSize * 1.2)

    implicitWidth: Math.round(iconSize)
    implicitHeight: Math.round(iconSize)

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: root.implicitWidth + Tokens.padding.medium
        implicitHeight: root.implicitHeight + Tokens.padding.medium
        radius: Tokens.rounding.full
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                const popouts = root.bar.popouts;
                if (!popouts)
                    return;
                if (popouts.hasCurrent && popouts.currentName === "osiconcontext") {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "osiconcontext";
                    popouts.currentCenter = root.bar.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : (root.mapToItem(null, 0, root.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                }
                return;
            }
            Visibilities.toggleLauncher("");
        }
    }

    Loader {
        asynchronous: true
        anchors.centerIn: parent
        sourceComponent: {
            if (SysInfo.isDefaultLogo) {
                return caelestiaLogo;
            } else if (GlobalConfig.general.logo && GlobalConfig.general.logo !== "caelestia") {
                return customIcon;
            } else {
                return distroIcon;
            }
        }
    }

    Component {
        id: caelestiaLogo

        Logo {
            implicitWidth: Math.round(root.iconSize * 4 / 3)
            implicitHeight: Math.round(root.iconSize * 4 / 3)
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Math.round(root.iconSize)
            colour: Colours.palette.m3tertiary
        }
    }

    Component {
        id: customIcon

        Loader {
            sourceComponent: SysInfo.recolourCustomLogo ? colouredIconComponent : iconImageComponent
        }
    }

    Component {
        id: colouredIconComponent

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Math.round(root.iconSize * (SysInfo.customLogoSize / 100))
            colour: Colours.palette.m3tertiary
        }
    }

    Component {
        id: iconImageComponent

        IconImage {
            source: SysInfo.osLogo
            implicitWidth: Math.round(root.iconSize * (SysInfo.customLogoSize / 100))
            implicitHeight: Math.round(root.iconSize * (SysInfo.customLogoSize / 100))
        }
    }
}
