#!/usr/bin/env bash
if [[ -z "${CAELESTIA_PACKAGES_SOURCED:-}" ]]; then
CAELESTIA_PACKAGES_SOURCED=1

detect_base_distro() {
    local detected="unknown"
    local os_release="${CAELESTIA_OS_RELEASE:-/etc/os-release}"

    if [[ -n "${BASE_DISTRO:-}" ]]; then
        printf '%s\n' "$BASE_DISTRO"
        return 0
    fi

    if [[ -f "$os_release" ]]; then
        . "$os_release"
        case "${ID:-}" in
            arch|cachyos|endeavouros|manjaro|artix)
                detected="arch"
                ;;
            fedora|nobara|bazzite|rhel|centos|almalinux|rocky)
                detected="fedora"
                ;;
            debian|ubuntu|pop|mint|kali|raspbian|elementary|zorin|deepin|devuan)
                detected="debian"
                ;;
            *)
                if echo "${ID_LIKE:-}" | grep -iq "arch"; then
                    detected="arch"
                elif echo "${ID_LIKE:-}" | grep -iq "fedora"; then
                    detected="fedora"
                elif echo "${ID_LIKE:-}" | grep -iq -E "debian|ubuntu"; then
                    detected="debian"
                fi
                ;;
        esac
    fi

    if [[ "$detected" == "unknown" ]]; then
        if command -v pacman >/dev/null 2>&1; then
            detected="arch"
        elif command -v dnf >/dev/null 2>&1; then
            detected="fedora"
        elif command -v apt-get >/dev/null 2>&1; then
            detected="debian"
        fi
    fi

    printf '%s\n' "$detected"
}

export BASE_DISTRO="$(detect_base_distro)"

package_present() {
    local pkg="$1"
    case "$BASE_DISTRO" in
        arch) pacman -Qq "$pkg" >/dev/null 2>&1 ;;
        fedora) rpm -q "$pkg" >/dev/null 2>&1 ;;
        debian) dpkg -s "$pkg" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

filter_missing() {
    local pkg
    for pkg in "$@"; do
        package_present "$pkg" || printf '%s\n' "$pkg"
    done
}

filter_installed() {
    local pkg
    for pkg in "$@"; do
        package_present "$pkg" && printf '%s\n' "$pkg"
    done
}

record_failed_package() {
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
    mkdir -p "$dir"
    printf '%s\n' "$1" >> "$dir/failed_packages.txt"
}

package_install() {
    local pkg="$1"
    local -a confirm=()
    [[ -n "${CONFIRM_ARG:-}" ]] && confirm=("$CONFIRM_ARG")

    case "$BASE_DISTRO" in
        arch)
            yay -S --needed "${confirm[@]}" "$pkg" 2>/dev/null ||
                caelestia_sudo pacman -S --needed "${confirm[@]}" "$pkg" 2>/dev/null
            ;;
        fedora)
            caelestia_sudo dnf install -y "$pkg" 2>/dev/null
            ;;
        debian)
            caelestia_sudo apt-get install -y "$pkg" 2>/dev/null
            ;;
        *)
            warn "No package manager is known for '$BASE_DISTRO'; cannot install $pkg."
            return 1
            ;;
    esac
}

install_if_missing() {
    local pkg
    local -a failed=()

    for pkg in "$@"; do
        if package_present "$pkg"; then
            skip "$pkg already installed."
            return 0
        fi

        info "Installing $pkg..."
        if package_install "$pkg"; then
            ok "$pkg installed."
            return 0
        fi

        warn "Could not install $pkg, skipping."
        failed+=("$pkg")
    done

    for pkg in "${failed[@]}"; do
        record_failed_package "$pkg"
    done
    return 1
}

fi
