#!/usr/bin/env bash
if [[ -z "${CAELESTIA_DARKLY_SOURCED:-}" ]]; then
CAELESTIA_DARKLY_SOURCED=1

darkly_gtk_installed() {
    [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/themes/Darkly" ]] ||
    [[ -d "$HOME/.themes/Darkly" ]] ||
    [[ -d "/usr/share/themes/Darkly" ]]
}

install_darkly_gtk_theme() {
    local tmpdir status=0
    tmpdir="$(mktemp -d)"

    if git clone --depth 1 https://github.com/wrymt/darkly-gtk "$tmpdir"; then
        (cd "$tmpdir" || exit 1; ./install.sh -l) || {
            err "Failed to install Darkly GTK theme."
            status=1
        }
    else
        err "Failed to clone Darkly GTK theme."
        status=1
    fi

    rm -rf "$tmpdir"
    return "$status"
}

fi
