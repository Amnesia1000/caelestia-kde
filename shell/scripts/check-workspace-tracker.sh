#!/usr/bin/env bash

set -euo pipefail

# Without these there is no way to ask, and a missing tool must not be reported
command -v kreadconfig6 >/dev/null 2>&1 || exit 0
command -v qdbus6 >/dev/null 2>&1 || exit 0

enabled="$(kreadconfig6 --file kwinrc --group Plugins --key kwin_workspace_trackerEnabled 2>/dev/null || true)"
[[ "$enabled" == "true" ]] || exit 0

qdbus6 org.kde.KWin /Caelestia/Workspaces org.freedesktop.DBus.Introspectable.Introspect >/dev/null 2>&1 || exit 3

exit 0
