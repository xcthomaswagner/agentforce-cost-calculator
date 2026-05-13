# Codex Goal Prompt

> V2 correction: this original prompt is superseded for the Agentforce sandbox flow by `MVP_EXECUTION_SPEC_V2.md` and `NATIVE_AGENTFORCE_SOURCE_SPEC.md`.
> CSV import is fallback-only. Step 2 must analyze native Service Cloud/Agentforce data when those objects and rows exist.

Use the following as historical context only unless the V2 specs say otherwise.

---

## GOAL

Build the MVP for the Salesforce-native **XC Agentforce Cost Calculator** in the repository:

`git@github.com:xcthomaswagner/agentforce-cost-calculator.git`

Local working folder:

`/Users/thomaswagner/Desktop/Projects.nosync/agentforce cost calculator`

The MVP is complete when both scripted flows work end-to-end:

1. **Synthetic Test Environment**
   - A developer runs one script on a Mac.
   - The script creates a Salesforce scratch org.
   - The script deploys the Salesforce source.
   - The script deploys or enables the demo harness.
   - The script creates deterministic synthetic Salesforce records and synthetic Agentforce cost ledger data.
   - The script runs validation and tests.
   - The Salesforce app opens ready for test/demo.

2. **Agentforce Sandbox Without Synthetic Data**
   - A developer runs one script against an existing Agentforce-enabled sandbox.
   - The script deploys Core only.
   - The demo harness and synthetic generator are absent.
   - Native Service Cloud and Agentforce source discovery is available.
   - The app can analyze live org usage data.
   - Data health, report builder, dashboard, and case explorer work without synthetic data.

Production deployment is out of scope for this MVP.

---

## NON-NEGOTIABLE CONSTRAINTS

- Keep the solution fully within Salesforce for the MVP.
- Do not add an external Node service, external database, middleware, or LLM service.
- Do not require Agentforce, Omni-Channel, Messaging, or Digital Engagement for the synthetic test org.
- Step 1 must work without Agentforce.
- Step 1 must create real Salesforce `Account`, `Contact`, and `Case` records.
- Step 1 must also create synthetic cost ledger records.
- Step 2 must run without synthetic data.
- All custom Salesforce metadata must use the `XC_AFCC` prefix.
- Core package/source must not contain demo/synthetic tooling.
- Demo/synthetic tooling must live only in the Demo Harness source area.
- Demo Harness must be permission-gated and sandbox/scratch-org guarded.
- Customer sandbox override for Demo Harness must exist, but must be explicit, auditable, and expiring.
- Production deployment is not part of the MVP.

---

## REQUIRED PROJECT STRUCTURE

Create or align the repo to this structure:

```text
xc-agentforce-cost-calculator/
  sfdx-project.json

  force-app/
    core/
      default/
        applications/
        classes/
        lwc/
        objects/
        permissionsets/
        customPermissions/
        tabs/
        flexipages/

    demo-harness/
      default/
        classes/
        lwc/
        permissionsets/
        customPermissions/
        customMetadata/
        staticresources/

  config/
    scratch/
      synthetic-test-scratch-def.json
      dev-scratch-def.json

    demo-scenarios/
      known-answer-small.json
      standard-flex.json
      deferred-hotspot.json
      conversation-pricing.json
      unallocated-usage.json
      missing-contract-rate.json

  scripts/
    mvp/
      01-create-synthetic-test-org.sh
      02-bootstrap-agentforce-sandbox.sh

    package/
      build-core-package.sh
      build-demo-harness-package.sh
      install-core-package.sh
      install-demo-harness-package.sh

    test/
      run-apex-tests.sh
      run-data-health-check.sh
      run-demo-readiness-check.sh
      collect-debug-artifacts.sh

    validate/
      no-demo-in-core.sh
      package-composition-check.sh

  scripts/apex/
    seedSyntheticData.apex
    validateSyntheticReadiness.apex
    validateSandboxReadiness.apex
    runDataHealth.apex
    resetSyntheticData.apex
```

