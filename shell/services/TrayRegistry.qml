pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property real unseenTtl: 30 * 24 * 60 * 60 * 1000

    readonly property string path: `${Paths.state}/tray_icons.json`

    property var remembered: []
    property var procNames: ({})
    property bool loaded: false
    property string lastSaved: ""

    // Every icon the shell knows about, running or not, in bar order.
    readonly property var entries: root.applyOrder(root.merged(), entry => entry.alias).map(entry => ({
                id: entry.id,
                alias: entry.alias,
                title: entry.title,
                icon: entry.liveIcon || entry.icon || root.fallbackIcon(entry),
                running: entry.running
            }))

    // The icons the bar draws, in bar order. Hidden icons are in neither list, so
    // the bar and the tray popout cannot disagree about which icons exist.
    readonly property var trayItems: root.applyOrder(SystemTray.items.values.filter(item => item.status !== Status.Passive && root.stateOfItem(item) !== "hidden"), item => root.keyOfItem(item))

    readonly property int collapsedCount: root.trayItems.filter(item => root.stateOfItem(item) === "collapsed").length

    // `remembered` with the running items folded in, keyed by alias. Both the bar
    // and the settings page read this, so they cannot drift apart.
    function merged(): var {
        const now = Date.now();
        const known = new Map(root.remembered.map(entry => [entry.alias ?? entry.id, entry]));
        for (const item of SystemTray.items.values) {
            if (item.status === Status.Passive)
                continue;
            const alias = root.keyOfItem(item);
            const existing = known.get(alias);
            known.set(alias, {
                id: item.id,
                alias: alias,
                title: root.displayName(item.id, item.title, item.icon) || existing?.title || alias,
                icon: root.stableIcon(item.icon) || existing?.icon || "",
                liveIcon: item.icon,
                running: true,
                lastSeen: now
            });
        }
        return [...known.values()].map(entry => ({
                id: entry.id,
                alias: entry.alias ?? entry.id,
                title: entry.title || entry.alias || entry.id,
                icon: entry.icon ?? "",
                liveIcon: entry.running ? (entry.liveIcon ?? "") : "",
                running: entry.running === true,
                lastSeen: entry.lastSeen ?? 0
            }));
    }

    function persisted(entry: var): var {
        return {
            id: entry.id,
            alias: entry.alias,
            title: entry.title,
            icon: entry.icon,
            lastSeen: entry.lastSeen
        };
    }

    function keyOfItem(item: var): string {
        return root.keyOfId(item.id, item.icon);
    }

    function keyOfId(id: string, icon: string): string {
        for (const entry of root.remembered) {
            if (entry.id === id)
                return entry.alias ?? id;
        }
        return root.appKeyOf(id, icon);
    }

    function pidOfId(id: string): string {
        const match = /^(\d+)-\d+$/.exec(id);
        return match ? match[1] : "";
    }

    function isTransientIcon(icon: string): bool {
        return icon.startsWith("image://qspixmap/");
    }

    function stableIcon(icon: string): string {
        return root.isTransientIcon(icon) ? "" : icon;
    }

    function themeIconName(icon: string): string {
        if (!icon.startsWith("image://icon/"))
            return "";
        const name = icon.slice("image://icon/".length);
        return name && !name.includes("/") ? name : "";
    }

    function prettify(name: string): string {
        return name.replace(/[_-]+/g, " ").replace(/\s+/g, " ").trim();
    }

    function appKeyOf(id: string, icon: string): string {
        const pid = root.pidOfId(id);
        const comm = pid ? root.procNames[pid] : "";
        if (comm)
            return `proc:${comm}`;
        const iconName = root.themeIconName(icon);
        if (iconName)
            return `icon:${iconName}`;
        return id;
    }

    function displayName(id: string, title: string, icon: string): string {
        const pid = root.pidOfId(id);
        const comm = pid ? root.procNames[pid] : "";
        if (title && title !== id && !/^\d+-\d+$/.test(title))
            return title;
        if (comm)
            return root.prettify(comm);
        const iconName = root.themeIconName(icon);
        if (iconName)
            return root.prettify(iconName);
        return root.prettify(id);
    }

    function fallbackIcon(entry: var): string {
        const alias = String(entry.alias ?? "").replace(/^(proc|icon):/, "");
        const names = [alias, String(entry.title ?? "")].map(name => name.toLowerCase().replace(/[^a-z0-9.+_-]+/g, "-").replace(/^-+|-+$/g, "")).filter(name => name);
        for (const name of names) {
            const path = Quickshell.iconPath(name, "");
            if (path)
                return path;
        }
        return "";
    }

    function sanitize(list: var): var {
        return list.map(entry => ({
                id: entry.id,
                alias: entry.alias ?? entry.id,
                title: entry.title ?? "",
                icon: root.stableIcon(entry.icon ?? ""),
                lastSeen: entry.lastSeen ?? 0
            }));
    }

    function refreshProcNames(): void {
        const pids = [...new Set([...SystemTray.items.values].map(item => root.pidOfId(item.id)).filter(pid => pid))];
        if (pids.length === 0)
            return;
        proc.command = ["bash", "-c", `for p in ${pids.join(" ")}; do printf '%s %s\\n' "$p" "$(cat /proc/$p/comm 2>/dev/null)"; done`];
        proc.running = true;
    }

    function applyOrder(list: var, key: var): var {
        const order = GlobalConfig.bar.tray.order;
        const pos = new Map();
        order.forEach((id, i) => pos.set(id, i));
        return list.map((entry, i) => ({
                entry,
                i
            })).sort((a, b) => {
            const ra = pos.has(key(a.entry)) ? pos.get(key(a.entry)) : order.length;
            const rb = pos.has(key(b.entry)) ? pos.get(key(b.entry)) : order.length;
            return ra !== rb ? ra - rb : a.i - b.i;
        }).map(e => e.entry);
    }

    function stateOf(key: string): string {
        if (GlobalConfig.bar.tray.hiddenIcons.includes(key))
            return "hidden";
        if (GlobalConfig.bar.tray.alwaysVisible.includes(key))
            return "visible";
        return "collapsed";
    }

    function stateOfItem(item: var): string {
        return root.stateOf(root.keyOfItem(item));
    }

    function setState(key: string, state: string): void {
        const always = GlobalConfig.bar.tray.alwaysVisible.filter(entry => entry !== key);
        const hidden = GlobalConfig.bar.tray.hiddenIcons.filter(entry => entry !== key);
        GlobalConfig.bar.tray.alwaysVisible = state === "visible" ? [...always, key] : always;
        GlobalConfig.bar.tray.hiddenIcons = state === "hidden" ? [...hidden, key] : hidden;
    }

    function setOrder(keys: var): void {
        const current = GlobalConfig.bar.tray.order;
        if (keys.length === current.length && keys.every((key, i) => key === current[i]))
            return;
        GlobalConfig.bar.tray.order = keys;
    }

    function forget(alias: string): void {
        root.remembered = root.remembered.filter(entry => (entry.alias ?? entry.id) !== alias);
        root.setState(alias, "collapsed");
        saveTimer.restart();
    }

    function prune(list: var): var {
        const now = Date.now();
        return list.filter(entry => {
            const alias = entry.alias ?? entry.id;
            if (/^\d+-\d+$/.test(alias))
                return false;
            return root.stateOf(alias) !== "collapsed" || now - (entry.lastSeen ?? 0) < root.unseenTtl;
        });
    }

    function sameEntries(a: var, b: var): bool {
        if (a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++) {
            const x = a[i];
            const y = b[i];
            if (x.id !== y.id || (x.alias ?? x.id) !== (y.alias ?? y.id) || x.title !== y.title || x.icon !== y.icon)
                return false;
        }
        return true;
    }

    function record(): void {
        if (!root.loaded)
            return;

        const next = root.prune(root.merged().map(root.persisted));
        if (root.sameEntries(next, root.remembered)) {
            for (let i = 0; i < next.length; i++)
                root.remembered[i].lastSeen = next[i].lastSeen;
            saveTimer.restart();
            return;
        }
        root.remembered = next;
        saveTimer.restart();
    }

    // Config rewrites belong to ConfigMigrations; the registry only owns the
    // alias every entry it remembers, including the ones written before aliases.
    function migrate(): void {
        ConfigMigrations.migrateTrayIcons(root.remembered);
        let changed = false;
        const next = root.remembered.map(entry => {
            if (entry.alias)
                return entry;
            changed = true;
            return {
                id: entry.id,
                alias: entry.id,
                title: entry.title ?? "",
                icon: entry.icon ?? "",
                lastSeen: entry.lastSeen ?? 0
            };
        });
        if (changed) {
            root.remembered = next;
            saveTimer.restart();
        }
    }

    function save(): void {
        const text = JSON.stringify(root.remembered);
        if (text === root.lastSaved)
            return;
        root.lastSaved = text;
        fileView.setText(text);
    }

    Component.onCompleted: fileView.reload()

    // Process names arrive after the first record, and they are what most aliases
    // are made of, so fold the corrected aliases in as soon as they land.
    onProcNamesChanged: root.record()

    Connections {
        function onValuesChanged(): void {
            root.refreshProcNames();
            root.record();
        }

        target: SystemTray.items
    }

    Process {
        id: proc

        command: []

        stdout: StdioCollector {
            id: procOut
        }

        onExited: {
            const next = Object.assign({}, root.procNames);
            let changed = false;
            for (const line of procOut.text.trim().split("\n")) {
                const space = line.indexOf(" ");
                if (space <= 0)
                    continue;
                const pid = line.slice(0, space);
                const name = line.slice(space + 1).trim();
                if (name && next[pid] !== name) {
                    next[pid] = name;
                    changed = true;
                }
            }
            if (changed)
                root.procNames = next;
        }
    }

    FileView {
        id: fileView

        path: root.path
        watchChanges: false
        printErrors: false

        onLoaded: {
            let parsed = [];
            try {
                const data = JSON.parse(fileView.text());
                if (Array.isArray(data))
                    parsed = data;
            } catch (e) {
                Logger.log("[TrayRegistry] ignoring an unreadable tray icon file:", e);
            }
            root.remembered = root.prune(root.sanitize(parsed));
            root.loaded = true;
            root.migrate();
            root.record();
        }

        // A missing file is the first run after the upgrade, which is exactly when
        // the config still holds raw ids that need rewriting.
        onLoadFailed: {
            root.remembered = [];
            root.loaded = true;
            root.migrate();
            root.record();
        }
    }

    Timer {
        id: saveTimer

        interval: 400
        repeat: false
        onTriggered: root.save()
    }
}
