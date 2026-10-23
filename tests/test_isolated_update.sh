#!/usr/bin/env bash
# suite: isolated

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

make_update_bundle() {
    local root="$1" log="$2" failing="${3:-}"
    mkdir -p "$root/scripts/lib" "$root/shell/scripts"
    cp "$REPO_ROOT/update.sh" "$root/update.sh"
    cp "$REPO_ROOT/scripts/lib/log.sh" "$REPO_ROOT/scripts/lib/privileges.sh" \
        "$REPO_ROOT/scripts/lib/install-fs.sh" "$REPO_ROOT/scripts/lib/submodules.sh" \
        "$root/scripts/lib/"

    for step in 03-deploy-configs.sh 08-build-shell.sh 09-system-tweaks.sh; do
        printf '#!/bin/bash\nprintf '\''%%s\\n'\'' '\''%s'\'' >> '\''%s'\''\n' \
            "${step%.sh}" "$log" > "$root/scripts/$step"
        if [[ "$step" == "$failing" ]]; then
            printf 'exit 7\n' >> "$root/scripts/$step"
        fi
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

test_an_install_from_before_the_wallpaper_engine_still_gets_it() {
    # update.sh never ran the packages step, so an install from before the skwd-wall
    # integration kept the shell's own wallpaper renderer for good. The engine has to be
    # ensured from the update path as well.
    local root home bin log status
    root="$(new_tmpdir)"
    home="$root/home"
    bin="$root/bin"
    log="$root/steps.log"
    mkdir -p "$home" "$bin" "$home/.runtime"
    make_update_bundle "$root" "$log"

    cat > "$root/scripts/lib/skwd-wall.sh" <<'EOF'
ensure_skwd_wall() {
    printf 'ensure_skwd_wall\n' >> "${SKWD_LOG:?}"
    return 0
}
EOF

    for command in git cmake make caelestia; do
        stub_bin "$bin" "$command" 'exit 0'
    done

    status="$(
        HOME="$home" XDG_STATE_HOME="$home/.local/state" XDG_RUNTIME_DIR="$home/.runtime" \
            SKWD_LOG="$root/skwd.log" PATH="$bin:$PATH" bash "$root/update.sh" > "$root/update.log" 2>&1
        printf '%s\n' "$?"
    )"

    assert_status 0 "$status" "the update should still succeed"
    assert_contains "$(cat "$root/skwd.log" 2>/dev/null)" "ensure_skwd_wall" \
        "the update must ensure the wallpaper engine, not leave the old renderer in place"
}

test_each_update_step_failure_stops_before_the_next_step() {
    local root home bin log failing next status calls
    for failing in 03-deploy-configs.sh 08-build-shell.sh 09-system-tweaks.sh; do
        root="$(new_tmpdir)"
        home="$root/home"
        bin="$root/bin"
        log="$root/steps.log"
        mkdir -p "$home" "$bin" "$home/.runtime"
        make_update_bundle "$root" "$log" "$failing"

        for command in git cmake make caelestia; do
            stub_bin "$bin" "$command" 'exit 0'
        done

        HOME="$home" XDG_STATE_HOME="$home/.local/state" XDG_RUNTIME_DIR="$home/.runtime" \
            PATH="$bin:$PATH" bash "$root/update.sh" > "$root/update.log" 2>&1
        status=$?
        if [[ "$failing" == "09-system-tweaks.sh" ]]; then
            assert_status 0 "$status" "$failing is intentionally non-fatal"
        else
            assert_status 1 "$status" "$failing should make the isolated update fail"
        fi
        calls="$(cat "$log")"
        assert_contains "$calls" "${failing%.sh}" "$failing should be reached before failure"

        case "$failing" in
            03-deploy-configs.sh) next="08-build-shell" ;;
            08-build-shell.sh) next="09-system-tweaks" ;;
            *) next="" ;;
        esac
        if [[ -n "$next" ]]; then
            assert_not_contains "$calls" "$next" "a failure in $failing must stop before $next"
        fi
    done
}

run_tests
