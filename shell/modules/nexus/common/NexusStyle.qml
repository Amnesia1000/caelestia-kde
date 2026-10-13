pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config

Singleton {
    readonly property font secondaryFont: Tokens.font.label.builders.small.size(10).build()
}