---

## PACKAGE/SOURCE MODEL

Implement two source areas:

### Core

The Core app is customer-installable and contains no synthetic/demo tooling.

Core includes:
- Ledger objects
- Staging objects
- Import run tracking
- Case/conversation linking
- Org configuration
- Cost calculation
- CSV import
- Data health
- Dashboard
- Grouped report
- Case explorer
- Admin setup
- Audit logging
- Permission sets

### Demo Harness

The Demo Harness is for XC dev/demo/test usage only.

Demo Harness includes:
- Synthetic data factory
- Scenario loader
- Demo seeder
- Demo reset
- Demo readiness validator
- Synthetic data generator LWC
- Synthetic data generator LWC
- Internal demo permission set
- Custom permission gate
- Demo scenario static resources

---

## STEP 1 SCRIPT REQUIREMENT

Build:

```bash
scripts/mvp/01-create-synthetic-test-org.sh
```

The script must:

1. Check prerequisites:
   - Salesforce CLI
   - Git
   - Node, if needed
   - jq, if used
   - Dev Hub authentication
2. Check scratch org limits.
3. Create a scratch org.
4. Deploy Core source.
5. Deploy Demo Harness source.
6. Assign:
   - `XC_AFCC_Admin`
   - `XC_AFCC_Internal_Demo_Admin`
7. Seed deterministic synthetic data using a scenario JSON file.
8. Run data health.
9. Run Apex tests.
10. Run readiness validation.
11. Open the Salesforce app.
12. Print:
   - org alias
   - scenario
   - case count
   - ledger row count
   - deferred case count
   - unallocated usage percentage
   - suggested demo question
   - app/dashboard/case explorer URLs where possible

Support options:

```bash
--scenario deferred-hotspot
--volume small|medium|large
--alias xc-afcc-synth-test
--duration-days 14
--fresh
--reuse-org <alias>
--reset-data
```

---

## STEP 2 SCRIPT REQUIREMENT

Build:

```bash
scripts/mvp/02-bootstrap-agentforce-sandbox.sh
```

The script must:

1. Accept a target org alias.
2. Verify the target org is not production.
3. Deploy Core source only.
4. Confirm Demo Harness metadata is not present.
5. Assign `XC_AFCC_Admin`.
6. Create default org config if missing.
7. Discover native Service Cloud and Agentforce source objects.
8. Sync native usage into the cost ledger when source rows exist.
9. Run data health.
10. Run sandbox readiness validation.
11. Open the Salesforce app.

Support options:

```bash
--target-org <alias>
--deploy-source
--install-package
--csv <path> # fallback only
--validate-only
```

If native usage source objects exist but no usage data exists, the script should report:

```text
Native Source Ready: YES
Analysis Ready: NO - Native Agentforce usage data not available yet
```

---

## REQUIRED SALESFORCE OBJECTS

Create these Core custom objects:

- `XC_AFCC_Cost_Ledger__c`
- `XC_AFCC_Usage_Staging__c`
- `XC_AFCC_Case_Conversation_Link__c`
- `XC_AFCC_Org_Config__c`
- `XC_AFCC_Import_Run__c`
- `XC_AFCC_Data_Health_Check__c`
- `XC_AFCC_Audit_Log__c`

Use fields specified in `docs/SALESFORCE_METADATA_SPEC.md`.

---

## REQUIRED CORE APEX CLASSES

Create these Core classes:

- `XC_AFCC_EnvironmentService`
- `XC_AFCC_CostCalculationService`
- `XC_AFCC_CostLedgerService`
- `XC_AFCC_UsageStagingService`
- `XC_AFCC_CsvImportService`
- `XC_AFCC_DataHealthService`
- `XC_AFCC_ReportQueryService`
- `XC_AFCC_CaseCostExplainService`
- `XC_AFCC_SetupController`
- `XC_AFCC_DashboardController`
- `XC_AFCC_GroupedReportController`
- `XC_AFCC_CaseExplorerController`
- `XC_AFCC_AuditLogService`

