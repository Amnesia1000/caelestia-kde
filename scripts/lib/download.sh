#!/usr/bin/env bash
if [[ -z "${CAELESTIA_DOWNLOAD_SOURCED:-}" ]]; then
CAELESTIA_DOWNLOAD_SOURCED=1

file_sha256() {
    sha256sum "$1" | cut -d' ' -f1
}

fetch_asset() {
    local url="$1" dest="$2"
    shift 2
    curl -fsSL --connect-timeout 10 "$@" "$url" -o "$dest"
}

# with a warning.
verify_download() {
    local url="$1" file="$2" sidecar expected
    sidecar="$(mktemp)"
    if ! fetch_asset "$url.sha256" "$sidecar" 2>/dev/null; then
        rm -f "$sidecar"
        return 2
    fi
    expected="$(cut -d' ' -f1 < "$sidecar")"
    rm -f "$sidecar"
    [[ -n "$expected" ]] || return 2
    [[ "$expected" == "$(file_sha256 "$file")" ]]
}

# party's, where the absence of a hash is what the warning is for. The path is anchored to
is_own_release() {
    local url="$1"
    case "$url" in
        https://github.com/ladybug-me/*/releases/download/*) return 0 ;;
        *) return 1 ;;
    esac
}

archive_entries_are_safe() {
    local archive="$1" listing line mode name
    listing="$(tar -tvzf "$archive" 2>/dev/null)" || return 1

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        mode="${line%% *}"
        name="${line##* }"
        case "$mode" in
            *s*|*S*) return 1 ;;
        esac
        case "$name" in
            /*|../*|*/../*|*/..) return 1 ;;
        esac
    done <<< "$listing"
    return 0
}

fi
