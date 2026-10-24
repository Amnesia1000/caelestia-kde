pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services

Singleton {
    id: root

    readonly property bool _loaded: EmojiDb.loaded
    readonly property int itemCount: EmojiDb.count

    function reload(): void {
        if (!EmojiDb.loaded) {
            console.warn("EmojiDb not loaded yet");
        }
    }

    function recordUsage(ch: string): void {
        EmojiDb.recordUsage(ch);
    }

    function getSortedItems(): var {
        const favEmojis = GlobalConfig.launcher.favouriteEmojis || [];
        return EmojiDb.getSortedItems(favEmojis, 30);
    }

    function search(text: string): var {
        const favEmojis = GlobalConfig.launcher.favouriteEmojis || [];
        return EmojiDb.search(text, 30, favEmojis);
    }

    Connections {
        function onFavouriteEmojisChanged(): void {
        }

        target: GlobalConfig.launcher
    }
}
