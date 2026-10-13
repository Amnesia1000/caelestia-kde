#!/bin/bash

set -euo pipefail

CAELESTIA_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
WALLPAPER_FILE="$CAELESTIA_STATE/wallpaper/path.txt"
SCHEME_FILE="$CAELESTIA_STATE/scheme.json"

if ! command -v caelestia >/dev/null 2>&1; then
    exit 0
fi

if [[ ! -s "$WALLPAPER_FILE" ]]; then
    exit 0
fi

WALLPAPER="$(<"$WALLPAPER_FILE")"
if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    exit 0
fi

CURRENT=""
if [[ -s "$SCHEME_FILE" ]] && command -v python3 >/dev/null 2>&1; then
    CURRENT="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("name", ""))' "$SCHEME_FILE" 2>/dev/null || true)"
fi
if [[ -n "$CURRENT" && "$CURRENT" != "dynamic" ]]; then
    exit 0
fi

scheme_mtime() {
    stat -c %Y "$SCHEME_FILE" 2>/dev/null || echo 0
}

before="$(scheme_mtime)"
timeout 10s caelestia scheme set -n dynamic "$@" >/dev/null 2>&1 || true

if [[ "$(scheme_mtime)" == "$before" ]]; then
    timeout 10s caelestia wallpaper -f "$WALLPAPER" "$@" >/dev/null 2>&1 || true
    timeout 10s caelestia scheme set -n dynamic "$@" >/dev/null 2>&1 || true
fi
