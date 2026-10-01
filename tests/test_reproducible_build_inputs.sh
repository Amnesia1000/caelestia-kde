#!/usr/bin/env bash

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMAKE_FILE="$ROOT/shell/CMakeLists.txt"
FETCH_SCRIPT="$ROOT/scripts/fetch-dependencies.sh"
MAKEFILE="$ROOT/Makefile"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

grep -Fq 'set(M3SHAPES_REV bdc327b29f95394a732baf3c9b19658ba23755b6)' "$CMAKE_FILE" \
    || fail "CMake must pin the M3Shapes revision"
grep -Fq 'option(CAELESTIA_OFFLINE "Disallow downloading build dependencies" OFF)' "$CMAKE_FILE" \
    || fail "CMake must expose an offline build mode"
grep -Fq 'CAELESTIA_M3SHAPES_SOURCE_DIR' "$CMAKE_FILE" \
    || fail "CMake must accept a pre-fetched dependency directory"
grep -Fq 'Offline build requested' "$CMAKE_FILE" \
    || fail "offline configure must fail when the dependency is absent"
grep -Fq 'M3SHAPES_REV="bdc327b29f95394a732baf3c9b19658ba23755b6"' "$FETCH_SCRIPT" \
    || fail "the fetch command must use the same pinned revision"
grep -Fq 'fetch-dependencies:' "$MAKEFILE" \
    || fail "make must expose the dependency-fetch command"

echo "PASS: reproducible build inputs are pinned and have an offline path"