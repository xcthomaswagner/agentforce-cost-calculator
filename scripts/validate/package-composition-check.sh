#!/usr/bin/env bash
set -euo pipefail
scripts/validate/no-demo-in-core.sh
for required in \
  force-app/core/default/objects/XC_AFCC_Cost_Ledger__c \
  force-app/core/default/classes/XC_AFCC_CsvImportService.cls \
  force-app/demo-harness/default/classes/XC_AFCC_DemoSeeder.cls \
  force-app/demo-harness/default/customPermissions/XC_AFCC_Access_Demo_Harness.customPermission-meta.xml
do
  if [[ ! -e "$required" ]]; then
    echo "Missing required package member: $required" >&2
    exit 1
  fi
done
if find force-app/core -path '*demo-harness*' -print | grep -q .; then
  echo "Core source contains demo-harness path." >&2
  exit 1
fi
echo "PASS: package composition is valid."
