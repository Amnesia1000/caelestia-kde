#!/usr/bin/env bash

record_installed_revision() {
    local bundle="$1" config="$2"

    if [[ "${CAELESTIA_SKIP_BUILD:-0}" == "1" ]]; then
        return 1
    fi

    if [[ ! -d "$bundle/.git" ]]; then
        return 1
    fi

    mkdir -p -- "$config" || return 1

    # A checkout parked on a feature branch must not silently re-point the
    local branch
    branch="$(git -C "$bundle" rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch=""
    case "$branch" in
        main | dev)
            update_state_set_branch "$config" "$branch" || return 1
            ;;
    esac

    git -C "$bundle" rev-parse HEAD > "$config/.current_commit" 2>/dev/null || {
        rm -f -- "$config/.current_commit"
        return 1
    }

    printf '%s\n' "$bundle" > "$config/.checkout" 2>/dev/null || true

    if [[ -f "$bundle/.github/version.env" ]]; then
        cp -- "$bundle/.github/version.env" "$config/.current_version" 2>/dev/null || true
    else
        git -C "$bundle" show HEAD:.github/version.env > "$config/.current_version" 2>/dev/null || true
    fi

    return 0
}

update_state_set_branch() {
    local config="$1" branch="$2"

    case "$branch" in
        main | dev) ;;
        *) return 1 ;;
    esac

    mkdir -p -- "$config" || return 1
    printf '%s\n' "$branch" > "$config/.update_branch" || return 1
    return 0
}

update_state_read_branch() {
    local config="$1" branch=""
    branch="$(cat "$config/.update_branch" 2>/dev/null)" || branch=""
    case "$branch" in
        main | dev)
            printf '%s\n' "$branch"
            ;;
        *)
            printf 'main\n'
            ;;
    esac
}

update_state_read_commit() {
    local config="$1"
    cat "$config/.current_commit" 2>/dev/null || true
}
