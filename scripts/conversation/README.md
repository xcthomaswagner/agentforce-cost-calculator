# Conversation Runner Contract

`scripts/mvp/03-run-prod-like-agentforce-sandbox.sh` can call a channel-specific conversation runner after it seeds real Salesforce business records.

The runner is intentionally external to Core metadata. It should drive the configured Agentforce runtime through the same channel production uses, such as Agent API, Enhanced Web Chat, or BYOC Messaging. It must not insert `MessagingSession`, `Conversation`, `AgentWork`, staging, or ledger records directly.

## Environment Variables

The Step 3 script passes:

| Variable | Meaning |
|---|---|
| `XC_AFCC_TARGET_ORG` | Salesforce CLI alias for the sandbox. |
| `XC_AFCC_RUN_KEY` | Unique run key used in seeded Case subjects. |
| `XC_AFCC_CASE_COUNT` | Requested number of seeded business cases. |
| `XC_AFCC_CASE_SUBJECT_PREFIX` | Prefix for seeded Case subjects. |

## Runner Responsibilities

1. Authenticate to the configured Agentforce/Messaging channel.
2. Start one real runtime conversation per seeded case, or the agreed sample size.
3. Send realistic customer utterances.
4. Include enough case-identifying context for the agent action or routing flow to find/update the seeded case.
5. End or close the conversation where the channel supports it.
6. Exit non-zero if the runtime path fails.

## Required Prohibitions

- Do not create `MessagingSession`, `Conversation`, or `AgentWork` records directly.
- Do not create `XC_AFCC_Usage_Staging__c` or `XC_AFCC_Cost_Ledger__c` records directly.
- Do not run against production.
- Do not send real customer PII in scripted conversations.
