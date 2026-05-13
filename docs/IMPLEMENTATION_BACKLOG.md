# Implementation Backlog

## Phase 0 — Repo and Project Structure

1. Create Salesforce DX project structure.
2. Add `force-app/core`.
3. Add `force-app/demo-harness`.
4. Add `config/scratch`.
5. Add `config/demo-scenarios`.
6. Add `scripts/mvp`.
7. Add `scripts/test`.
8. Add `scripts/validate`.
9. Add `scripts/apex`.
10. Add docs.

---

## Phase 1 — Core Metadata

1. Create `XC_AFCC_Cost_Ledger__c`.
2. Create `XC_AFCC_Usage_Staging__c`.
3. Create `XC_AFCC_Case_Conversation_Link__c`.
4. Create `XC_AFCC_Org_Config__c`.
5. Create `XC_AFCC_Import_Run__c`.
6. Create `XC_AFCC_Data_Health_Check__c`.
7. Create `XC_AFCC_Audit_Log__c`.
8. Create Core permission sets.
9. Create Core Lightning app/tabs.

---

## Phase 2 — Core Apex

1. `XC_AFCC_EnvironmentService`
2. `XC_AFCC_CostCalculationService`
3. `XC_AFCC_UsageStagingService`
4. `XC_AFCC_CostLedgerService`
5. `XC_AFCC_CsvImportService`
6. `XC_AFCC_DataHealthService`
7. `XC_AFCC_ReportQueryService`
8. `XC_AFCC_CaseCostExplainService`
9. `XC_AFCC_AuditLogService`
10. Apex tests

---

## Phase 3 — Core UI

1. `xcAfccSetupWizard`
2. `xcAfccDataHealth`
3. `xcAfccCostDashboard`
4. `xcAfccGroupedReport`
5. `xcAfccCaseExplorer`
6. `xcAfccCsvImporter`
7. `xcAfccAdminSettings`

---

## Phase 4 — Demo Harness

1. Add custom permission `XC_AFCC_Access_Demo_Harness`.
2. Add permission set `XC_AFCC_Internal_Demo_Admin`.
3. Create `XC_AFCC_DemoGuardService`.
4. Create `XC_AFCC_DemoScenarioService`.
5. Create `XC_AFCC_SyntheticDataFactory`.
6. Create `XC_AFCC_DemoSeeder`.
7. Create `XC_AFCC_DemoResetService`.
8. Create `XC_AFCC_DemoReadinessService`.
9. Create Demo Harness LWCs.
10. Add scenario JSON files.
11. Add tests.

---

## Phase 5 — Step 1 Script

1. Build `01-create-synthetic-test-org.sh`.
2. Add prerequisite checks.
3. Add scratch org creation.
4. Add source deployment.
5. Add permission assignment.
6. Add synthetic seed.
7. Add readiness validation.
8. Add test execution.
9. Add scorecard output.
10. Add app opening.

---

## Phase 6 — Step 2 Script

1. Build `02-bootstrap-agentforce-sandbox.sh`.
2. Add target org validation.
3. Add non-production check.
4. Deploy Core only.
5. Validate Demo Harness absent.
6. Assign permission set.
7. Validate CSV import.
8. Run data health.
9. Add readiness output.

---

## Phase 7 — Testing and Defect Flush

1. Run Step 1 from clean Mac repo.
2. Run browser smoke test.
3. Capture defects.
4. Fix deployment defects.
5. Fix UI defects.
6. Fix readiness defects.
7. Run known-answer scenario.
8. Run Step 2 against sandbox.
9. Validate no synthetic leakage.
10. Produce release readiness scorecard.

---

## Phase 8 — Prod-Like Agentforce Sandbox Harness

1. Add Step 3 script.
2. Add production-like business seed Apex.
3. Add runtime readiness validation Apex.
4. Add conversation runner contract.
5. Add production-like scenario config.
6. Validate against an Agentforce-enabled sandbox.
7. Build channel-specific runner for the selected sandbox path.
8. Generate 150 runtime conversations.
9. Sync native runtime data.
10. Verify dashboard, data health, grouped report, and case explorer from `LIVE` rows.
