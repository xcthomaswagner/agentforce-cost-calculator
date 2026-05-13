#!/usr/bin/env bash
set -euo pipefail
TARGET_ORG="${1:-${TARGET_ORG:-}}"
OUT_DIR="${2:-artifacts/xc-afcc-debug-$(date +%Y%m%d-%H%M%S)}"
if [[ -z "$TARGET_ORG" ]]; then
  echo "Usage: scripts/test/collect-debug-artifacts.sh <target-org> [out-dir]" >&2
  exit 2
fi
mkdir -p "$OUT_DIR"
sf org display --target-org "$TARGET_ORG" --json > "$OUT_DIR/org-display.json" || true
sf data query --target-org "$TARGET_ORG" --json --query "SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c" > "$OUT_DIR/ledger-count.json" || true
sf data query --target-org "$TARGET_ORG" --json --query "SELECT COUNT() FROM XC_AFCC_Usage_Staging__c" > "$OUT_DIR/staging-count.json" || true
sf apex run --target-org "$TARGET_ORG" --file scripts/apex/runDataHealth.apex > "$OUT_DIR/data-health.txt" 2>&1 || true
sf apex run --target-org "$TARGET_ORG" --file scripts/apex/validateSandboxReadiness.apex > "$OUT_DIR/sandbox-readiness.txt" 2>&1 || true
cp -R config/demo-scenarios "$OUT_DIR/demo-scenarios" || true
echo "$OUT_DIR"
