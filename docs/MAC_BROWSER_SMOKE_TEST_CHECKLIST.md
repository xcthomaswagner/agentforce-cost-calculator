# Mac / Browser Smoke Test Checklist

## Step 1 Synthetic Test Org

1. Run `scripts/mvp/01-create-synthetic-test-org.sh --scenario known-answer-small --volume small --fresh`.
2. Confirm the script prints `Result: PASS`.
3. Open the Cost Dashboard tab and confirm ledger rows and allocated cost are visible.
4. Open Grouped Report and switch between Queue, Agent, Topic, Outcome, Channel, and Date.
5. Open Case Explorer, enter a seeded case number, and confirm cost explanation rows load.
6. Open Data Health and run the health check.
7. Open the Demo Harness app and confirm the Synthetic Data Generator is visible only for a user with `XC_AFCC_Internal_Demo_Admin`.
8. Run `scripts/validate/no-demo-in-core.sh`.
9. Run `scripts/validate/package-composition-check.sh`.

## Step 2 Sandbox Bootstrap

1. Run `scripts/mvp/02-bootstrap-agentforce-sandbox.sh --target-org <sandbox-alias> --deploy-source`.
2. Confirm the script prints `Demo Harness Present: NO`.
3. Confirm the script prints Service Cloud counts for `Account`, `Contact`, and `Case`.
4. Confirm the script prints native source counts for available Agentforce/Service Cloud objects.
5. Confirm the script prints `Native Source Ready: YES` when native usage objects contain data.
6. If native usage objects are present but no usage records exist yet, confirm it prints `Analysis Ready: NO - Native Agentforce usage data not available yet`.
7. Open Setup and confirm the primary action is native usage sync, not CSV import.
8. Re-run Data Health.
9. Confirm Dashboard, Grouped Report, and Case Explorer work from native/live ledger rows when source data exists.

## CSV Fallback Smoke Sample

CSV is a fallback-only admin utility. Use this sample only when explicitly validating the fallback path.

```csv
source_record_id,billing_model,usage_timestamp,case_number,conversation_id,agent_name,action_name,topic,channel,queue_name,credits_used,conversations_used,action_count,case_outcome
smoke-1,FLEX_CREDITS,2026-01-01 12:00:00,00001000,conv-smoke-1,Agent 1,Resolve,Billing,Web,Billing Support,20,0,1,RESOLVED
```
