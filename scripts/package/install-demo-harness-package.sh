#!/usr/bin/env bash
set -euo pipefail
TARGET_ORG="${1:-${TARGET_ORG:-}}"
PACKAGE_VERSION="${2:-${DEMO_HARNESS_PACKAGE_VERSION:-}}"
if [[ -z "$TARGET_ORG" || -z "$PACKAGE_VERSION" ]]; then
  echo "Usage: scripts/package/install-demo-harness-package.sh <target-org> <package-version-id>" >&2
  exit 2
fi
sf package install --target-org "$TARGET_ORG" --package "$PACKAGE_VERSION" --wait 30 --publish-wait 30 --no-prompt
