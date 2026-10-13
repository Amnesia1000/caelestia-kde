#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

RULES_FILE="kwinrulesrc"
RULES_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/$RULES_FILE"
RULE_GROUPS=(caelestia-opacity caelestia-dialogs caelestia-pip)
RULE_INDEX=""
RULE_INDEX_COUNT=0
WINDOW_OPACITY="${WINDOW_OPACITY:-95}"
RULE_WRITES=0
RULE_FAILURES=0

set_rule_key() {
    local group="$1" key="$2" value="$3" outcome_var="$4" current confirmed
    current="$(kreadconfig6 --file "$RULES_FILE" --group "$group" --key "$key" 2>/dev/null || true)"
    if [[ "$current" == "$value" ]]; then
        printf -v "$outcome_var" '%s' "unchanged"
    else
        kwriteconfig6 --file "$RULES_FILE" --group "$group" --key "$key" "$value" 2>/dev/null || true
        confirmed="$(kreadconfig6 --file "$RULES_FILE" --group "$group" --key "$key" 2>/dev/null || true)"
        if [[ "$confirmed" == "$value" ]]; then
            printf -v "$outcome_var" '%s' "written"
        else
            printf -v "$outcome_var" '%s' "failed"
        fi
    fi
}

apply_rule_group() {
    local group="$1" label="$2"
    shift 2
    local outcome="" written=0 failed=0
    while [[ $# -ge 2 ]]; do
        set_rule_key "$group" "$1" "$2" outcome
        case "$outcome" in
            written) written=$((written + 1)) ;;
            failed) failed=$((failed + 1)) ;;
        esac
        shift 2
    done
    RULE_WRITES=$((RULE_WRITES + written))
    RULE_FAILURES=$((RULE_FAILURES + failed))

    if (( failed > 0 )); then
        warn "$failed of $((written + failed)) key(s) for $label could not be written."
    elif (( written > 0 )); then
        ok "Applied $label."
    else
        skip "$label already in place."
    fi
}

list_rule_groups() {
    local path="$1"
    [[ -f "$path" ]] || return 0
    awk '
        /^[[:space:]]*\[/ {
            name = $0
            sub(/^[[:space:]]*\[/, "", name)
            sub(/\].*$/, "", name)
            if (name != "" && name != "General" && substr(name, 1, 1) != "$") {
                print name
            }
        }
    ' "$path"
}

trim_rule_name() {
    local name="$1"
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    printf '%s' "$name"
}

add_to_rule_index() {
    local name="$1"
    [[ -n "$name" ]] || return 0
    case ",$RULE_INDEX," in
        *",$name,"*) return 0 ;;
    esac
    RULE_INDEX="${RULE_INDEX:+$RULE_INDEX,}$name"
    RULE_INDEX_COUNT=$((RULE_INDEX_COUNT + 1))
}

build_rule_index() {
    local current="$1" groups="$2" name
    RULE_INDEX=""
    RULE_INDEX_COUNT=0
    while IFS= read -r name; do
        add_to_rule_index "$(trim_rule_name "$name")"
    done <<< "$(printf '%s' "$current" | tr ',' '\n')"
    while IFS= read -r name; do
        add_to_rule_index "$name"
    done <<< "$groups"
    for name in "${RULE_GROUPS[@]}"; do
        add_to_rule_index "$name"
    done
}

echo
echo ""
info "Applying KWin window rules"
echo ""

if [[ "${APPLY_WINDOW_RULES:-true}" == "true" ]]; then
    if ! command -v kwriteconfig6 >/dev/null 2>&1; then
        warn "kwriteconfig6 not found - skipping window rules."
        exit 0
    fi

    apply_rule_group "caelestia-opacity" "window opacity" \
        Description "Caelestia: window opacity" \
        types 33 \
        opacityinactive "$WINDOW_OPACITY" \
        opacityinactiverule 2

    apply_rule_group "caelestia-dialogs" "dialog centering" \
        Description "Caelestia: center dialogs" \
        types 32 \
        placement 5 \
        placementrule 2

    apply_rule_group "caelestia-pip" "picture-in-picture pin" \
        Description "Caelestia: pin picture-in-picture" \
        title "Picture(-| )in(-| )[Pp]icture" \
        titlematch 3 \
        above true \
        aboverule 2

    build_rule_index \
        "$(kreadconfig6 --file "$RULES_FILE" --group General --key rules 2>/dev/null || true)" \
        "$(list_rule_groups "$RULES_PATH")"
    apply_rule_group "General" "the rule index" \
        rules "$RULE_INDEX" \
        count "$RULE_INDEX_COUNT"

    if command -v qdbus6 >/dev/null 2>&1; then
        qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
    else
        warn "qdbus6 not found - KWin picks the rules up on its next restart."
    fi

    if (( RULE_FAILURES > 0 )); then
        warn "Window rules not fully applied: $RULE_FAILURES key(s) rejected, $RULE_WRITES written."
    elif (( RULE_WRITES > 0 )); then
        ok "Window rules applied."
    else
        skip "Window rules already in place."
    fi
    info "Rule index names $RULE_INDEX_COUNT group(s)."
else
    skip "Skipping window rules"
fi
