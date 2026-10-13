#!/usr/bin/env bash
# suite: isolated

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$REPO_ROOT/src/bin/caelestia-update"
BASH_BIN="$(command -v bash)"

TEST_ROOT="$(new_tmpdir)"
mkdir -p "$TEST_ROOT/tmp"
FIXTURE_REMOTE=""

require_tools() {
    local tool
    for tool in git tar; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            skip_test "$tool is not installed"
            return 1
        fi
    done
    return 0
}

REQUIRED_IN_CHECKOUT=(
    assets/org.quickshell.desktop
    scripts/03-deploy-configs.sh
    scripts/lib/install-fs.sh
    src/bin/caelestia
    src/matugen
    src/dots/starship.toml
    shell/CMakeLists.txt
    installer/tui/CMakeLists.txt
    .github/version.env
    .gitmodules
    uninstall.sh
)

seed_submodule() {
    local remote="$1" file="$2" work="$1.work"

    git init -q --bare "$remote" || return 1
    mkdir -p "$work" || return 1
    git -C "$work" init -q || return 1
    mkdir -p "$work/$(dirname "$file")" || return 1
    printf 'fixture submodule content\n' > "$work/$file" || return 1

    git -C "$work" add -A || return 1
    git -C "$work" -c user.name=fixture -c user.email=fixture@example.invalid \
        commit -qm fixture || return 1
    git -C "$work" push -q "$remote" HEAD:refs/heads/main || return 1
    git -C "$remote" symbolic-ref HEAD refs/heads/main || return 1

    git -C "$work" rev-parse HEAD
}

fixture_remote() {
    local remote="$TEST_ROOT/upstream" subs="$TEST_ROOT/subs" dots icons
    mkdir -p "$remote" "$subs" || return 1
    git -C "$REPO_ROOT" archive HEAD | tar -x -C "$remote" || return 1

    rm -rf "$remote/src/dots" "$remote/src/yet-another-monochrome-icon-set"
    dots="$(seed_submodule "$subs/dots.git" starship.toml)" || return 1
    icons="$(seed_submodule "$subs/icons.git" index.theme)" || return 1

    git -C "$remote" init -q || return 1
    git -C "$remote" config user.name fixture
    git -C "$remote" config user.email fixture@example.invalid
    git -C "$remote" config -f .gitmodules submodule.caelestia.path src/dots
    git -C "$remote" config -f .gitmodules submodule.caelestia.url "$subs/dots.git"
    git -C "$remote" config -f .gitmodules submodule.icons.path src/yet-another-monochrome-icon-set
    git -C "$remote" config -f .gitmodules submodule.icons.url "$subs/icons.git"
    git -C "$remote" add -A || return 1
    git -C "$remote" update-index --add --cacheinfo 160000,"$dots",src/dots || return 1
    git -C "$remote" update-index --add --cacheinfo 160000,"$icons",src/yet-another-monochrome-icon-set || return 1
    git -C "$remote" commit -qm fixture || return 1
    git -C "$remote" branch -M dev || return 1

    printf '%s\n' "$remote"
}

ensure_fixture() {
    [[ -n "$FIXTURE_REMOTE" ]] && return 0

    local remote
    remote="$(fixture_remote)" || return 1
    [[ -n "$remote" ]] || return 1
    FIXTURE_REMOTE="$remote"
}

run_updater() {
    local home="$1" log="$2" tool resolved
    local tools="$home/tools"

    mkdir -p "$home" "$tools" "$home/.runtime" || return 1
    for tool in awk bash basename cat chmod cp date dirname env find flock git grep head \
        id ls mkdir mktemp mv readlink rm rmdir sed sh sleep sort tail tar tr uname wc; do
        resolved="$(command -v "$tool" 2>/dev/null)" || continue
        ln -sf "$resolved" "$tools/$tool"
    done
    stub_bin "$tools" cmake 'exit 0'
    stub_bin "$tools" make 'exit 0'
    stub_bin "$tools" pkexec 'exit 0'

    cat > "$home/.gitconfig" <<EOF
[user]
    name = fixture
    email = fixture@example.invalid
[url "$FIXTURE_REMOTE"]
    insteadOf = https://github.com/ladybug-me/caelestia-kde.git
[protocol "file"]
    allow = always
EOF

    env -i HOME="$home" PATH="$tools" TMPDIR="$TEST_ROOT/tmp" \
        XDG_RUNTIME_DIR="$home/.runtime" \
        CAELESTIA_SKIP_DEPLOY=1 CAELESTIA_SKIP_BUILD=1 \
        "$BASH_BIN" "$UPDATER" dev > "$log" 2>&1
    printf '%s\n' "$?"
}

sparse_rules() {
    sed -n 's/.*echo "\([^"]*\)" >\+ \.git\/info\/sparse-checkout.*/\1/p' "$UPDATER"
}

checkout_repo() {
    printf '%s\n' "$1/.config/caelestia-update/repo"
}

test_the_checkout_carries_everything_the_later_stages_read() {
    require_tools || return 0
    ensure_fixture || { fail "could not build the fixture repository"; return 0; }

    local home="$TEST_ROOT/checkout" log="$TEST_ROOT/checkout.log" status repo path absent=""

    status="$(run_updater "$home" "$log")"
    assert_status 0 "$status" "the updater should complete its checkout stage (log: $log)"

    repo="$(checkout_repo "$home")"
    for path in "${REQUIRED_IN_CHECKOUT[@]}"; do
        [[ -e "$repo/$path" ]] || absent="$absent $path"
    done
    [[ -z "$absent" ]] || fail "the sparse checkout is missing path(s) the update reads:$absent"
}

test_every_sparse_rule_selects_something_in_the_checkout() {
    require_tools || return 0
    ensure_fixture || { fail "could not build the fixture repository"; return 0; }

    local home="$TEST_ROOT/rules" log="$TEST_ROOT/rules.log" status repo entry rules=0

    status="$(run_updater "$home" "$log")"
    assert_status 0 "$status" "the updater should complete its checkout stage (log: $log)"

    repo="$(checkout_repo "$home")"
    while IFS= read -r entry; do
        rules=$((rules + 1))
        [[ -e "$repo/$entry" ]] || fail "sparse rule '$entry' selected nothing in the worktree"
    done < <(sparse_rules)
    [[ "$rules" -gt 0 ]] || fail "no sparse rules were found in $UPDATER"

    assert_file_missing "$repo/tests"
}

test_a_second_update_reuses_the_checkout_without_losing_content() {
    require_tools || return 0
    ensure_fixture || { fail "could not build the fixture repository"; return 0; }

    local home="$TEST_ROOT/again" log="$TEST_ROOT/again.log" status repo

    status="$(run_updater "$home" "$log")"
    assert_status 0 "$status" "the first update should succeed (log: $log)"

    status="$(run_updater "$home" "$TEST_ROOT/again-2.log")"
    assert_status 0 "$status" "a repeated update should succeed (log: $TEST_ROOT/again-2.log)"

    repo="$(checkout_repo "$home")"
    assert_file_exists "$repo/assets/org.quickshell.desktop"
    assert_file_exists "$repo/src/dots/starship.toml"
}

run_tests
