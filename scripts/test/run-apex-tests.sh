#!/usr/bin/env bash
set -euo pipefail
TARGET_ORG="${1:-${TARGET_ORG:-}}"
if [[ -z "$TARGET_ORG" ]]; then
  echo "Usage: scripts/test/run-apex-tests.sh <target-org>" >&2
  exit 2
fi
sf apex run test --target-org "$TARGET_ORG" --test-level RunLocalTests --wait 30 --result-format human
