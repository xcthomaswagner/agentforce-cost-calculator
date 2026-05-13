# Execution Spec V2 - Native Agentforce Cost Calculator

## 1. Product Correction

V1 incorrectly made CSV import the primary path for the Agentforce sandbox flow. V2 replaces that with native Salesforce analysis.

The Core product is intended to run in an Agentforce-enabled Salesforce org with Service Cloud data. It should inspect and use native Salesforce records first, especially `Case`, `Account`, `Contact`, and available Agentforce/Service Cloud conversation or work objects.

CSV import is deprecated as the main path. It may remain as an explicit fallback/admin utility, but it must not be the primary setup experience, readiness state, acceptance criterion, or demo story for Step 2.

## 2. Release Stages

### Step 1: Synthetic Test Environment

Step 1 still creates a scratch org that does not require Agentforce, Omni-Channel, Messaging, or Digital Engagement.

The Demo Harness may create deterministic synthetic `Account`, `Contact`, `Case`, staging, link, and ledger records so developers can test the calculator without licensed Agentforce features.

### Step 2: Native Agentforce Sandbox Analysis

Step 2 runs Core only against an existing Agentforce-enabled sandbox or production-like org.

The script must:

1. Confirm the target org is authenticated.
2. Confirm the target org is not production for release execution.
3. Deploy or install Core only.
4. Verify Demo Harness metadata is absent.
5. Assign `XC_AFCC_Admin`.
6. Create default org config if missing.
7. Discover native Service Cloud and Agentforce source objects.
8. Confirm `Account`, `Contact`, and `Case` access.
9. Confirm at least one supported native usage source is available when the org is expected to be Agentforce-enabled.
10. Sync/analyze native records into `XC_AFCC_Cost_Ledger__c`.
11. Run data health and native readiness validation.
12. Open the Core app.

### Step 3: Prod-Like Agentforce Sandbox Harness

Step 3 is the preferred way to create production-like validation data in a sandbox.

It seeds real `Account`, `Contact`, and `Case` records, then drives the configured Agentforce runtime through a channel-specific conversation runner. Salesforce must create the runtime conversation/work records. The harness must not directly insert `MessagingSession`, `Conversation`, or `AgentWork` records.

The script is:

```bash
scripts/mvp/03-run-prod-like-agentforce-sandbox.sh --target-org agentforce-sandbox --case-count 150
```

Add `--conversation-runner <path>` after the sandbox's Agentforce channel is configured.

## 3. Native Source Model

Core must use dynamic object discovery so it can deploy in scratch orgs without optional Service Cloud/Agentforce objects.

Preferred native sources:

| Priority | Source | Purpose |
|---:|---|---|
| 1 | `MessagingSession` | Customer conversation/session anchor for Service Cloud messaging. |
| 2 | `AgentWork` | Routed work assignment for agent/service work, often linked to a Case. |
| 3 | `Conversation` | Conversation-level source where available. |
| 4 | Data Cloud Agent Work DMO | Future source for larger-scale analytics, not required for Core. |
| 5 | Conversation Data API | Future transcript/event detail source, not required for Core because it is not SOQL-native. |

Core may materialize normalized records into `XC_AFCC_Usage_Staging__c` and `XC_AFCC_Cost_Ledger__c`, but the source system must be marked `LIVE` and the calculation basis must communicate whether the value is actual, allocated, or estimated.

Step 3 must use the same native source model after the runtime conversations complete.

## 4. Native Readiness States

| State | Meaning |
|---|---|
| `NATIVE_READY` | Required Core config exists, standard Service Cloud objects are accessible, and at least one supported native source object exists. |
| `ANALYSIS_READY` | Native source rows have been synced into ledger rows and reports can run. |
| `READY_FOR_NATIVE_DATA` | Core is installed, but no supported native Agentforce/Service Cloud source rows are available yet. |
| `MISSING_NATIVE_SOURCE` | Core is installed, but the org lacks supported native Agentforce/Service Cloud source objects or permissions. |
| `CONFIG_REQUIRED` | Required Core config or rates are missing. |

## 5. CSV Fallback Policy

CSV import is not the primary Step 2 flow.

CSV may remain available only when explicitly enabled by an admin for fallback testing, migration support, or one-time customer-provided exports. The UI and scripts must label it as a fallback path.

Readiness output must not say "ready for import" as the main success state. It must say whether the org is ready for native analysis.

## 6. Acceptance Criteria Delta From V1

Step 2 is complete only when:

- Core can discover native Service Cloud/Agentforce objects.
- The app can show native source availability.
- The app can sync/analyze native source records without synthetic data.
- Data health distinguishes native source absence from empty ledger data.
- Dashboard, grouped report, and case explorer work from `LIVE` ledger rows.
- Demo Harness and synthetic tools are absent.
- CSV is not visible as the primary path.

## 7. Salesforce References

Salesforce's Agentforce developer guide identifies Agent API, Agentforce DX, Enhanced Chat v2, Enhanced In-App Chat, and session tracing as Agentforce developer capabilities. Salesforce Messaging documentation states that conversation data spans on-platform and off-platform objects; on-platform objects are SOQL-queryable, while detailed message entries may require Conversation Data APIs or Data Cloud.

Implementation must therefore start with SOQL-native object discovery and leave off-platform transcript/event ingestion as a future enhancement.
