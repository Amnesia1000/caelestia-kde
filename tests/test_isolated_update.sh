#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

make_update_bundle() {
    local root="$1" log="$2"
    mkdir -p "$root/scripts/lib" "$root/shell/scripts"
    cp "$REPO_ROOT/update.sh" "$root/update.sh"
    cp "$REPO_ROOT/scripts/lib/log.sh" "$REPO_ROOT/scripts/lib/privileges.sh" \
        "$REPO_ROOT/scripts/lib/install-fs.sh" "$REPO_ROOT/scripts/lib/submodules.sh" \
        "$root/scripts/lib/"

    for step in 03-deploy-configs.sh 08-build-shell.sh 09-system-tweaks.sh; do
        printf '#!/bin/bash\nprintf '\''%%s\\n'\'' '\''%s'\'' >> '\''%s'\''\n' \
            "${step%.sh}" "$log" > "$root/scripts/$step"
        chmod +x "$root/scripts/$step"
    done

    cat > "$root/shell/scripts/restart_shell.sh" <<EOF
#!/bin/bash
mkdir -p "\${XDG_STATE_HOME}/caelestia"
printf 'ready\\n' > "\${XDG_STATE_HOME}/caelestia/scheme.json"
EOF
    chmod +x "$root/shell/scripts/restart_shell.sh"
}

test_update_runs_twice_in_an_isolated_home() {
    local root home bin log calls status expected
    root="$(new_tmpdir)"
    home="$root/home"
    bin="$root/bin"
    log="$root/steps.log"
    mkdir -p "$home" "$bin" "$home/.runtime"
    make_update_bundle "$root" "$log"

    for command in git cmake make caelestia; do
        stub_bin "$bin" "$command" 'exit 0'
    done

    status="$(
        HOME="$home" XDG_STATE_HOME="$home/.local/state" XDG_RUNTIME_DIR="$home/.runtime" \
            PATH="$bin:$PATH" bash "$root/update.sh" > "$root/first.log" 2>&1
        printf '%s\n' "$?"
    )"
    assert_status 0 "$status" "the first isolated update should succeed"

    status="$(
        HOME="$home" XDG_STATE_HOME="$home/.local/state" XDG_RUNTIME_DIR="$home/.runtime" \
            PATH="$bin:$PATH" bash "$root/update.sh" > "$root/second.log" 2>&1
        printf '%s\n' "$?"
    )"
    assert_status 0 "$status" "the repeated isolated update should succeed"

    calls="$(cat "$log")"
    expected=$'03-deploy-configs\n08-build-shell\n09-system-tweaks\n03-deploy-configs\n08-build-shell\n09-system-tweaks'
    assert_eq "$expected" "$calls" "update should run its core steps in order on both runs"
    assert_file_exists "$home/.local/state/caelestia/scheme.json"
}

run_tests
