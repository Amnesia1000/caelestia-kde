#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KDE_SCRIPT="$REPO_ROOT/scripts/04-deploy-kde.sh"

# The install step writes the unit from this function, so the test drives the real
# thing against a throwaway HOME rather than matching text in the script.
UNIT_SOURCE="$(extract_function "$KDE_SCRIPT" write_cliphist_unit)"

if [[ -z "$UNIT_SOURCE" ]]; then
    fail "could not find write_cliphist_unit in scripts/04-deploy-kde.sh"
    run_tests
    exit 1
fi

# The step scripts log through lib/log.sh, which this harness does not source.
LOG_STUBS='
ok() { :; }
info() { :; }
warn() { :; }
skip() { :; }
'

write_unit() {
    local home="$1"
    HOME="$home" bash -c "${LOG_STUBS}${UNIT_SOURCE}
write_cliphist_unit" 2>&1
}

unit_path() {
    printf '%s\n' "$1/.config/systemd/user/cliphist.service"
}

# The --all-mime-type-regex argument as systemd hands it to bash, quotes stripped.
unit_filter() {
    sed -n 's/.*--all-mime-type-regex "\(.*\)" & wait -n.*/\1/p' "$1"
}

have_python() {
    if command -v python3 >/dev/null 2>&1; then
        return 0
    fi
    skip_test "python3 not installed"
    return 1
}

# Judges the filter with a real regex engine against "expected=mime-type" pairs.
filter_verdicts() {
    local filter="$1"
    shift
    python3 - "$filter" "$@" <<'PYEOF'
import re
import sys

pattern, pairs = sys.argv[1], sys.argv[2:]
try:
    regex = re.compile(pattern)
except re.error as err:
    print(f"the filter is not a regex a regex engine can compile: {err}")
    sys.exit(1)

wrong = []
for pair in pairs:
    wanted, mime = pair.split("=", 1)
    matches = "yes" if regex.match(mime) else "no"
    if matches != wanted:
        wrong.append(f"{mime} (wanted {wanted}, got {matches})")
if wrong:
    print("filter verdict wrong for: " + ", ".join(wrong))
    sys.exit(1)
PYEOF
}

test_the_generated_unit_keeps_history_and_persistence() {
    local home unit
    home="$(new_tmpdir)"
    write_unit "$home" >/dev/null
    unit="$(cat "$(unit_path "$home")")"

    assert_contains "$unit" 'ExecStart=/bin/bash -c' "the unit still runs the helpers through bash"
    assert_contains "$unit" 'wl-paste --type text --watch cliphist store' "text history keeps being recorded"
    assert_contains "$unit" 'wl-paste --type image --watch cliphist store' "image history keeps being recorded"
    assert_contains "$unit" 'wl-clip-persist --clipboard regular' "the clipboard still persists across app exits"
    assert_contains "$unit" 'wait -n' "and a dying helper still takes the unit down"
    assert_contains "$unit" 'Restart=always' "which the unit recovers from"
    assert_contains "$unit" 'WantedBy=default.target' "the unit is still wanted by the default target"
}

test_private_formats_are_left_to_their_owner() {
    have_python || return 0

    local home filter output status
    home="$(new_tmpdir)"
    write_unit "$home" >/dev/null
    filter="$(unit_filter "$(unit_path "$home")")"

    assert_ne "" "$filter" "wl-clip-persist should be told which selection events to leave alone"

    output="$(filter_verdicts "$filter" \
        "no=application/x-krita-node-internal-pointer" \
        "no=application/x-krita-krita-node-data" \
        "no=image/x-inkscape-svg" \
        "yes=text/plain" \
        "yes=text/plain;charset=utf-8" \
        "yes=UTF8_STRING" \
        "yes=image/png" \
        "yes=application/zip")"
    status=$?

    assert_status 0 "$status" "the filter should skip only the private formats ($output)"
}

test_the_step_still_installs_and_starts_the_unit() {
    local script calls
    script="$(cat "$KDE_SCRIPT")"

    calls="$(printf '%s\n' "$script" | grep -c '^write_cliphist_unit')"
    assert_eq "2" "$calls" "the step should define the unit writer and call it once"
    assert_contains "$script" 'systemctl --user daemon-reload' "the unit still gets reloaded"
    assert_contains "$script" 'systemctl --user enable --now cliphist.service' "and still gets started"
}

run_tests
