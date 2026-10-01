#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$REPO_ROOT/shell/services/Uninstaller.qml"
DIALOG="$REPO_ROOT/shell/modules/nexus/common/UninstallDialog.qml"
ABOUT="$REPO_ROOT/shell/modules/nexus/pages/AboutPage.qml"
CAELESTIA_CLI="$REPO_ROOT/src/bin/caelestia"

extract_probe_command() {
    python3 - "$SERVICE" <<'PYEOF'
import re, sys
text = open(sys.argv[1]).read()
match = re.search(r'command:\s*\["sh",\s*"-c",\s*`(.*?)`,\s*"--"', text, re.S)
if not match:
    sys.exit(1)
sys.stdout.write(match.group(1))
PYEOF
}

test_the_service_searches_the_same_checkout_caelestia_uses() {
    local service
    service="$(cat "$SERVICE")"

    assert_contains "$service" 'Quickshell.env("CAELESTIA_DIR")' \
        "an explicit checkout should win"
    assert_contains "$service" '"/caelestia-kde/uninstall.sh"' \
        "the default the installer's own command falls back to should be searched"

    assert_contains "$(cat "$CAELESTIA_CLI")" 'CHECKOUT="$HOME/caelestia-kde"' \
        "the CLI and the button should agree on the default checkout"
}

test_the_service_offers_a_package_managers_command() {
    local service
    service="$(cat "$SERVICE")"

    assert_contains "$service" 'command -v pacman' "the Arch manager should be asked for"
    assert_contains "$service" 'command -v dnf' "the Fedora manager should be asked for"
    assert_contains "$service" 'command -v apt-get' "the Debian manager should be asked for"
    assert_contains "$service" 'caelestia-kde' "the package name should be named"
}

test_the_uninstaller_runs_in_a_terminal() {
    local service
    service="$(cat "$SERVICE")"

    assert_contains "$service" "GlobalConfig.general.apps.terminal" \
        "the script should run in the configured terminal"
    assert_contains "$service" "wrap_term_launch.sh" \
        "and through the same wrapper a terminal launch uses"
}

test_the_dialog_only_offers_to_run_a_script_that_exists() {
    local dialog
    dialog="$(cat "$DIALOG")"

    assert_contains "$dialog" "Uninstaller.scriptFound" \
        "the dialog should read whether a script was found"
    assert_contains "$dialog" "Uninstaller.launch()" \
        "and launch it when it has"
    assert_contains "$dialog" "visible: root.canRun" \
        "the run button should follow what was found"
}

test_the_page_offers_the_action() {
    local about
    about="$(cat "$ABOUT")"

    assert_contains "$about" "Uninstaller" "the About page should reach the service"
    assert_contains "$about" "UninstallDialog" "and open the confirmation"
}

test_the_probe_finds_a_script_and_nothing_else() {
    local command tmp body
    command="$(extract_probe_command)" || {
        fail "the probe command could not be read out of the service"
        return 0
    }

    tmp="$(new_tmpdir)"

    mkdir -p "$tmp/checkout"
    printf '#!/usr/bin/env bash\n' > "$tmp/checkout/uninstall.sh"
    body="$(sh -c "$command" -- "$tmp/checkout/uninstall.sh" "$tmp/absent/uninstall.sh" 2>&1)"
    assert_contains "$body" "SCRIPT $tmp/checkout/uninstall.sh" \
        "the first existing candidate should be reported"
    assert_not_contains "$body" "MANUAL" "no fallback should be printed when a script was found"

    body="$(sh -c "$command" -- "$tmp/absent/uninstall.sh" 2>&1)"
    assert_contains "$body" "MANUAL" "a missing script should report the manual path"
    assert_eq "1" "$(printf '%s\n' "$body" | grep -c '^MANUAL')" \
        "exactly one manual line should be printed"
}

run_tests
