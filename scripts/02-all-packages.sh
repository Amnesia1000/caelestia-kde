#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
# shellcheck source=scripts/lib/packages.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/packages.sh"

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"
export BUNDLE_DIR

export PACKAGE_GROUP="all"

packages_script="$BUNDLE_DIR/installer/distro/$BASE_DISTRO/packages.sh"
if [[ ! -f "$packages_script" ]]; then
    die "No package list for '$BASE_DISTRO' (expected arch, fedora or debian)"
fi

bash "$packages_script"
