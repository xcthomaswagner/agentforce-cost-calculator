# Conversation Runner Contract

`scripts/mvp/03-run-prod-like-agentforce-sandbox.sh` can call a channel-specific conversation runner after it seeds real Salesforce business records.

The runner is intentionally external to Core metadata. It should drive the configured Agentforce runtime through the same channel production uses, such as Agent API, Enhanced Web Chat, or BYOC Messaging. It must not insert `MessagingSession`, `Conversation`, `AgentWork`, staging, or ledger records directly.

## Agent API Runner

`scripts/conversation/run-agent-api-conversations.mjs` drives the Salesforce Agent API directly. It starts real Agentforce sessions, sends support-intake utterances tied to seeded `Case` records, and ends each session.

Example:

```bash
scripts/conversation/run-agent-api-conversations.mjs \
  --target-org agentcalc-af \
  --agent-id 0Xx... \
  --eca-id 0xI... \
  --consumer-id 888... \
  --run-key afcc-prod-like-YYYYMMDDHHMMSS \
  --case-subject-prefix "AFCC Prod-Like afcc-prod-like-YYYYMMDDHHMMSS Case" \
  --count 150
```

Prerequisites:

- Agentforce platform enabled.
- Active Agentforce service agent.
- External Client App with OAuth scopes `Api`, `RefreshToken`, `Chatbot`, and `SFApiPlatform`.
- OAuth client credentials flow enabled with an API-only integration user.
- The integration user's profile or permission set pre-authorized for the External Client App.
- REST access to External Client App consumer secrets enabled while the runner executes.

Important runtime note: Agent API sessions are real Agentforce runtime sessions, but they do not populate `MessagingSession`, `Conversation`, or `AgentWork` in this org. To test those objects, use a real Messaging channel such as Enhanced Web Chat or BYOC Messaging and point the conversation runner at that channel.

## Enhanced Web Chat Runner

`scripts/conversation/run-enhanced-web-chat-conversations.mjs` drives the real Enhanced Web Chat browser widget. It opens a fresh browser context for each Case, authenticates through the local Salesforce CLI session, opens the chat launcher, waits for the agent greeting, sends a realistic customer message, validates the visible answer, captures screenshots, and confirms the Agentforce event log shows the live case lookup action.

Example single-case smoke test:

```bash
scripts/conversation/run-enhanced-web-chat-conversations.mjs \
  --target-org agentcalc-af \
  --chat-url "https://orgfarm-6743bee981-dev-ed--c.develop.vf.force.com/apex/ESWXCAFCCAgentforceCos1778718120601" \
  --case-number 00001322 \
  --count 1
```

Example custom cost-question smoke test:

```bash
scripts/conversation/run-enhanced-web-chat-conversations.mjs \
  --target-org agentcalc-af \
  --chat-url "https://orgfarm-6743bee981-dev-ed--c.develop.vf.force.com/apex/ESWXCAFCCAgentforceCos1778718120601" \
  --message "What is total Agentforce cost?" \
  --expect-text "total Agentforce cost" \
  --expect-text "0.95" \
  --expect-text "190" \
  --event-action-regex "actionName: Answer_Cost_Question_Live_.*isSuccessful: true" \
  --count 1
```

Example prod-like run through Step 3:

```bash
scripts/mvp/03-run-prod-like-agentforce-sandbox.sh \
  --target-org agentcalc-af \
  --case-count 150 \
  --conversation-count 150 \
  --enhanced-web-chat-url "https://orgfarm-6743bee981-dev-ed--c.develop.vf.force.com/apex/ESWXCAFCCAgentforceCos1778718120601"
```

Validation performed per run:

- Visible reply includes the expected Case number, status, and priority.
- For custom prompts, visible reply includes every `--expect-text` value.
- Failure phrases such as "unable to look up" fail the run.
- A screenshot is written for every conversation.
- `ConversationDefinitionEventLog` is polled until the expected action success is visible. The default is `Look_Up_Case_Status_Live`; custom prompts can pass `--event-action-regex`.

Prerequisites:

- `npm install` has been run locally so Playwright is available.
- The target org is authenticated with Salesforce CLI.
- Enhanced Web Chat test page is reachable by the authenticated user.
- The Agentforce service agent is active and its Support Status topic uses `Look Up Case Status Live`.

## Environment Variables

The Step 3 script passes:

| Variable | Meaning |
|---|---|
| `XC_AFCC_TARGET_ORG` | Salesforce CLI alias for the sandbox. |
| `XC_AFCC_RUN_KEY` | Unique run key used in seeded Case subjects. |
| `XC_AFCC_CASE_COUNT` | Requested number of seeded business cases. |
| `XC_AFCC_CASE_SUBJECT_PREFIX` | Prefix for seeded Case subjects. |
| `XC_AFCC_EWC_URL` | Enhanced Web Chat test page URL for the browser runner. |
| `XC_AFCC_EWC_MESSAGE` | Optional custom prompt for a one-off smoke test. |
| `XC_AFCC_EWC_EXPECT_TEXT` | Optional pipe-delimited visible text expectations for custom prompts. |
| `XC_AFCC_EWC_EVENT_ACTION_REGEX` | Optional event-log action success pattern. |

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
