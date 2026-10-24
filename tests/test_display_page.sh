#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$REPO_ROOT/shell/services/Displays.qml"
PAGE="$REPO_ROOT/shell/modules/nexus/pages/DisplayPage.qml"
MODES="$REPO_ROOT/shell/modules/nexus/pages/display/DisplayModesPage.qml"
DICTIONARY="$REPO_ROOT/shell/modules/nexus/PageDictionary.qml"
REGISTRY="$REPO_ROOT/shell/modules/nexus/PageCompRegistry.qml"
STATE="$REPO_ROOT/shell/modules/nexus/NexusState.qml"

test_kscreen_is_the_only_owner_of_the_layout() {
    local service
    service="$(cat "$SERVICE")"

    assert_contains "$service" 'command: ["kscreen-doctor", "-j"]' \
        "the shell reads the layout from KScreen"
    assert_contains "$service" 'writeProcess.command = ["kscreen-doctor", ...settings]' \
        "and asks KScreen to change it, instead of keeping a second copy"
    assert_contains "$service" 'onExited: root.refresh()' \
        "every change has to be read back, so the page shows what really happened"
    assert_contains "$service" 'root.outputs = []' "an unreadable layout must not look like an empty one"
    assert_contains "$service" 'root.failed = true' "and has to be reported"
}

test_output_settings_map_onto_the_kscreen_cli() {
    local service
    service="$(cat "$SERVICE")"

    assert_contains "$service" '`output.${name}.${on ? "enable" : "disable"}`' "enabling an output"
    assert_contains "$service" '`output.${name}.mode.${modeId}`' "setting a mode"
    assert_contains "$service" '`output.${name}.scale.${scale}`' "setting the scale"
    assert_contains "$service" '`output.${name}.rotation.${rotation}`' "setting the rotation"
    assert_contains "$service" '`output.${name}.hdr.${on ? "enable" : "disable"}`' "setting HDR"
    assert_contains "$service" 'return root.rotationNames[Math.log2(rotation)] ?? "none"' \
        "KScreen reports the rotation as a bit flag, so it has to be named"
    assert_contains "$service" 'function modesFor(output: var): var' \
        "modes are offered largest and fastest first"
}

test_the_page_is_driven_by_the_service() {
    local page
    page="$(cat "$PAGE")"

    assert_contains "$page" 'model: Displays.connected' "one section per connected screen"
    assert_contains "$page" 'Displays.setEnabled(outputSection.modelData.name, checked)' "enabled switch"
    assert_contains "$page" 'Displays.setScale(outputSection.modelData.name, Number(item.value))' "scale menu"
    assert_contains "$page" 'Displays.setRotation(outputSection.modelData.name, item.value)' "rotation menu"
    assert_contains "$page" 'Displays.setHdr(outputSection.modelData.name, checked)' "HDR switch"
    assert_contains "$page" 'enabled: Displays.enabled.length > 1 || !outputSection.modelData.enabled' \
        "the last enabled screen cannot be switched off"
    assert_contains "$page" 'fallbackText:' "a scale or rotation outside the menu still shows the truth"
    assert_contains "$page" 'Launch.exec(["systemsettings", "kcm_touchpad"])' \
        "input settings stay with the KCM that owns them"
    assert_contains "$page" 'Launch.exec(["systemsettings", "kcm_keyboard"])' "and so does the keyboard"
}

test_the_mode_list_marks_and_applies() {
    local modes
    modes="$(cat "$MODES")"

    assert_contains "$modes" 'model: root.modes' "every mode of the selected output"
    assert_contains "$modes" 'function isCurrent(mode: var): bool' "the current one has to be recognisable"
    assert_contains "$modes" 'Displays.setMode(root.output.name, String(modeRow.modelData.id))' "applying a mode"
    assert_contains "$modes" 'root.nState.closeSubPage()' "and returning to the screen it came from"
}

test_the_page_is_registered_next_to_its_neighbours() {
    local dictionary registry state
    dictionary="$(cat "$DICTIONARY")"
    registry="$(cat "$REGISTRY")"
    state="$(cat "$STATE")"

    assert_contains "$dictionary" 'key: "displays"' "the page has to exist in the dictionary"
    assert_contains "$dictionary" 'category: "connectivity"' "and sit with the hardware pages"
    assert_contains "$dictionary" 'function pageIdxFor(key: string): int' \
        "page positions are looked up, never remembered"
    assert_contains "$registry" 'Component { DisplayPage {} }' "the page has to be registered"
    assert_contains "$registry" 'Component { DisplayModesPage {} }' "with its mode list"
    assert_contains "$state" 'property string selectedOutput' "the mode list needs to know which screen it edits"

    local dictionary_bluetooth dictionary_displays dictionary_audio
    dictionary_bluetooth="$(grep -n 'key: "bluetooth"' "$DICTIONARY" | cut -d: -f1)"
    dictionary_displays="$(grep -n 'key: "displays"' "$DICTIONARY" | cut -d: -f1)"
    dictionary_audio="$(grep -n 'key: "audio"' "$DICTIONARY" | cut -d: -f1)"
    assert_eq "yes" "$([ "$dictionary_bluetooth" -lt "$dictionary_displays" ] && [ "$dictionary_displays" -lt "$dictionary_audio" ] && echo yes)" \
        "displays belong between the connected devices and audio"

    # The registry is positional: its Nth stack is the Nth page of the dictionary.
    local registry_bluetooth registry_displays registry_audio
    registry_bluetooth="$(grep -n 'key: "bluetoothPairing"' "$REGISTRY" | cut -d: -f1)"
    registry_displays="$(grep -n 'key: "displays"' "$REGISTRY" | cut -d: -f1)"
    registry_audio="$(grep -n 'key: "audio"' "$REGISTRY" | cut -d: -f1)"
    assert_eq "yes" "$([ "$registry_bluetooth" -lt "$registry_displays" ] && [ "$registry_displays" -lt "$registry_audio" ] && echo yes)" \
        "and the registry has to keep that order"
}

run_tests