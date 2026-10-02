#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/install-fs.sh"

test_validate_install_manifest_accepts_a_complete_tree() {
    local tmp status
    tmp="$(new_tmpdir)"
    mkdir -p "$tmp/root/usr/bin"
    : > "$tmp/root/usr/bin/app"
    printf '# a comment\n\n/usr/bin/app\n' > "$tmp/manifest.txt"

    validate_install_manifest "$tmp/manifest.txt" "$tmp/root"
    status=$?

    assert_status 0 "$status" "a manifest whose paths all exist should pass"
}

test_validate_install_manifest_rejects_a_missing_path() {
    local tmp status
    tmp="$(new_tmpdir)"
    mkdir -p "$tmp/root/usr/bin"
    : > "$tmp/root/usr/bin/app"
    printf '/usr/bin/app\n/usr/bin/absent\n' > "$tmp/manifest.txt"

    validate_install_manifest "$tmp/manifest.txt" "$tmp/root" 2>/dev/null
    status=$?

    assert_status 1 "$status" "a manifest referencing a missing path should fail"
}

test_validate_install_manifest_rejects_a_missing_manifest() {
    local tmp status
    tmp="$(new_tmpdir)"

    validate_install_manifest "$tmp/absent.txt" "$tmp/root" 2>/dev/null
    status=$?

    assert_status 1 "$status" "a missing manifest should fail"
}

test_validate_install_manifest_checks_absolute_entries_without_a_root() {
    local tmp status
    tmp="$(new_tmpdir)"
    : > "$tmp/app"
    printf '%s\n' "$tmp/app" > "$tmp/manifest.txt"

    validate_install_manifest "$tmp/manifest.txt"
    status=$?

    assert_status 0 "$status" "with no root the absolute entries should be checked as-is"
}

run_tests
