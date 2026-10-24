#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONNECTIVITY="$REPO_ROOT/shell/services/Connectivity.qml"
PROXY_SERVICE="$REPO_ROOT/shell/services/Proxy.qml"
PROXY_SCRIPT="$REPO_ROOT/shell/scripts/proxy.py"
PROXY_PAGE="$REPO_ROOT/shell/modules/nexus/pages/network/ProxyPage.qml"
NETWORK_PAGE="$REPO_ROOT/shell/modules/nexus/pages/NetworkPage.qml"
REGISTRY="$REPO_ROOT/shell/modules/nexus/PageCompRegistry.qml"
PYTHON="$(command -v python3 || command -v python)"

TMP="$("$PYTHON" -c 'import tempfile; print(tempfile.mkdtemp())')"
trap 'rm -rf "$TMP"' EXIT

test_networkmanager_is_the_one_that_knows_about_portals() {
    assert_file_contains "$CONNECTIVITY" '["nmcli", "-t", "-f", "CONNECTIVITY", "general"]' \
        "NetworkManager runs the probe; the shell must not invent its own verdict"
    assert_file_contains "$CONNECTIVITY" 'root.state === "portal"' "and portal is the state it keys on"
    assert_file_contains "$CONNECTIVITY" 'function onIsConnectedChanged()' "the answer is re-read when the connection changes"
}

test_the_sign_in_url_is_found_by_where_the_redirect_went() {
    assert_file_contains "$CONNECTIVITY" '"%{url_effective}"' \
        "a portal intercepts the check and answers with its own address"
    assert_file_contains "$CONNECTIVITY" 'url.startsWith(root.checkUrl) ? "" : url' \
        "an unchanged URL means the network answered normally and there is nothing to open"
    assert_file_contains "$CONNECTIVITY" '["xdg-open", root.portalUrl]' "the page is opened, not described"
    assert_file_contains "$NETWORK_PAGE" 'Connectivity.portal' "the network page only shows the row when there is a portal"
    assert_file_contains "$NETWORK_PAGE" 'Connectivity.signIn()' "and the row asks for the sign-in page"
}

test_the_proxy_is_written_where_kde_reads_it() {
    export XDG_CONFIG_HOME="$TMP/config"
    mkdir -p "$XDG_CONFIG_HOME"
    cat > "$XDG_CONFIG_HOME/kioslaverc" <<'INI'
[General]
SomeKey=keepme

[Proxy Settings]
ProxyType=1
httpProxy=http://old:3128
noProxyFor=localhost,127.0.0.1

[Other]
Also=kept
INI

    assert_eq "manual http://old:3128 localhost,127.0.0.1" \
        "$("$PYTHON" "$PROXY_SCRIPT" --get | "$PYTHON" -c 'import json,sys; d=json.load(sys.stdin); print(d["mode"], d["http"], d["noProxy"])')" \
        "reading reports the mode and the addresses KDE would use"

    "$PYTHON" "$PROXY_SCRIPT" --set https https://new:8443
    "$PYTHON" "$PROXY_SCRIPT" --set-mode pac

    assert_contains "$(cat "$XDG_CONFIG_HOME/kioslaverc")" "ProxyType=2" "the mode is the ProxyType KDE expects"
    assert_contains "$(cat "$XDG_CONFIG_HOME/kioslaverc")" "httpsProxy=https://new:8443" "a set address is written"
    assert_contains "$(cat "$XDG_CONFIG_HOME/kioslaverc")" "SomeKey=keepme" "sections the shell does not own survive"
    assert_contains "$(cat "$XDG_CONFIG_HOME/kioslaverc")" "Also=kept" "including the ones after the proxy section"
    assert_contains "$(cat "$XDG_CONFIG_HOME/kioslaverc")" "httpProxy=http://old:3128" "and keys are updated, not cleared"
    assert_not_contains "$(cat "$XDG_CONFIG_HOME/kioslaverc")" "ProxyType=1" "the old mode is replaced"
}

test_the_proxy_page_and_service_agree_on_the_script() {
    assert_file_contains "$PROXY_SERVICE" 'Quickshell.shellPath("scripts/proxy.py")' "one owner for the file"
    assert_file_contains "$PROXY_SERVICE" '["--set-mode", mode]' "the mode setter goes through it"
    assert_file_contains "$PROXY_SERVICE" '["--set", key, value]' "so do the addresses"
    assert_file_contains "$PROXY_PAGE" 'onEditingFinished: Proxy.set(' \
        "values are written when the field is done, not on every keystroke"
    assert_file_contains "$REGISTRY" 'key: "proxy"' "the page is reachable"
    assert_file_contains "$NETWORK_PAGE" 'Proxy.settings.mode' "and the network page reports what it holds"
}

run_tests