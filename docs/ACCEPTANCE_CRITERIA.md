# Acceptance Criteria

## Release Definition

The release consists of two completed steps:

1. Script-created synthetic test environment.
2. Script-bootstrapped Agentforce sandbox without synthetic data.

Production deployment is not part of this release.

---

## Step 1 Acceptance Criteria: Synthetic Test Environment

Step 1 is complete when:

### Deployment

- [ ] A developer can run `scripts/mvp/01-create-synthetic-test-org.sh`.
- [ ] The script creates a scratch org.
- [ ] The script deploys Core.
- [ ] The script deploys Demo Harness.
- [ ] The script assigns `XC_AFCC_Admin`.
- [ ] The script assigns `XC_AFCC_Internal_Demo_Admin`.
- [ ] The script opens the app.

### Data

- [ ] Accounts are created.
- [ ] Contacts are created.
- [ ] Cases are created.
- [ ] Case/conversation links are created.
- [ ] Usage staging rows are created.
- [ ] Cost ledger rows are created.
- [ ] Data health rows are created.
- [ ] Data is marked `SYNTHETIC`.
- [ ] Synthetic data can be reset without affecting non-synthetic data.

### Functionality

- [ ] Dashboard loads.
- [ ] Dashboard shows non-zero total cost.
- [ ] Dashboard shows deferred case cost.
- [ ] Grouped report runs.
- [ ] Grouped report supports grouping by Queue.
- [ ] Grouped report supports filtering by Outcome.
- [ ] Case Explorer explains a case.
- [ ] Case Explorer shows line items.
- [ ] Related Case link opens a Salesforce Case.
- [ ] Data Health runs and displays results.

### Correctness

- [ ] Known-answer scenario passes exact expected totals.
- [ ] Flex Credit cost calculation is correct.
- [ ] Conversation cost calculation is correct.
- [ ] Missing rate marks results as `ESTIMATED`.
- [ ] Unallocated usage appears in Data Health.
- [ ] Staging-to-ledger reconciliation works.
- [ ] Duplicate source usage IDs are handled safely.

### Gating

- [ ] Demo Harness requires custom permission.
- [ ] Demo Harness refuses production-like orgs.
- [ ] Core contains no Demo Harness metadata.
- [ ] `no-demo-in-core.sh` passes.

### Tests

- [ ] Apex tests pass.
- [ ] Readiness validator returns PASS.
- [ ] Mac/browser smoke checklist passes.

---

## Step 2 Acceptance Criteria: Native Agentforce Sandbox Without Synthetic Data

Step 2 is complete when:

### Deployment

- [ ] A developer can run `scripts/mvp/02-bootstrap-agentforce-sandbox.sh --target-org <alias>`.
- [ ] The script validates target org is not production.
- [ ] The script deploys Core only.
- [ ] The script assigns `XC_AFCC_Admin`.
- [ ] The script opens the app.

### Absence of Synthetic Tooling

- [ ] Demo Harness classes are absent.
- [ ] Demo Harness LWCs are absent.
- [ ] Demo permission set is absent.
- [ ] No synthetic generator is visible.
- [ ] No synthetic records exist.

### Core Functionality

- [ ] Setup wizard loads.
- [ ] Org config can be created.
- [ ] Billing model can be configured.
- [ ] Rate can be configured.
- [ ] Native Service Cloud objects are accessible: Account, Contact, Case.
- [ ] Native Agentforce/Service Cloud source discovery runs.
- [ ] At least one supported native source object is detected when the target org is Agentforce-enabled.
- [ ] Native source sync creates LIVE staging rows.
- [ ] Ledger builder creates LIVE ledger rows.
- [ ] CSV import is labeled fallback/deprecated and is not the primary path.
- [ ] Data health runs.
- [ ] Dashboard/report/case explorer work after native sync.

### Readiness

- [ ] If no native source data exists, script reports `READY_FOR_NATIVE_DATA` or `MISSING_NATIVE_SOURCE`.
- [ ] If usage data exists, script reports `ANALYSIS_READY`.
- [ ] Sandbox readiness validator returns PASS, NATIVE_READY, or READY_FOR_NATIVE_DATA.
