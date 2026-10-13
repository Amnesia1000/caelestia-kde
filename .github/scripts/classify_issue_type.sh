#!/usr/bin/env bash

set -euo pipefail

LABEL_BUG="bug"
LABEL_FEATURE="feature"
LABEL_HELP="help me"

LABEL_FALLBACK="$LABEL_HELP"

TEMPLATE_BUG_TEXT="bug - something is broken"
TEMPLATE_HELP_TEXT="help wanted - i need assistance"

emit() {
    printf '%s\n' "$1" >&2
    printf '%s\n' "$2"
    return 0
}

checked_options() {
    local body="$1" lines
    lines="$(printf '%s\n' "$body" | grep -Ei '^[[:space:]]*[-*][[:space:]]*\[[xX]\]' || true)"
    printf '%s' "${lines,,}"
}

title_tag() {
    local title="$1" head

    if [[ "$title" == \[*\]* ]]; then
        head="${title#\[}"
        printf '%s' "${head%%\]*}"
        return 0
    fi

    if [[ "$title" == *:* ]]; then
        head="${title%%:*}"
        head="${head%%(*}"
        if [[ "$head" =~ ^[a-z]+$ ]]; then
            printf '%s' "$head"
            return 0
        fi
    fi

    return 1
}

label_for_tag() {
    case "$1" in
        bug | bugs | bugfix | defect | fix | fixes | regression | crash)
            printf '%s\n' "$LABEL_BUG"
            ;;
        feature | features | feat | enhancement | fr | request | "feature request")
            printf '%s\n' "$LABEL_FEATURE"
            ;;
        help | "help needed" | "help wanted" | question | support | assistance | "how to" | howto)
            printf '%s\n' "$LABEL_HELP"
            ;;
        *)
            return 1
            ;;
    esac
}

label_for_title_keywords() {
    case "$1" in
        *crash* | *broken* | *broke* | *"not working"* | *"doesn't work"* | *"does not work"* | *"won't work"* | \
            *freeze* | *frozen* | *hang* | *fail* | *error* | *regression* | *stuck* | *"no longer"* | \
            *silently* | *flicker* | *unresponsive* | *segfault*)
            printf '%s\n' "$LABEL_BUG"
            ;;
        *"feature request"* | *enhancement* | *"please add"* | *"add support"* | *"support for"* | \
            *"would be nice"* | *"ability to"* | *"add a "* | *"add an "*)
            printf '%s\n' "$LABEL_FEATURE"
            ;;
        *"how do i"* | *"how to"* | *question* | *help*)
            printf '%s\n' "$LABEL_HELP"
            ;;
        *)
            return 1
            ;;
    esac
}

main() {
    if [[ $# -ne 1 ]]; then
        printf 'usage: %s "<issue title>"   # issue body on stdin\n' "${0##*/}" >&2
        return 2
    fi

    local title="${1,,}" body checked tag label
    body="$(cat)"
    checked="$(checked_options "$body")"

    if [[ "$checked" == *"$TEMPLATE_BUG_TEXT"* ]]; then
        emit "issue form: bug option ticked" "$LABEL_BUG"
        return 0
    fi

    if [[ "$checked" == *"$TEMPLATE_HELP_TEXT"* ]]; then
        emit "issue form: help option ticked" "$LABEL_HELP"
        return 0
    fi

    if tag="$(title_tag "$title")" && label="$(label_for_tag "$tag")"; then
        emit "title tag [$tag]" "$label"
        return 0
    fi

    if label="$(label_for_title_keywords "$title")"; then
        emit "title keyword" "$label"
        return 0
    fi

    emit "no signal: falling back so the issue is never left untyped" "$LABEL_FALLBACK"
}

main "$@"
