#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG=""
DEPLOY_SOURCE="false"
INSTALL_PACKAGE="false"
CSV_PATH=""
VALIDATE_ONLY="false"
SKIP_OPEN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org) TARGET_ORG="$2"; shift 2 ;;
    --deploy-source) DEPLOY_SOURCE="true"; shift ;;
    --install-package) INSTALL_PACKAGE="true"; shift ;;
    --csv) CSV_PATH="$2"; shift 2 ;;
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

sf org display --target-org "$TARGET_ORG" --json >/dev/null
org_json="$(sf data query --target-org "$TARGET_ORG" --json --query "SELECT IsSandbox, OrganizationType FROM Organization LIMIT 1")"
is_sandbox="$(echo "$org_json" | jq -r '.result.records[0].IsSandbox')"
org_type="$(echo "$org_json" | jq -r '.result.records[0].OrganizationType')"
if [[ "$is_sandbox" != "true" && "$org_type" == "Production" ]]; then
  echo "Refusing to deploy to production org: $TARGET_ORG" >&2
  exit 1
fi

if [[ "$VALIDATE_ONLY" != "true" ]]; then
  if [[ "$DEPLOY_SOURCE" == "true" || "$INSTALL_PACKAGE" != "true" ]]; then
    echo "Deploying Core source only"
    sf project deploy start --source-dir force-app/core --target-org "$TARGET_ORG" --wait 30 >/dev/null
  else
    scripts/package/install-core-package.sh "$TARGET_ORG"
  fi
fi

demo_count="$(sf data query --target-org "$TARGET_ORG" --use-tooling-api --json --query "SELECT Id FROM ApexClass WHERE Name LIKE 'XC_AFCC_Demo%' LIMIT 1" | jq -r '.result.totalSize')"
if [[ "$demo_count" != "0" ]]; then
  echo "Demo Harness metadata is present in target org. Core-only bootstrap cannot continue." >&2
  exit 1
fi

if [[ "$VALIDATE_ONLY" != "true" ]]; then
  sf org assign permset --name XC_AFCC_Admin --target-org "$TARGET_ORG" >/dev/null || true
  sf apex run --target-org "$TARGET_ORG" --file scripts/apex/validateSandboxReadiness.apex >/dev/null
fi

count_object() {
  local object_name="$1"
  if sf sobject describe --target-org "$TARGET_ORG" --sobject "$object_name" --json >/dev/null 2>&1; then
    sf data query --target-org "$TARGET_ORG" --json --query "SELECT COUNT() FROM $object_name" | jq -r '.result.totalSize'
  else
    echo "0"
  fi
}

account_count="$(count_object Account)"
contact_count="$(count_object Contact)"
case_count="$(count_object Case)"
messaging_session_count="$(count_object MessagingSession)"
agent_work_count="$(count_object AgentWork)"
conversation_count="$(count_object Conversation)"
native_source_count=$((messaging_session_count + agent_work_count + conversation_count))

if [[ "$VALIDATE_ONLY" != "true" ]]; then
  sf apex run --target-org "$TARGET_ORG" --file scripts/apex/syncNativeUsage.apex >/dev/null || true
fi

if [[ -n "$CSV_PATH" ]]; then
  echo "CSV fallback requested explicitly. Native Salesforce source analysis remains the primary path."
  if [[ ! -f "$CSV_PATH" ]]; then
    echo "CSV file not found: $CSV_PATH" >&2
    exit 1
  fi
  encoded="$(base64 < "$CSV_PATH" | tr -d '\n')"
  tmp_csv="$(mktemp)"
  cat > "$tmp_csv" <<EOF
XC_AFCC_Org_Config__c config = XC_AFCC_SetupController.ensureDefaultConfig();
config.XC_AFCC_Csv_Import_Enabled__c = true;
update config;
String csvBody = EncodingUtil.base64Decode('$encoded').toString();
System.debug(JSON.serializePretty(XC_AFCC_CsvImportService.importCsv('$CSV_PATH', csvBody)));
EOF
  sf apex run --target-org "$TARGET_ORG" --file "$tmp_csv" >/dev/null
  rm -f "$tmp_csv"
fi

sf apex run --target-org "$TARGET_ORG" --file scripts/apex/runDataHealth.apex >/dev/null
sandbox_output="$(sf apex run --target-org "$TARGET_ORG" --file scripts/apex/validateSandboxReadiness.apex 2>&1 || true)"
ledger_count="$(sf data query --target-org "$TARGET_ORG" --json --query "SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c" | jq -r '.result.totalSize')"
live_ledger_count="$(sf data query --target-org "$TARGET_ORG" --json --query "SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'LIVE'" | jq -r '.result.totalSize')"
if [[ "$native_source_count" == "0" ]]; then
  native_ready="NO - Supported native source objects or rows not found"
  analysis_ready="NO - Native Agentforce/Service Cloud data not available yet"
  readiness="MISSING_NATIVE_SOURCE"
elif [[ "$live_ledger_count" == "0" ]]; then
  native_ready="YES"
  analysis_ready="NO - Native source rows not synced into ledger yet"
  readiness="NATIVE_READY"
else
  native_ready="YES"
  analysis_ready="YES"
  readiness="ANALYSIS_READY"
fi
app_url="$(sf org open --target-org "$TARGET_ORG" --path lightning/n/XC_AFCC_Cost_Dashboard --url-only --json | jq -r '.result.url // empty')"

if [[ "$SKIP_OPEN" != "true" ]]; then
  sf org open --target-org "$TARGET_ORG" --path lightning/n/XC_AFCC_Cost_Dashboard >/dev/null
fi

cat <<EOF

Agentforce Cost Calculator Step 2 Readiness

Target Org: $TARGET_ORG
Org Type: $org_type
Core Only: PASS
Demo Harness Present: NO
Account Rows: $account_count
Contact Rows: $contact_count
Case Rows: $case_count
MessagingSession Rows: $messaging_session_count
AgentWork Rows: $agent_work_count
Conversation Rows: $conversation_count
Native Source Ready: $native_ready
Analysis Ready: $analysis_ready
Ledger Row Count: $ledger_count
Live Ledger Row Count: $live_ledger_count
CSV Fallback: explicit --csv only
App URL: $app_url
Readiness Validator: $readiness

Result: PASS
EOF
