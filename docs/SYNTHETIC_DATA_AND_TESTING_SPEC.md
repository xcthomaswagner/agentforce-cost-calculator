# Synthetic Data and Testing Spec

## 1. Purpose

Synthetic data is the first release milestone. It allows XC developers to prove the complete Salesforce app without Agentforce, Omni-Channel, Messaging, or Digital Engagement.

Synthetic data must be realistic enough for demos and deterministic enough for automated testing.

---

## 2. Synthetic Data Principles

- Synthetic data lives only in Demo Harness.
- Synthetic data must be marked as `SYNTHETIC`.
- Synthetic data generation must be deterministic.
- Synthetic data must include standard Salesforce records.
- Synthetic data must include ledger records.
- Synthetic data must include edge cases and bad-data scenarios.
- Synthetic data reset must delete only synthetic records.

---

## 3. Required Synthetic Salesforce Records

Generate:

- `Account`
- `Contact`
- `Case`
- `XC_AFCC_Case_Conversation_Link__c`
- `XC_AFCC_Usage_Staging__c`
- `XC_AFCC_Cost_Ledger__c`
- `XC_AFCC_Data_Health_Check__c`
- `XC_AFCC_Org_Config__c`

Do not require:
- Agentforce
- Omni-Channel
- Messaging
- Digital Engagement

---

## 4. Scenario JSON Format

Each scenario file lives under:

```text
config/demo-scenarios/
```

Example:

```json
{
  "scenarioName": "deferred-hotspot",
  "seed": 12345,
  "billingModel": "FLEX_CREDITS",
  "caseCount": 300,
  "accountCount": 40,
  "contactCount": 120,
  "agentCount": 4,
  "queueNames": [
    "Billing Support",
    "Order Support",
    "Returns",
    "Product Help",
    "Account Support"
  ],
  "hotspotQueue": "Billing Support",
  "dateRangeDays": 30,
  "creditRate": 0.005,
  "conversationRate": 2.0,
  "deferredRate": 0.35,
  "escalatedRate": 0.15,
  "abandonedRate": 0.05,
  "resolvedRate": 0.45,
  "unallocatedUsageRate": 0.08,
  "expectedResults": {
    "minimumCases": 300,
    "minimumDeferredCases": 90,
    "minimumLedgerRows": 1000,
    "topQueue": "Billing Support",
    "minimumUnallocatedUsagePercent": 7.0,
    "maximumUnallocatedUsagePercent": 9.0
  }
}
```

---

## 5. Required Scenarios

### 5.1 `known-answer-small`

Purpose: prove math.

Data:
- 3 Cases
- 5 Flex Credit actions
- 100 total credits
- credit rate `$0.005`
- expected total cost `$0.50`

Expected:
- total credits = 100
- total cost = 0.50
- one deferred case
- one resolved case
- one escalated case

### 5.2 `standard-flex`

Purpose: normal Flex Credit demo/test.

Data:
- 100 Cases
- mixed outcomes
- action-level ledger rows
- 20 credits per standard action

### 5.3 `deferred-hotspot`

Purpose: show business insight.

Data:
- Billing Support has a high deferred cost share.
- Good for dashboard and grouped report demos.

### 5.4 `conversation-pricing`

Purpose: prove Conversation pricing.

Data:
- conversation-based ledger rows
- no credits
- conversation rate applied

### 5.5 `unallocated-usage`

Purpose: prove data health.

Data:
- some usage rows without linked cases
- readiness should warn, not fail

### 5.6 `missing-contract-rate`

Purpose: prove estimated-cost handling.

Data:
- rate missing
- system applies default rate
- calculation basis marked `ESTIMATED`

---

## 6. Determinism

Synthetic generation must use a seed.

Same scenario + same seed must produce:

- same counts
- same cost totals
- same case numbers
- same top queue
- same readiness results

This is required for reproducible defects.

---

## 7. Data Health Test Requirements

Data health should validate:

- staging row count
- ledger row count
- failed row count
- staging-to-ledger reconciliation
- total credits imported/staged
- total credits ledgered
- total conversations staged
- total conversations ledgered
- total allocated cost
- unallocated usage percentage
- case linkage percentage
- deferred case count
- estimated-cost rows
- duplicate source IDs
- missing timestamps

---

## 8. Known-Answer Tests

The test suite must include a tiny deterministic scenario and assert exact values.

Example:

```text
credits = 100
rate = 0.005
expected cost = 0.50
```

The application must pass this before larger demo scenarios are considered valid.

---

## 9. Negative Tests

Test failures and edge cases:

- missing billing model
- missing rate
- duplicate usage ID
- bad CSV date
- invalid billing model
- usage row with no case
- conversation linked to multiple cases
- report group-by unsupported field
- user lacks demo harness permission
- demo harness attempts to run in production-like org
- no deferred cases found

---

## 10. Readiness Validation

`XC_AFCC_DemoReadinessService` should return a structured scorecard:

```json
{
  "result": "PASS",
  "scenario": "deferred-hotspot",
  "checks": [
    { "name": "Core data exists", "status": "PASS" },
    { "name": "Ledger rows exist", "status": "PASS" },
    { "name": "Deferred cases exist", "status": "PASS" },
    { "name": "Top queue matches expected", "status": "PASS" }
  ],
  "summary": {
    "cases": 300,
    "ledgerRows": 1850,
    "deferredCases": 104,
    "allocatedCost": 482.75
  }
}
```
