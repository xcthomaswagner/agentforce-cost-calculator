# CSV Import Contract

## 1. Status

Deprecated for the primary MVP Step 2 flow. CSV import is now a fallback/admin utility only.

Use `MVP_EXECUTION_SPEC_V2.md` and `NATIVE_AGENTFORCE_SOURCE_SPEC.md` as the authority for native Agentforce sandbox analysis.

## 2. Purpose

The CSV import contract lets the Core app ingest customer-provided exported usage data when native Salesforce source discovery cannot be used. It must not be presented as the primary Agentforce sandbox path.

---

## 3. Required CSV Columns

| Column | Required | Description |
|---|---:|---|
| `external_usage_id` | Yes | unique usage row ID |
| `billing_model` | Yes | FLEX_CREDITS or CONVERSATIONS |
| `usage_timestamp` | Yes | ISO date/time preferred |
| `case_id` | No | Salesforce Case ID |
| `case_number` | No | Salesforce Case Number |
| `conversation_id` | No | conversation/session ID |
| `messaging_session_id` | No | optional |
| `agent_name` | No | agent display name |
| `agent_version` | No | agent version |
| `action_name` | No | action name |
| `credits_used` | Conditionally | required for FLEX_CREDITS |
| `conversations_used` | Conditionally | required for CONVERSATIONS |
| `channel` | No | Web, Chat, Voice, Messaging, Other |
| `topic` | No | business topic |
| `queue_name` | No | queue/group |
| `case_outcome` | No | RESOLVED, DEFERRED, ESCALATED, ABANDONED, UNKNOWN |
| `calculation_basis` | No | IMPORTED, ACTUAL, ESTIMATED |
| `raw_payload` | No | optional JSON/source detail |

---

## 4. Validation Rules

- `external_usage_id` must be unique per import/source.
- `billing_model` must be supported.
- `usage_timestamp` must parse.
- Flex Credit rows must have `credits_used`.
- Conversation rows must have `conversations_used`.
- Numeric fields must be non-negative.
- Missing Case ID is allowed but becomes unallocated usage.
- Invalid rows go to failed staging status, not directly to ledger.

---

## 5. Example: Flex Credit

```csv
external_usage_id,billing_model,usage_timestamp,case_number,conversation_id,agent_name,action_name,credits_used,channel,topic,queue_name,case_outcome,calculation_basis
u-001,FLEX_CREDITS,2026-05-01T10:00:00Z,00010001,c-001,Service Agent A,Classify Intent,20,Web,Billing,Billing Support,DEFERRED,IMPORTED
```

---

## 6. Example: Conversation Pricing

```csv
external_usage_id,billing_model,usage_timestamp,case_number,conversation_id,agent_name,conversations_used,channel,topic,queue_name,case_outcome,calculation_basis
u-101,CONVERSATIONS,2026-05-01T10:00:00Z,00010044,c-101,Service Agent B,1,Web,Returns,Returns,RESOLVED,IMPORTED
```
