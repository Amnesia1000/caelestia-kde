#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$REPO_ROOT/shell/services/Accessibility.qml"
CONFIG="$REPO_ROOT/shell/plugin/src/Caelestia/Config/appearanceconfig.hpp"
PAGE="$REPO_ROOT/shell/modules/nexus/pages/services/AccessibilityPage.qml"
REGISTRY="$REPO_ROOT/shell/modules/nexus/PageCompRegistry.qml"
DICTIONARY="$REPO_ROOT/shell/modules/nexus/PageDictionary.qml"

test_shell_text_follows_kdes_font_size() {
    local config service
    config="$(cat "$CONFIG")"
    service="$(cat "$SERVICE")"

    assert_contains "$config" 'CONFIG_PROPERTY(bool, followSystemScale, true)' \
        "following KDE's text size has to be a setting"
    # kdeglobals stores "Family,11,-1,5,…": the point size is the second field.
    assert_contains "$service" '"kdeglobals", "--group", "General", "--key", "font"' \
        "the size has to be read from where KDE keeps it"
    assert_contains "$service" 'const size = parseInt((text.split(",")[1] ?? "").trim(), 10)' \
        "and be taken from the font entry"
    assert_contains "$service" 'const scale = points / root.basePointSize' \
        "an 11 pt default has to become 110%, not a delta"
    assert_contains "$service" 'root.systemPointSize = isNaN(size) || size <= 0 ? 0 : size' \
        "an absent key means KDE's default, not a zero scale"
    assert_contains "$service" 'if (!root.followSystem)' "the setting has to be honoured"
    assert_contains "$service" 'Math.abs(current - root.systemScale) < 0.005' \
        "the config must not be rewritten on every poll"
}

test_visual_helpers_drive_kwin_effects() {
    local service page
    service="$(cat "$SERVICE")"
    page="$(cat "$PAGE")"

    # These are KWin's own effect names; the shell only loads and unloads them.
    assert_contains "$service" 'for e in zoom invert colorblindnesscorrection' \
        "the effects to query have to be the ones KWin ships"
    assert_contains "$service" 'org.kde.kwin.Effects.${method}' "toggling must go through KWin's interface"
    assert_contains "$page" 'Accessibility.setEffect("zoom", checked)' "the magnifier must be switchable"
    assert_contains "$page" 'Accessibility.setEffect("invert", checked)' "so must inversion"
    assert_contains "$page" 'Accessibility.setEffect("colorblindnesscorrection", checked)' "and the filters"
    assert_contains "$page" 'qsTr("Reduce motion")' "reduced motion belongs on this page"
    assert_contains "$page" 'GlobalConfig.appearance.anim.enabled = !checked' \
        "reduced motion is the inverse of the animations switch"
}

test_screen_reader_is_offered_when_present() {
    local service page
    service="$(cat "$SERVICE")"
    page="$(cat "$PAGE")"

    assert_contains "$service" 'command -v orca' "availability has to be detected, not assumed"
    assert_contains "$service" 'Quickshell.execDetached(["orca"])' "starting it must not block the shell"
    assert_contains "$page" 'enabled: Accessibility.screenReaderInstalled' \
        "the button must not be offered when it cannot work"
}

test_accessibility_page_is_a_top_level_page() {
    local page registry dictionary
    page="$(cat "$PAGE")"
    registry="$(cat "$REGISTRY")"
    dictionary="$(cat "$DICTIONARY")"

    assert_contains "$page" 'title: qsTr("Accessibility")' "the page needs its own title"
    assert_contains "$registry" 'Component { AccessibilityPage {} }' "the page must be registered"
    assert_contains "$dictionary" 'key: "accessibility"' "and listed in the settings index"
    assert_not_contains "$page" 'isSubPage: true' "it is a top level page, not a sub page"
}

run_tests
