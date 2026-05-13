# Prod-Like Agentforce Sandbox Harness Spec

## Purpose

This spec defines the preferred production-like validation path for Agentforce Cost Calculator.

The goal is to exercise a real Agentforce-enabled sandbox as closely as possible to production without deploying to production and without directly manufacturing Agentforce runtime records.

## Principle

The harness may seed real Salesforce business records:

- `Account`
- `Contact`
- `Case`

The harness must not directly create runtime records such as:

- `MessagingSession`
- `Conversation`
- `AgentWork`

Those records should be created by Salesforce runtime through the configured Agentforce, Messaging, Omni-Channel, Enhanced Web Chat, Agent API, or BYOC path.

## Script

Primary script:

```bash
scripts/mvp/03-run-prod-like-agentforce-sandbox.sh \
  --target-org agentforce-sandbox \
  --deploy-core \
  --case-count 150 \
  --conversation-runner scripts/conversation/customer-runner.sh
```

## Script Responsibilities

The script must:

1. Confirm the target org is authenticated.
2. Refuse production.
3. Deploy Core only when requested.
4. Confirm Demo Harness metadata is absent.
5. Assign `XC_AFCC_Admin`.
6. Create default Core config if needed.
7. Seed real Accounts, Contacts, and Cases.
8. Validate Agentforce runtime object availability.
9. Run an optional channel-specific conversation runner.
10. Sync native runtime records into staging and ledger rows.
11. Run data health.
12. Open the Core setup page.
13. Print a readiness scorecard.

## Admin Prerequisites

The sandbox owner must configure:

- Agentforce Service Agent.
- Messaging channel, Enhanced Web Chat, Agent API access, or BYOC channel.
- Routing or service deployment needed by that channel.
- Case find/create/update action used by the agent.
- Permission model that allows the running user or integration user to invoke the channel.

The calculator should validate these prerequisites where possible, but it should not silently create customer-specific Agentforce setup.

## Conversation Runner Contract

The conversation runner is channel-specific. It receives environment variables from the Step 3 script and is responsible for driving conversations through the real configured runtime.

The runner must:

- Start real conversations.
- Send realistic customer utterances.
- Include enough identifying context for the agent to find or update seeded Cases.
- End conversations when the channel supports it.
- Exit non-zero when the runtime conversation path fails.

The runner must not insert Agentforce runtime records or XC ledger records directly.

## Success Criteria

Step 3 is successful when:

- 150 seeded real Cases exist.
- The configured channel creates real runtime conversation/session/work records.
- Core native sync creates `LIVE` staging rows.
- Core ledger builder creates `LIVE` ledger rows.
- Dashboard, grouped report, data health, and case explorer work from `LIVE` data.
- Unallocated usage is visible and explainable.
- Any estimated cost rows are auditable.

## Why This Exists

The deterministic synthetic scratch-org path proves math and UX without Agentforce licensing. Step 3 proves production-like runtime behavior in an Agentforce-enabled sandbox.

Both are required for confidence. They test different risks.
