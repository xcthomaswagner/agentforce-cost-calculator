# Mac / Browser Smoke Test Checklist

## Step 1 Synthetic Test Org

1. Run `scripts/mvp/01-create-synthetic-test-org.sh --scenario known-answer-small --volume small --fresh`.
2. Confirm the script prints `Result: PASS`.
3. Open the Cost Dashboard tab and confirm ledger rows and allocated cost are visible.
4. Open Grouped Report and switch between Queue, Agent, Topic, Outcome, Channel, and Date.
5. Open Case Explorer, enter a seeded case number, and confirm cost explanation rows load.
6. Open Data Health and run the health check.
7. Open the Demo Harness app and confirm the launcher is visible only for a user with `XC_AFCC_Internal_Demo_Admin`.
8. Run `scripts/validate/no-demo-in-core.sh`.
9. Run `scripts/validate/package-composition-check.sh`.

## Step 2 Sandbox Bootstrap

1. Run `scripts/mvp/02-bootstrap-agentforce-sandbox.sh --target-org <sandbox-alias> --deploy-source`.
2. Confirm the script prints `Demo Harness Present: NO`.
3. Confirm the script prints `Sandbox Ready for Data Import: YES`.
4. If no CSV was supplied, confirm it prints `Analysis Ready: NO - Usage data not imported yet`.
5. Open CSV Importer and import a small usage CSV.
6. Re-run Data Health.
7. Confirm Dashboard, Grouped Report, and Case Explorer work from imported rows.

## CSV Smoke Sample

```csv
source_record_id,billing_model,usage_timestamp,case_number,conversation_id,agent_name,action_name,topic,channel,queue_name,credits_used,conversations_used,action_count,case_outcome
smoke-1,FLEX_CREDITS,2026-01-01 12:00:00,00001000,conv-smoke-1,Agent 1,Resolve,Billing,Web,Billing Support,20,0,1,RESOLVED
```
