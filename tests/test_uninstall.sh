#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNINSTALL_SCRIPT="$REPO_ROOT/uninstall.sh"

nopasswd_sudo_stub() {
    local dir="$1" log="$2"
    stub_bin "$dir" sudo "
printf 'sudo %s\n' \"\$*\" >> '$log'
args=()
for arg in \"\$@\"; do
    case \"\$arg\" in
        -n|-A|-S|-v|--non-interactive) ;;
        -*) ;;
        *) args+=(\"\$arg\") ;;
    esac
done
if [ \${#args[@]} -eq 0 ]; then
    for arg in \"\$@\"; do
        if [ \"\$arg\" = -v ]; then
            printf 'sudo: a password is required\n' >&2
            exit 1
        fi
    done
    exit 0
fi
exec \"\${args[@]}\""
    printf '%s\n' "$dir/sudo"
}

make_uninstall_sandbox() {
    local tmp="$1"
    local home="$tmp/home"
    local bin="$tmp/bin"
    mkdir -p \
        "$home/.config/quickshell/caelestia" \
        "$home/.config/caelestia" \
        "$home/.config/Caelestia" \
        "$home/.config/systemd/user" \
        "$home/.config/environment.d" \
        "$home/.config/plasma-workspace/env" \
        "$home/.local/bin" \
        "$home/.local/lib/caelestia" \
        "$home/.local/lib/qt6/qml/Caelestia" \
        "$home/.local/lib/qt6/qml/M3Shapes" \
        "$home/.local/share/caelestia" \
        "$home/.local/share/applications" \
        "$home/.local/share/kwin/scripts/quickshell-kde-bridge" \
        "$home/.cache/Caelestia/caelestia-shell" \
        "$home/.cache/caelestia-shell" \
        "$home/.local/state/caelestia" \
        "$bin"

    printf '{"bar":{}}\n' > "$home/.config/caelestia/shell.json"
    printf '[]\n'          > "$home/.config/caelestia/keybinds.json"
    printf '{}\n'          > "$home/.config/caelestia/cli.json"
    printf '{"kwin":{}}\n' > "$home/.config/caelestia/stolen-shortcuts.json"
    printf '{"edges":{}}\n' > "$home/.config/caelestia/stolen-screen-edges.json"
    printf '{}\n'          > "$home/.config/Caelestia/caelestia-shell.conf"
    printf 'cache\n'       > "$home/.cache/Caelestia/caelestia-shell/qmlcache"
    printf 'cache\n'       > "$home/.cache/caelestia-shell/qmlcache"
    printf '# user bashrc\nexport PATH=$HOME/.local/bin:$PATH\n' > "$home/.bashrc"
    printf '#!/bin/sh\n' > "$home/.local/bin/caelestia"
    printf '# caelestia\n' > "$home/.config/environment.d/caelestia.conf"
    printf '#!/bin/sh\n' > "$home/.config/plasma-workspace/env/caelestia.sh"
    printf '[Desktop Entry]\nX-KDE-Wayland-Interfaces=x\n' \
        > "$home/.local/share/applications/quickshell.desktop"

    local name
    for name in systemctl pkill kwriteconfig6 kreadconfig6 kpackagetool6 \
                qdbus6 qdbus kbuildsycoca6 update-desktop-database lookandfeeltool \
                gpasswd udevadm pgrep dnf apt-get yay pacman rpm dpkg \
                fc-cache update-mime-database xdg-desktop-menu; do
        stub_bin "$bin" "$name" 'exit 0'
    done
    recording_stub "$bin" chsh "$tmp/chsh.log"
    stub_bin "$bin" getent "printf 'camus:x:1000:1000::/home/camus:/usr/bin/fish\n'"
    nopasswd_sudo_stub "$bin" "$tmp/sudo.log" >/dev/null
    printf '%s\n' "$bin"
}

run_uninstall_in_sandbox() {
    local tmp="$1"
    local home="$tmp/home" bin="$tmp/bin"

    (
        cd "$REPO_ROOT" || exit 1
        printf 'y\nn\nn\nn\n' \
            | env -i \
                HOME="$home" \
                PATH="$bin:/usr/bin:/bin" \
                TMPDIR="$tmp" \
                CAELESTIA_SUDO_PRIMED=1 \
                CAELESTIA_SUDO_BIN="$bin/sudo" \
                bash "$UNINSTALL_SCRIPT" >"$tmp/uninstall.log" 2>&1
    )
    printf '%s\n' "$?"
}

test_the_uninstaller_removes_stranded_shortcut_recovery_files() {
    local tmp status home
    tmp="$(new_tmpdir)"
    make_uninstall_sandbox "$tmp" >/dev/null
    home="$tmp/home"

    status="$(run_uninstall_in_sandbox "$tmp")"

    assert_status 0 "$status" "a plain uninstall should complete"

    assert_file_missing "$home/.config/caelestia/stolen-shortcuts.json"
    assert_file_missing "$home/.config/caelestia/stolen-screen-edges.json"
    assert_file_exists "$home/.config/caelestia/shell.json"
    assert_file_exists "$home/.config/caelestia/keybinds.json"
    assert_file_missing "$home/.cache/Caelestia"
    assert_file_missing "$home/.cache/caelestia-shell"
    assert_file_missing "$home/.config/Caelestia"
}

test_the_uninstaller_leaves_the_login_shell_alone_without_a_backup() {
    local tmp status
    tmp="$(new_tmpdir)"
    make_uninstall_sandbox "$tmp" >/dev/null

    status="$(run_uninstall_in_sandbox "$tmp")"
    assert_status 0 "$status" "a plain uninstall should complete"

    assert_eq "" "$(calls_to "$tmp/chsh.log" chsh)" \
        "chsh must not run without a recorded previous shell"
}

test_the_uninstaller_removes_the_installed_footprint() {
    local tmp status home
    tmp="$(new_tmpdir)"
    make_uninstall_sandbox "$tmp" >/dev/null
    home="$tmp/home"

    status="$(run_uninstall_in_sandbox "$tmp")"
    assert_status 0 "$status" "a plain uninstall should complete"

    assert_file_missing "$home/.config/quickshell/caelestia"
    assert_file_missing "$home/.local/lib/caelestia"
    assert_file_missing "$home/.local/lib/qt6/qml/Caelestia"
    assert_file_missing "$home/.local/lib/qt6/qml/M3Shapes"
    assert_file_missing "$home/.local/share/caelestia"
    assert_file_missing "$home/.local/bin/caelestia"
    assert_file_missing "$home/.config/environment.d/caelestia.conf"
    assert_file_missing "$home/.config/plasma-workspace/env/caelestia.sh"
    assert_file_missing "$home/.local/share/kwin/scripts/quickshell-kde-bridge"
    assert_file_missing "$home/.local/state/caelestia"
}

run_tests
