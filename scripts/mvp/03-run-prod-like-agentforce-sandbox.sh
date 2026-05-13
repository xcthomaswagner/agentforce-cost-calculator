#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG=""
CASE_COUNT="150"
RUN_KEY="afcc-prod-like-$(date +%Y%m%d%H%M%S)"
DEPLOY_CORE="false"
SEED_BUSINESS_DATA="true"
CONVERSATION_RUNNER=""
SYNC_NATIVE="true"
VALIDATE_ONLY="false"
SKIP_OPEN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org) TARGET_ORG="$2"; shift 2 ;;
    --case-count) CASE_COUNT="$2"; shift 2 ;;
    --run-key) RUN_KEY="$2"; shift 2 ;;
    --deploy-core) DEPLOY_CORE="true"; shift ;;
    --skip-seed) SEED_BUSINESS_DATA="false"; shift ;;
    --conversation-runner) CONVERSATION_RUNNER="$2"; shift 2 ;;
    --skip-sync) SYNC_NATIVE="false"; shift ;;
    --validate-only) VALIDATE_ONLY="true"; shift ;;
    --skip-open) SKIP_OPEN="true"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$TARGET_ORG" ]]; then
  echo "--target-org is required." >&2
  exit 2
fi

command -v sf >/dev/null 2>&1 || { echo "Missing prerequisite: sf" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Missing prerequisite: jq" >&2; exit 1; }

if ! [[ "$CASE_COUNT" =~ ^[0-9]+$ ]] || [[ "$CASE_COUNT" -lt 1 ]]; then
  echo "--case-count must be a positive integer." >&2
  exit 2
fi

sf org display --target-org "$TARGET_ORG" --json >/dev/null
org_json="$(sf data query --target-org "$TARGET_ORG" --json --query "SELECT IsSandbox, OrganizationType FROM Organization LIMIT 1")"
is_sandbox="$(echo "$org_json" | jq -r '.result.records[0].IsSandbox')"
org_type="$(echo "$org_json" | jq -r '.result.records[0].OrganizationType')"
if [[ "$is_sandbox" != "true" && "$org_type" == "Production" ]]; then
  echo "Refusing to run production-like harness against production org: $TARGET_ORG" >&2
  exit 1
fi

if [[ "$VALIDATE_ONLY" != "true" && "$DEPLOY_CORE" == "true" ]]; then
  echo "Deploying Core source only"
  sf project deploy start --source-dir force-app/core --target-org "$TARGET_ORG" --wait 30 >/dev/null
fi

demo_count="$(sf data query --target-org "$TARGET_ORG" --use-tooling-api --json --query "SELECT Id FROM ApexClass WHERE Name LIKE 'XC_AFCC_Demo%' LIMIT 1" | jq -r '.result.totalSize')"
if [[ "$demo_count" != "0" ]]; then
  echo "Demo Harness metadata is present. Prod-like runtime validation must run Core-only." >&2
  exit 1
fi

if [[ "$VALIDATE_ONLY" != "true" ]]; then
  sf org assign permset --name XC_AFCC_Admin --target-org "$TARGET_ORG" >/dev/null || true
  sf apex run --target-org "$TARGET_ORG" --file scripts/apex/validateSandboxReadiness.apex >/dev/null
fi

if [[ "$VALIDATE_ONLY" != "true" && "$SEED_BUSINESS_DATA" == "true" ]]; then
  echo "Seeding real Accounts, Contacts, and Cases for run key: $RUN_KEY"
  tmp_seed="$(mktemp)"
  sed \
    -e "s/__CASE_COUNT__/$CASE_COUNT/g" \
    -e "s/__RUN_KEY__/$RUN_KEY/g" \
    scripts/apex/seedProdLikeBusinessData.apex > "$tmp_seed"
  sf apex run --target-org "$TARGET_ORG" --file "$tmp_seed" >/dev/null
  rm -f "$tmp_seed"
fi

runtime_before="$(sf apex run --target-org "$TARGET_ORG" --file scripts/apex/validateAgentforceRuntimeReadiness.apex 2>&1 || true)"

runner_result="SKIPPED"
if [[ "$VALIDATE_ONLY" != "true" && -n "$CONVERSATION_RUNNER" ]]; then
  if [[ ! -x "$CONVERSATION_RUNNER" ]]; then
    echo "Conversation runner is not executable: $CONVERSATION_RUNNER" >&2
    exit 1
  fi
  echo "Running configured Agentforce conversation runner"
  XC_AFCC_TARGET_ORG="$TARGET_ORG" \
  XC_AFCC_RUN_KEY="$RUN_KEY" \
  XC_AFCC_CASE_COUNT="$CASE_COUNT" \
  XC_AFCC_CASE_SUBJECT_PREFIX="AFCC Prod-Like $RUN_KEY Case" \
  "$CONVERSATION_RUNNER"
  runner_result="PASS"
elif [[ -z "$CONVERSATION_RUNNER" ]]; then
  runner_result="PENDING - provide --conversation-runner after Agentforce channel setup is confirmed"
fi

if [[ "$VALIDATE_ONLY" != "true" && "$SYNC_NATIVE" == "true" ]]; then
  echo "Syncing native Salesforce runtime records into the cost ledger"
  sf apex run --target-org "$TARGET_ORG" --file scripts/apex/syncNativeUsage.apex >/dev/null || true
  sf apex run --target-org "$TARGET_ORG" --file scripts/apex/runDataHealth.apex >/dev/null
fi

runtime_after="$(sf apex run --target-org "$TARGET_ORG" --file scripts/apex/validateAgentforceRuntimeReadiness.apex 2>&1 || true)"
business_case_count="$(sf data query --target-org "$TARGET_ORG" --json --query "SELECT COUNT() FROM Case WHERE Subject LIKE 'AFCC Prod-Like $RUN_KEY Case%'" | jq -r '.result.totalSize')"
live_ledger_count="$(sf data query --target-org "$TARGET_ORG" --json --query "SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'LIVE'" | jq -r '.result.totalSize')"
staging_count="$(sf data query --target-org "$TARGET_ORG" --json --query "SELECT COUNT() FROM XC_AFCC_Usage_Staging__c WHERE XC_AFCC_Source_System__c = 'LIVE'" | jq -r '.result.totalSize')"
app_url="$(sf org open --target-org "$TARGET_ORG" --path lightning/n/XC_AFCC_Setup --url-only --json | jq -r '.result.url // empty')"

if [[ "$SKIP_OPEN" != "true" ]]; then
  sf org open --target-org "$TARGET_ORG" --path lightning/n/XC_AFCC_Setup >/dev/null
fi

cat <<EOF

Agentforce Cost Calculator Step 3 Prod-Like Sandbox Readiness

Target Org: $TARGET_ORG
Org Type: $org_type
Run Key: $RUN_KEY
Core Only: PASS
Demo Harness Present: NO
Requested Business Case Count: $CASE_COUNT
Seeded Business Case Count: $business_case_count
Conversation Runner: $runner_result
Live Staging Rows: $staging_count
Live Ledger Rows: $live_ledger_count
App URL: $app_url

Runtime Readiness Before Runner:
$runtime_before

Runtime Readiness After Runner:
$runtime_after

Result: $([[ "$runner_result" == "PASS" && "$live_ledger_count" != "0" ]] && echo "PASS" || echo "PENDING_RUNTIME_CONVERSATIONS")
EOF
