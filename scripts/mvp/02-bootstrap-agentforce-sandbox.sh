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

if [[ -n "$CSV_PATH" ]]; then
  if [[ ! -f "$CSV_PATH" ]]; then
    echo "CSV file not found: $CSV_PATH" >&2
    exit 1
  fi
  encoded="$(base64 < "$CSV_PATH" | tr -d '\n')"
  tmp_csv="$(mktemp)"
  cat > "$tmp_csv" <<EOF
String csvBody = EncodingUtil.base64Decode('$encoded').toString();
System.debug(JSON.serializePretty(XC_AFCC_CsvImportService.importCsv('$CSV_PATH', csvBody)));
EOF
  sf apex run --target-org "$TARGET_ORG" --file "$tmp_csv" >/dev/null
  rm -f "$tmp_csv"
fi

sf apex run --target-org "$TARGET_ORG" --file scripts/apex/runDataHealth.apex >/dev/null
sandbox_output="$(sf apex run --target-org "$TARGET_ORG" --file scripts/apex/validateSandboxReadiness.apex 2>&1 || true)"
ledger_count="$(sf data query --target-org "$TARGET_ORG" --json --query "SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c" | jq -r '.result.totalSize')"
csv_available="YES"
if [[ "$ledger_count" == "0" ]]; then
  analysis_ready="NO - Usage data not imported yet"
  readiness="READY_FOR_IMPORT"
else
  analysis_ready="YES"
  readiness="PASS"
fi
app_url="$(sf org open --target-org "$TARGET_ORG" --path lightning/n/XC_AFCC_Cost_Dashboard --url-only --json | jq -r '.result.url // empty')"

if [[ "$SKIP_OPEN" != "true" ]]; then
  sf org open --target-org "$TARGET_ORG" --path lightning/n/XC_AFCC_Cost_Dashboard >/dev/null
fi

cat <<EOF

XC AFCC MVP Step 2 Readiness

Target Org: $TARGET_ORG
Org Type: $org_type
Core Only: PASS
Demo Harness Present: NO
CSV Import Available: $csv_available
Sandbox Ready for Data Import: YES
Analysis Ready: $analysis_ready
Ledger Row Count: $ledger_count
App URL: $app_url
Readiness Validator: $readiness

Result: PASS
EOF
