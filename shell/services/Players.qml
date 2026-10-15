pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Caelestia
import Caelestia.Config
import qs.components.misc

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: props.manualActive ?? list.find(p => getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? list[0] ?? null
    property alias manualActive: props.manualActive

    readonly property list<string> appVolumePlayers: ["Spotify", "Fastpotify", "YouTube Music"]

    property string lastNowPlayingKey: ""

    function getIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.values.find(a => a.from === player.identity);
        if (alias)
            return alias.to;
        if (player.identity === "com.github.th-ch.youtube-music" || player.identity === "com.github.th_ch.youtube_music")
            return "YouTube Music";
        return player.identity;
    }

    function playerMatchesSource(player: MprisPlayer, name: string): bool {
        if (!player || !name)
            return false;
        const target = String(name).trim().toLowerCase();
        if (!target)
            return false;

        const friendly = root.getIdentity(player).toLowerCase();
        const raw = String(player.identity ?? "").toLowerCase();
        const entry = String(player.entry ?? "").toLowerCase();

        if (friendly.includes(target) || raw.includes(target) || entry.includes(target))
            return true;

        const cleanTarget = target.replace(/[^a-z0-9]/g, "");
        if (cleanTarget) {
            const cleanFriendly = friendly.replace(/[^a-z0-9]/g, "");
            const cleanRaw = raw.replace(/[^a-z0-9]/g, "");
            const cleanEntry = entry.replace(/[^a-z0-9]/g, "");

            if (cleanFriendly.includes(cleanTarget) || cleanRaw.includes(cleanTarget) || cleanEntry.includes(cleanTarget))
                return true;

            if ((cleanTarget === "youtubemusic" && cleanFriendly === "ytmusic") ||
                (cleanTarget === "ytmusic" && (cleanFriendly === "youtubemusic" || cleanRaw.includes("youtube"))))
                return true;
        }

        return false;
    }

    function supportsAppVolume(player: MprisPlayer): bool {
        if (!player)
            return false;
        return root.appVolumePlayers.some(n => root.playerMatchesSource(player, n));
    }

    // First player whose identity matches one of the given source names
    // (empty list follows the active player), or null when none matches.
    // Prefers currently-playing matches over paused ones.
    function sourcePlayer(names: var): MprisPlayer {
        const sources = names || [];
        if (sources.length === 0)
            return root.active;
        const list = root.list || [];
        let firstMatch = null;
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            for (let j = 0; j < sources.length; j++) {
                if (root.playerMatchesSource(p, String(sources[j]))) {
                    if (p.isPlaying)
                        return p;
                    if (!firstMatch)
                        firstMatch = p;
                }
            }
        }
        return firstMatch;
    }

    // A display name cut into comparable tokens: lowercased, ".desktop" and
    // "-desktop" tails dropped, split on anything that is not a letter or digit.
    function nameTokens(name: var): var {
        return String(name ?? "").toLowerCase().replace(/\.desktop$/g, "").replace(/-desktop$/g, "").split(/[^a-z0-9]+/).filter(t => t.length > 0);
    }

    // Process id from a Chromium-family MPRIS bus name
    // (chromium.instance<PID>), or "" when the entry carries none.
    function instancePid(entry: var): string {
        const m = String(entry ?? "").match(/\.instance(\d+)$/);
        return m ? m[1] : "";
    }

    // Whether a PipeWire stream belongs to an MPRIS player. Compares the
    // stream name, process binary and app name against the player identity
    // and entry by shared tokens or substring either way, and additionally
    // matches the Chromium-family case by process id: branded forks report
    // one name over MPRIS and another over PipeWire, so names alone never
    // meet while the pid is the same on both sides.
    function streamMatches(player: var, streamName: var, binary: var, appName: var, processId: var): bool {
        if (!player)
            return false;
        const identity = String(player.identity ?? "").toLowerCase();
        const entry = String(player.entry ?? "").toLowerCase();
        if (!identity && !entry)
            return false;
        const pid = instancePid(entry);
        if (pid && String(processId ?? "") === pid)
            return true;
        const playerTokens = [...nameTokens(identity), ...nameTokens(entry)];
        const streamTokens = [...nameTokens(streamName), ...nameTokens(binary), ...nameTokens(appName)];
        if (playerTokens.some(t => streamTokens.includes(t)))
            return true;
        const playerNames = [identity, entry].filter(n => n);
        const streamNames = [String(streamName ?? "").toLowerCase(), String(binary ?? "").toLowerCase(), String(appName ?? "").toLowerCase()].filter(n => n);
        return streamNames.some(sn => playerNames.some(pn => sn.includes(pn) || pn.includes(sn)));
    }

    // The PipeWire stream belonging to a player, or null when none matches.
    // The audio service is passed in so both the bar widget and its popout
    // share this lookup instead of duplicating it.
    function playerStream(player: var, audio: var): var {
        const streams = audio?.streams ?? [];
        return streams.find(s => {
            const props = s.properties ?? {};
            return root.streamMatches(player, audio.getStreamName(s), (props["application.process.binary"] ?? "").toString(), (props["app.name"] ?? "").toString(), (props["application.process.id"] ?? "").toString());
        }) || null;
    }

    // Effective volume for scroll control: MPRIS app volume first, then the
    // matching PipeWire stream, then the global sink.
    function playerVolume(player: var, stream: var, audio: var): real {
        if (root.supportsAppVolume(player) && player?.volume !== undefined && player?.volume !== null)
            return player.volume;
        if (stream)
            return audio.getStreamVolume(stream);
        return audio.volume;
    }

    function setPlayerVolume(player: var, stream: var, audio: var, v: real): void {
        const clamped = Math.max(0, Math.min(1, v));
        if (root.supportsAppVolume(player) && player && player.volume !== undefined) {
            player.volume = clamped;
        } else if (stream) {
            audio.setStreamVolume(stream, clamped);
        } else {
            audio.setVolume(clamped);
        }
    }

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;

        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            // Fallback for youtube
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    // Quickshell only emits postTrackChanged when trackid/url/title change, so late
    // artist updates (common with mpv-mpris + yt-dlp player) never retrigger it. Watch
    // title/artist too and toast once both are usable.
    function maybeToastNowPlaying(): void {
        if (!GlobalConfig.utilities.toasts.nowPlaying)
            return;

        const player = root.active;
        if (!player)
            return;

        const title = player.trackTitle ?? "";
        const artist = player.trackArtist ?? "";
        if (!title || !artist)
            return;

        const key = `${getIdentity(player)}\0${player.uniqueId}\0${title}\0${artist}`;
        if (key === lastNowPlayingKey)
            return;

        lastNowPlayingKey = key;
        Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(artist).arg(title), "music_note");
    }

    onActiveChanged: lastNowPlayingKey = ""

    Connections {
        function onPostTrackChanged(): void {
            root.maybeToastNowPlaying();
        }

        function onTrackTitleChanged(): void {
            root.maybeToastNowPlaying();
        }

        function onTrackArtistChanged(): void {
            root.maybeToastNowPlaying();
        }

        target: root.active
    }

    PersistentProperties {
        id: props

        property MprisPlayer manualActive

        reloadableId: "players"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: qsTr("Toggle media playback")
        onPressed: {
            const active = root.active;
            if (active && active.canTogglePlaying)
                active.togglePlaying();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: qsTr("Previous track")
        onPressed: {
            const active = root.active;
            if (active && active.canGoPrevious)
                active.previous();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: qsTr("Next track")
        onPressed: {
            const active = root.active;
            if (active && active.canGoNext)
                active.next();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: qsTr("Stop media playback")
        onPressed: root.active?.stop()
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? qsTr("Invalid property") : qsTr("No active player");
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }

        target: "mpris"
    }
}
