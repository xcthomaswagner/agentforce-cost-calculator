#!/usr/bin/env bash
set -euo pipefail
TARGET_ORG="${1:-${TARGET_ORG:-}}"
if [[ -z "$TARGET_ORG" ]]; then
  echo "Usage: scripts/test/run-data-health-check.sh <target-org>" >&2
  exit 2
fi
sf apex run --target-org "$TARGET_ORG" --file scripts/apex/runDataHealth.apex