---

## REQUIRED DEMO HARNESS APEX CLASSES

Create these Demo Harness classes:

- `XC_AFCC_SyntheticDataFactory`
- `XC_AFCC_DemoScenarioService`
- `XC_AFCC_DemoSeeder`
- `XC_AFCC_DemoResetService`
- `XC_AFCC_DemoGuardService`
- `XC_AFCC_DemoReadinessService`

Demo Harness must refuse to run unless:
- org is scratch/sandbox/non-production
- current user has the `XC_AFCC_Access_Demo_Harness` custom permission
- if running in a customer sandbox, an expiring override is present

---

## REQUIRED LWC UI

Core LWCs:
- `xcAfccSetupWizard`
- `xcAfccDataHealth`
- `xcAfccCostDashboard`
- `xcAfccGroupedReport`
- `xcAfccCaseExplorer`
- `xcAfccCsvImporter`
- `xcAfccAdminSettings`

Demo Harness LWCs:
- `xcAfccSyntheticDataGenerator`
- `xcAfccDemoScenarioPicker`

---

## SYNTHETIC DATA REQUIREMENTS

The synthetic seed must create both standard Salesforce data and cost-analysis data.

Create:
- Accounts
- Contacts
- Cases
- Case/conversation links
- Usage staging records
- Cost ledger records
- Data health records

Required scenarios:
- `known-answer-small`
- `standard-flex`
- `deferred-hotspot`
- `conversation-pricing`
- `unallocated-usage`
- `missing-contract-rate`

Synthetic data must be deterministic:
- scenario name + seed value must produce the same results every time.
- each scenario must define expected results.
- readiness validation must compare actual results to expected results.

---

## TESTING REQUIREMENTS

Create Apex tests for:
- cost calculation
- CSV import
- synthetic data generation
- data health
- report query
- case explanation
- demo guard
- environment detection
- duplicate import handling
- missing rate handling
- unallocated usage handling

Create script tests for:
- Step 1 synthetic org creation
- Step 2 sandbox bootstrap
- no-demo-in-core validation
- package composition validation

Create a Mac/browser smoke test checklist in docs.

---

## ACCEPTANCE CRITERIA

Step 1 is done when:
- one command creates a working synthetic test org
- dashboard loads with seeded data
- grouped report returns correct totals
- case explorer explains a case
- known-answer math scenario passes
- Apex tests pass
- demo harness is gated
- no demo assets exist in Core
- readiness validator returns PASS

Step 2 is done when:
- one command bootstraps an Agentforce sandbox with Core only
- no synthetic data is present
- no demo harness assets are present
- native Service Cloud and Agentforce source discovery works
- data health runs
- ledger can be populated from native source rows
- reports and case explorer work from live/native data
- readiness validator returns PASS, NATIVE_READY, or READY_FOR_NATIVE_DATA when usage data does not exist yet

---

## IMPLEMENTATION ORDER

1. Create project structure and docs.
2. Create Core objects and fields.
3. Create Core Apex services.
4. Create Core LWCs.
5. Create Demo Harness objects/classes/LWCs.
6. Create demo scenario JSON files.
7. Create Step 1 script.
8. Create synthetic data factory and seeder.
9. Create readiness validators.
10. Create tests.
11. Create Step 2 script.
12. Create CSV importer.
13. Run Mac/browser smoke test and fix defects.
14. Produce MVP readiness scorecard.

---

## OUTPUT EXPECTATION

Make incremental commits or clearly grouped changes. After implementation, provide:

- files changed
- commands run
- test results
- known limitations
- next action

Do not add external services. Do not put synthetic/demo code in Core.
