# MVP Execution Spec — XC Agentforce Cost Calculator

> Superseded for Step 2 by `MVP_EXECUTION_SPEC_V2.md`. V1 incorrectly treated CSV import as the primary Agentforce sandbox path. CSV is now fallback only; native Agentforce/Service Cloud source discovery is the primary Step 2 path.

## 1. Product Goal

Build a Salesforce-native application that calculates and explains Agentforce-related service cost by Case, Queue, Agent, Topic, Channel, Outcome, and time period.

The MVP has two scripted stages:

1. **Synthetic Test Environment**
   - Create a scratch org.
   - Deploy Core and Demo Harness.
   - Seed deterministic synthetic data.
   - Run validation/tests.
   - Open a ready app.

2. **Agentforce Sandbox Without Synthetic Data**
   - Bootstrap an existing Agentforce-enabled sandbox.
   - Deploy Core only.
   - Analyze native Service Cloud and Agentforce data.
   - Run data health and reporting.
   - Prove the application works without synthetic/demo tooling.

Production deployment is excluded from the MVP.

---

## 2. Core Assumptions

- The MVP remains fully inside Salesforce.
- No external service, database, middleware, or LLM is introduced.
- Step 1 does not require Agentforce, Omni-Channel, Messaging, or Digital Engagement.
- Step 1 uses standard Salesforce `Account`, `Contact`, and `Case` records plus custom XC_AFCC objects.
- Step 2 uses Core only and does not install demo/synthetic metadata.
- All metadata uses the `XC_AFCC` prefix.
- The solution is source-controlled in GitHub.
- Scripts are the primary deployment and validation interface.

---

## 3. Deployment Modes

| Mode | Target Org | Source/Packages | Data | Purpose |
|---|---|---|---|---|
| Dev | Scratch org | Source deploy | Developer-controlled | Fast iteration |
| Synthetic Test | Scratch org | Core + Demo Harness | Synthetic | MVP Step 1 |
| Agentforce Sandbox | Existing sandbox | Core only | Native Service Cloud/Agentforce | MVP Step 2 |
| Production | Production org | Core only | Live | Out of scope for MVP |

---

## 4. Package Model

### Core

Customer-installable and production-safe. Contains no synthetic/demo tooling.

### Demo Harness

XC-only testing/demo package/source area. Contains synthetic data generation, demo seeding, readiness validation, and demo-only UI.

The Demo Harness must not be required for Core functionality.

---

## 5. Functional Capabilities

### Core Capabilities

- Configure billing model:
  - Flex Credits
  - Conversations
  - Unknown / not configured
- Configure rates:
  - contract credit rate
  - contract conversation rate
  - fallback/default rates
- Discover and sync native Service Cloud/Agentforce usage records.
- Keep CSV import as an explicit fallback only.
- Stage raw usage records.
- Normalize usage into ledger rows.
- Link usage to Cases where possible.
- Classify outcomes:
  - RESOLVED
  - DEFERRED
  - ESCALATED
  - ABANDONED
  - UNKNOWN
- Calculate allocated cost.
- Run data health checks.
- Display dashboard cards.
- Run grouped reports.
- Explain case-level costs.
- Export or copy report data where practical.
- Audit setup and sensitive configuration changes.

### Demo Harness Capabilities

- Generate deterministic synthetic data.
- Seed Accounts, Contacts, Cases, conversation links, staging records, ledger rows, and data health records.
- Reset only synthetic data.
- Validate scenario expected results.
- Provide a ready-demo checklist and output.

---

## 6. Step 1: Synthetic Test Environment

### Goal

A developer runs one command and receives a ready Salesforce app with synthetic data.

### Primary Script

```bash
scripts/mvp/01-create-synthetic-test-org.sh --scenario deferred-hotspot --volume medium
```

### Required Behavior

The script must:

