#!/usr/bin/env bash
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$REPO_ROOT/shell/services/TrayRegistry.qml"
MIGRATIONS="$REPO_ROOT/shell/services/ConfigMigrations.qml"
CONTENT="$REPO_ROOT/shell/modules/bar/popouts/Content.qml"
BAR="$REPO_ROOT/shell/modules/bar/Bar.qml"

test_popouts_are_named_by_the_stable_alias() {
    assert_file_not_contains "$REGISTRY" "trayIndexById" "the registry must not publish positional indices"
    assert_file_not_contains "$CONTENT" "trayIndexById" "the popout name must not be an index"
    assert_file_not_contains "$BAR" "trayIndex" "the bar must not resolve tray icons by index"
    assert_file_contains "$CONTENT" 'traymenu${QsServices.TrayRegistry.keyOfItem(modelData)}' "the popout name is the alias"
}

test_the_registry_merges_live_icons_once() {
    assert_file_contains "$REGISTRY" "root.applyOrder(root.merged()" "the settings list reads the shared merge"
    assert_file_contains "$REGISTRY" "root.prune(root.merged()" "the saved list reads the shared merge"
    assert_file_contains "$REGISTRY" "root.stateOfItem(item)" "the bar list reads visibility from one place"
}

test_the_config_rewrite_lives_in_the_migrations() {
    assert_file_contains "$MIGRATIONS" "function migrateTrayIcons(entries" "config rewrites belong to ConfigMigrations"
    assert_file_contains "$REGISTRY" "ConfigMigrations.migrateTrayIcons(root.remembered)" "the registry hands its aliases over"

    local calls
    calls="$(grep -cF 'root.migrate();' "$REGISTRY")"
    assert_eq "2" "$calls" "both load paths migrate, including the missing-file first run"
}

test_the_registry_resolves_and_orders_icons() {
    if ! command -v node >/dev/null 2>&1; then
        skip_test "node is not available"
        return 0
    fi

    local harness
    harness="$(mktemp "${TMPDIR:-/tmp}/caelestia-trayregistry.XXXXXX.mjs")"
    cat > "$harness" <<'EOF'
import { readFileSync } from "node:fs";

const src = readFileSync(process.argv[2], "utf8");

function sliceBalanced(from, open, close) {
    let depth = 0;
    for (let i = from; i < src.length; i++) {
        if (src[i] === open) depth++;
        else if (src[i] === close && --depth === 0) return src.slice(from, i + 1);
    }
    throw new Error("unbalanced " + open);
}

function stripTypes(header) {
    return header
        .replace(/\)\s*:\s*[A-Za-z_][\w<>.\[\]|]*\s*$/, ") ")
        .replace(/([(,\s])([A-Za-z_]\w*)\s*:\s*[A-Za-z_][\w<>.\[\]|]*/g, "$1$2");
}

function extractFunction(name) {
    const marker = "function " + name + "(";
    const start = src.indexOf(marker);
    if (start === -1) throw new Error(name + " not found");
    const text = sliceBalanced(start, "{", "}");
    const brace = text.indexOf("{");
    return stripTypes(text.slice(0, brace)) + text.slice(brace);
}

const config = { bar: { tray: { order: [], hiddenIcons: [], alwaysVisible: [] } } };
const root = { remembered: [], procNames: {}, unseenTtl: 30 * 24 * 60 * 60 * 1000 };

const names = ["pidOfId", "themeIconName", "appKeyOf", "keyOfId", "stateOf", "applyOrder", "prune"];
Object.assign(root, new Function("root", "GlobalConfig",
    names.map(extractFunction).join("\n") + "\nreturn {" + names.join(", ") + "};")(root, config));

const eq = (actual, expected, msg) => {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        console.error("FAIL:", msg);
        console.error("  actual:  ", JSON.stringify(actual));
        console.error("  expected:", JSON.stringify(expected));
        process.exit(1);
    }
};

config.bar.tray.order = ["c", "a"];
eq(root.applyOrder(["a", "b", "c"], key => key), ["c", "a", "b"], "listed icons come first, in listed order");

config.bar.tray.order = [];
eq(root.applyOrder(["a", "b"], key => key), ["a", "b"], "an empty order keeps registration order");

config.bar.tray.order = ["gone", "b"];
eq(root.applyOrder(["a", "b"], key => key), ["b", "a"], "keys the order does not know are skipped");
config.bar.tray.order = [];

root.remembered = [{ id: "2407-1", alias: "proc:firefox", title: "", icon: "", lastSeen: 1 }];
eq(root.keyOfId("2407-1", ""), "proc:firefox", "a re-launched notifier reuses its alias");

root.remembered = [];
root.procNames = { "2652": "firefox" };
eq(root.keyOfId("2652-9", ""), "proc:firefox", "an unseen notifier folds onto its process name");

root.procNames = {};
eq(root.keyOfId("9999-1", "image://icon/firefox"), "icon:firefox", "no process name falls back to the theme icon");
eq(root.keyOfId("9999-1", "image://qspixmap/abc"), "9999-1", "a pixmap icon names nothing, so the id stays");

const now = Date.now();
const day = 24 * 60 * 60 * 1000;
const entries = [
    { alias: "proc:new", lastSeen: now },
    { alias: "proc:old", lastSeen: now - 40 * day }
];

config.bar.tray.hiddenIcons = [];
config.bar.tray.alwaysVisible = [];
eq(root.prune(entries).map(entry => entry.alias), ["proc:new"], "collapsed icons unseen for a month are dropped");

config.bar.tray.alwaysVisible = ["proc:old"];
eq(root.prune(entries).map(entry => entry.alias), ["proc:new", "proc:old"], "a pinned icon is never dropped");
config.bar.tray.alwaysVisible = [];

eq(root.prune([{ alias: "2407-1", lastSeen: now }]).length, 0, "a launch id never becomes an entry");

config.bar.tray.hiddenIcons = ["proc:new"];
eq(root.stateOf("proc:new"), "hidden", "hidden wins over the other states");
eq(root.stateOf("proc:other"), "collapsed", "anything unset collapses");

console.log("tray registry: all harness cases passed");
EOF

    if ! timeout 15 node "$harness" "$REGISTRY"; then
        rm -f "$harness"
        fail "the tray registry harness failed"
        return 0
    fi
    rm -f "$harness"
}

run_tests
