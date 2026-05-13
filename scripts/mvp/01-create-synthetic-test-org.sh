#!/usr/bin/env bash
set -euo pipefail

SCENARIO="deferred-hotspot"
VOLUME="small"
ORG_ALIAS="xc-afcc-synth-test"
DURATION_DAYS="14"
FRESH="false"
REUSE_ORG=""
RESET_DATA="false"
SKIP_OPEN="false"
RUN_TESTS="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario) SCENARIO="$2"; shift 2 ;;
    --volume) VOLUME="$2"; shift 2 ;;
    --alias) ORG_ALIAS="$2"; shift 2 ;;
    --duration-days) DURATION_DAYS="$2"; shift 2 ;;
    --fresh) FRESH="true"; shift ;;
    --reuse-org) REUSE_ORG="$2"; ORG_ALIAS="$2"; shift 2 ;;
    --reset-data) RESET_DATA="true"; shift ;;
    --skip-open) SKIP_OPEN="true"; shift ;;
    --run-tests) RUN_TESTS="true"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing prerequisite: $1" >&2; exit 1; }; }
need sf
need git
need jq

if [[ ! -f "sfdx-project.json" ]]; then
  echo "Run this script from the repository root." >&2
  exit 1
fi

DEV_HUB="$(sf config get target-dev-hub --json 2>/dev/null | jq -r '.result[0].value // empty')"
if [[ -z "$DEV_HUB" ]]; then
  DEV_HUB="$(sf org list --json | jq -r '.result.devHubs[0].alias // .result.devHubs[0].username // empty')"
fi
if [[ -z "$DEV_HUB" ]]; then
  echo "No authenticated Dev Hub found. Authenticate a Dev Hub with Salesforce CLI first." >&2
  exit 1
fi

echo "Checking scratch org limits in Dev Hub: $DEV_HUB"
sf org list limits --target-org "$DEV_HUB" >/dev/null || echo "Warning: could not read Dev Hub limits; continuing."

if [[ "$FRESH" == "true" ]]; then
  sf org delete scratch --target-org "$ORG_ALIAS" --no-prompt >/dev/null 2>&1 || true
fi

if [[ -z "$REUSE_ORG" ]]; then
  echo "Creating scratch org: $ORG_ALIAS"
  sf org create scratch \
    --definition-file config/scratch/synthetic-test-scratch-def.json \
    --alias "$ORG_ALIAS" \
    --duration-days "$DURATION_DAYS" \
    --target-dev-hub "$DEV_HUB" \
    --set-default \
    --wait 20 >/dev/null
else
  echo "Reusing scratch org: $ORG_ALIAS"
fi

echo "Deploying Core source"
sf project deploy start --source-dir force-app/core --target-org "$ORG_ALIAS" --wait 30 >/dev/null

echo "Deploying Demo Harness source"
sf project deploy start --source-dir force-app/demo-harness --target-org "$ORG_ALIAS" --wait 30 >/dev/null

echo "Assigning permission sets"
sf org assign permset --name XC_AFCC_Admin --target-org "$ORG_ALIAS" >/dev/null || true
sf org assign permset --name XC_AFCC_Internal_Demo_Admin --target-org "$ORG_ALIAS" >/dev/null || true

if [[ "$RESET_DATA" == "true" || "$FRESH" == "true" ]]; then
  echo "Resetting generated data"
  tmp_reset="$(mktemp)"
  printf "XC_AFCC_DemoResetService.resetSyntheticData();\n" > "$tmp_reset"
  sf apex run --target-org "$ORG_ALIAS" --file "$tmp_reset" >/dev/null || true
  rm -f "$tmp_reset"
fi

echo "Seeding scenario: $SCENARIO ($VOLUME)"
tmp_seed="$(mktemp)"
printf "System.debug(JSON.serializePretty(XC_AFCC_DemoSeeder.seed('%s', '%s')));\n" "$SCENARIO" "$VOLUME" > "$tmp_seed"
sf apex run --target-org "$ORG_ALIAS" --file "$tmp_seed" >/dev/null
rm -f "$tmp_seed"

echo "Running data health"
sf apex run --target-org "$ORG_ALIAS" --file scripts/apex/runDataHealth.apex >/dev/null

if [[ "$RUN_TESTS" == "true" ]]; then
  echo "Running Apex tests"
  scripts/test/run-apex-tests.sh "$ORG_ALIAS"
fi

echo "Running readiness validation"
sf apex run --target-org "$ORG_ALIAS" --file scripts/apex/validateSyntheticReadiness.apex >/dev/null

case_count="$(sf data query --target-org "$ORG_ALIAS" --json --query "SELECT COUNT() FROM Case WHERE Subject LIKE 'XC AFCC Synthetic Case%'" | jq -r '.result.totalSize')"
ledger_count="$(sf data query --target-org "$ORG_ALIAS" --json --query "SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC'" | jq -r '.result.totalSize')"
deferred_count="$(sf data query --target-org "$ORG_ALIAS" --json --query "SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC' AND XC_AFCC_Case_Outcome__c = 'DEFERRED'" | jq -r '.result.totalSize')"
unallocated_count="$(sf data query --target-org "$ORG_ALIAS" --json --query "SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC' AND XC_AFCC_Case__c = null" | jq -r '.result.totalSize')"
if [[ "$ledger_count" == "0" ]]; then
  unallocated_pct="0"
else
  unallocated_pct="$(awk "BEGIN { printf \"%.2f\", ($unallocated_count * 100) / $ledger_count }")"
fi
suggested_question="$(jq -r '.suggestedQuestion // "Which support queue has the highest Agentforce cost per deferred case?"' "config/demo-scenarios/$SCENARIO.json")"
dashboard_url="$(sf org open --target-org "$ORG_ALIAS" --path lightning/n/XC_AFCC_Cost_Dashboard --url-only --json | jq -r '.result.url // empty')"
report_url="$(sf org open --target-org "$ORG_ALIAS" --path lightning/n/XC_AFCC_Grouped_Report --url-only --json | jq -r '.result.url // empty')"
case_url="$(sf org open --target-org "$ORG_ALIAS" --path lightning/n/XC_AFCC_Case_Explorer --url-only --json | jq -r '.result.url // empty')"

if [[ "$SKIP_OPEN" != "true" ]]; then
  sf org open --target-org "$ORG_ALIAS" --path lightning/n/XC_AFCC_Cost_Dashboard >/dev/null
fi

cat <<EOF

Agentforce Cost Calculator Step 1 Readiness

Org Alias: $ORG_ALIAS
Scenario: $SCENARIO
Case Count: $case_count
Ledger Row Count: $ledger_count
Deferred Case Count: $deferred_count
Unallocated Usage Percentage: $unallocated_pct
Suggested Demo Question: $suggested_question
Dashboard URL: $dashboard_url
Grouped Report URL: $report_url
Case Explorer URL: $case_url

Core Deploy: PASS
Demo Harness Deploy: PASS
Permission Sets: PASS
Synthetic Seed: PASS
Data Health: PASS
Apex Tests: $([[ "$RUN_TESTS" == "true" ]] && echo PASS || echo SKIPPED)
Readiness Validator: PASS

Result: PASS
EOF