1. Check local prerequisites.
2. Check Dev Hub connection.
3. Check scratch org limits.
4. Create or reuse a scratch org.
5. Deploy Core.
6. Deploy Demo Harness.
7. Assign permissions.
8. Seed deterministic synthetic data.
9. Run data health.
10. Run Apex tests.
11. Run readiness validation.
12. Open the Salesforce app.
13. Print a readiness scorecard.

### Step 1 Output

The script should print:

```text
Synthetic Test Org Ready: YES
Scenario: deferred-hotspot
Billing Model: FLEX_CREDITS
Cases: 300
Ledger Rows: 1850
Deferred Cases: 104
Unallocated Usage: 8%
Suggested Question: What did deferred cases cost by queue last month?
```

---

## 7. Step 2: Agentforce Sandbox Without Synthetic Data

### Goal

A developer runs one command against an existing sandbox and the Core app is ready for native Service Cloud/Agentforce usage analysis.

### Primary Script

```bash
scripts/mvp/02-bootstrap-agentforce-sandbox.sh --target-org my-agentforce-sandbox
```

### Required Behavior

The script must:

1. Confirm target org is authorized.
2. Confirm target org is not production.
3. Deploy Core only.
4. Verify Demo Harness is absent.
5. Assign Core admin permission.
6. Create default configuration if missing.
7. Discover native Service Cloud/Agentforce source objects.
8. Sync/analyze native source rows.
9. Run data health.
10. Open the app.
11. Print readiness state.

### Possible Output

If usage data exists:

```text
Sandbox Analysis Ready: YES
```

If usage data does not exist yet:

```text
Native Source Ready: NO
Analysis Ready: NO - Native Agentforce/Service Cloud data not available yet
```

---

## 8. Data Flow

### Native Usage Flow

```text
MessagingSession / AgentWork / Conversation
  -> XC_AFCC_Import_Run__c
  -> XC_AFCC_Usage_Staging__c
  -> validation
  -> normalization
  -> XC_AFCC_Cost_Ledger__c
  -> data health
  -> reports / dashboard / case explorer
```

### Synthetic Flow

```text
Scenario JSON
  -> XC_AFCC_DemoScenarioService
  -> XC_AFCC_SyntheticDataFactory
  -> Account / Contact / Case
  -> XC_AFCC_Case_Conversation_Link__c
  -> XC_AFCC_Usage_Staging__c
  -> XC_AFCC_Cost_Ledger__c
  -> readiness validation
```

---

## 9. Cost Calculation

### Flex Credits

```text
Allocated Cost = Credits Used × Credit Rate
```

### Conversation Pricing

```text
Allocated Cost = Conversations Used × Conversation Rate
```

### Calculation Basis

Each ledger row must be marked as one of:

- ACTUAL
- IMPORTED
- SYNTHETIC
- ESTIMATED
- ALLOCATED
- INCOMPLETE

### Data Set Type

Each ledger/staging row must be marked as one of:

- SYNTHETIC
- IMPORTED
- LIVE

---

## 10. Data Health

Data Health must check:

- org config exists
- billing model configured
- rates configured or defaulted
- staging rows exist
- ledger rows exist
- live/imported rows reconcile to ledger rows
- case linkage percentage
- unallocated usage percentage
- deferred cases found
- duplicate usage IDs
- failed staging records
- unsupported billing models
- missing timestamps
- missing cost basis

---

## 11. Security and Gating

### Core

- Uses Core permission sets.
- No demo/synthetic metadata.
- No unrestricted SOQL from user input.
- Audits sensitive configuration changes.

### Demo Harness

Must require:

- non-production/sandbox/scratch environment
- custom permission `XC_AFCC_Access_Demo_Harness`
- internal permission set `XC_AFCC_Internal_Demo_Admin`

For customer sandbox override:

- explicit override metadata/config
- reason
- approving person
- expiration date
- target org ID

Production must always block demo harness execution.

---

## 12. Out of Scope

- Production deployment
- AppExchange/security review
- Managed packaging
- Digital Wallet direct connector
- Natural-language Ask Agent
- External data warehouse
- External middleware
- External LLM query agent
