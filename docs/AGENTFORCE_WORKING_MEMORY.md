# Agentforce Working Memory

This document captures implementation findings from the Agentforce production-like sandbox work so a future session can resume without rediscovering the same issues.

Do not store Salesforce access tokens, frontdoor URLs, passwords, or session cookies here.

## Current Org Context

- Target org alias: `agentcalc-af`
- Org Id: `00Dg500000AFgyrEAD`
- Lightning host: `orgfarm-6743bee981-dev-ed.develop.lightning.force.com`
- Enhanced Web Chat test page: `/apex/ESWXCAFCCAgentforceCos1778718120601`
- Messaging channel Id: `0Mjg5000000BPvxCAG`
- Messaging channel developer name: `XC_AFCC_Agentforce_Cost_Chat`
- Agent label: `Agentforce Cost Service Agent`
- BotDefinition Id: `0Xxg5000000m7tdCAA`
- BotVersion Id: `0X9g50000016Fv3CAE`
- Agent runtime user Id: `005g5000006jXArAAM`
- Agent runtime user profile: `Einstein Agent User`
- Fallback queue Id: `00Gg5000004QROrEAO`

## Test Case Used During Debugging

- Case number: `00001322`
- Case Id: `500g500000Rg60aAAB`
- Subject: `AFCC Prod-Like afcc-prod-like-20260513210015 Case 147 - Order status`
- Status: `New`
- Priority: `High`
- Account: `AFCC Prod-Like Account 147 afcc-prod-like-20260513210015`
- Contact: `AFCC Contact 147`
- Contact email: `afcc+afccprodlike20260513210015+147@example.invalid`

## Why The Agent Gave A Generic Failure Answer

The answer:

> It seems I couldn't retrieve specific details about the next steps for your case due to a technical issue.

was not caused by the Case being absent. The Case exists.

The failures came from the Agentforce action path:

1. The agent runtime user initially did not have enough `Case`, `Account`, and `Contact` access.
2. After granting object access, the agent still selected Salesforce stock Service Cloud case lookup actions.
3. The stock action `SvcCopilotTmpl__GetCaseByVerifiedCaseNumber` is designed for verified-customer service flows. It can return an unusable or unsafe answer even when the Case exists, especially when the conversation identity does not satisfy the verified customer association it expects.
4. The visible chat answer became generic because Agentforce suppressed or could not use the action output.

The important trace evidence was in `ConversationDefinitionEventLog`:

- `Topic classification succeeded: p_16jg5000000TBbB_Support_Status_And_Next_Steps`
- `actionName: SvcCopilotTmpl__GetCaseByVerifiedCaseNumber, isSuccessful: true`
- `Copilot Message: INFORM, Is Output Safe? false`

That means the stock action ran, but the final output was not usable for the customer response.

## Fixes Applied

### Agent Runtime Data Access

Added permission set:

- `force-app/core/default/permissionsets/XC_AFCC_Agent_Service_Data.permissionset-meta.xml`

Granted:

- Account read
- Contact read
- Case read/edit
- Apex class access for:
  - `XC_AFCC_AgentforceCaseLookupAction`
  - `XC_AFCC_AgentforceCaseLookupRequest`
  - `XC_AFCC_AgentforceCaseLookupResponse`
  - `XC_AFCC_AgentforceCaseLookupV2Action`
  - `XC_AFCC_AgentforceCaseStatusTextAction`

Assigned it to the Agentforce runtime user:

```bash
sf org assign permset --target-org agentcalc-af --name XC_AFCC_Agent_Service_Data --on-behalf-of afcc.service.agent.00dg500000afgyr@agentforce.local
```

Verified with `UserRecordAccess` that the runtime user can read the test Case, Account, and Contact.

### Custom AFCC Agentforce Case Lookup Action

Added a deterministic Apex invocable action:

- `force-app/core/default/classes/XC_AFCC_AgentforceCaseLookupAction.cls`
- `force-app/core/default/classes/XC_AFCC_AgentforceCaseLookupActionTest.cls`

The action accepts a case number and returns:

- found
- case number
- subject
- status
- priority
- account name
- contact name
- contact email
- next step
- summary

Validation deploy passed with:

```bash
sf project deploy start --target-org agentcalc-af \
  --source-dir force-app/core/default/classes/XC_AFCC_AgentforceCaseLookupAction.cls \
  --source-dir force-app/core/default/classes/XC_AFCC_AgentforceCaseLookupAction.cls-meta.xml \
  --source-dir force-app/core/default/classes/XC_AFCC_AgentforceCaseLookupActionTest.cls \
  --source-dir force-app/core/default/classes/XC_AFCC_AgentforceCaseLookupActionTest.cls-meta.xml \
  --source-dir force-app/core/default/permissionsets/XC_AFCC_Agent_Service_Data.permissionset-meta.xml \
  --test-level RunSpecifiedTests \
  --tests XC_AFCC_AgentforceCaseLookupActionTest \
  --wait 10
```

Result: deploy succeeded, tests passed.

### GenAiFunction Metadata

Changed `sfdx-project.json` source API version to `66.0` because GenAiFunction metadata deployment failed under API `60.0`.

Added GenAiFunction bundle:

- `force-app/core/default/genAiFunctions/XC_AFCC_Lookup_Case_By_Number/XC_AFCC_Lookup_Case_By_Number.genAiFunction-meta.xml`

Tooling API confirmed:

- GenAiFunctionDefinition Id: `172g5000006JPX7AAO`
- DeveloperName: `XC_AFCC_Lookup_Case_By_Number`
- MasterLabel: `Look Up Case by Number`
- InvocationTargetType: `apex`

Later debugging showed that source-created Agentforce actions can be internally missing the generated Lightning type schema that Builder expects. The repeated retrieve/deploy failure was:

```text
The Input LightningTypeBundle schema for action 'XC_AFCC_Lookup_Case_Status_Text_179g5000000jkoJ' could not be found.
```

Manually adding LightningTypeBundle metadata did not repair that internal action asset. The working fix was to create a fresh Builder-native Agent Action from the Apex invocable method:

- Label: `Look Up Case Status Live`
- Generated runtime action name: `Look_Up_Case_Status_Live_179g5000000jkoJ`
- Invocation target: `XC_AFCC_AgentforceCaseStatusTextAction`
- Input schema: `caseNumbers` as text
- Output schema: `output` as text
- Progress text: `Looking up the case.`

That created retrievable generated schemas under:

- `force-app/core/default/genAiPlannerBundles/XC_AFCC_Service_Intake_Agent/localActions/p_16jg5000000TBbB_Support_Status_And_Next_Steps_16jg5000000TBbB/Look_Up_Case_Status_Live_179g5000000jkoJ/input/schema.json`
- `force-app/core/default/genAiPlannerBundles/XC_AFCC_Service_Intake_Agent/localActions/p_16jg5000000TBbB_Support_Status_And_Next_Steps_16jg5000000TBbB/Look_Up_Case_Status_Live_179g5000000jkoJ/output/schema.json`

### Agent Topic Metadata

Retrieved agent metadata into:

- `.tmp-agent-full-retrieve/`

Important topic plugin ids:

- `179g5000000jMXSAA2`: Case Creation And Update
- `179g5000000jMXUAA2`: Support Status And Next Steps

Patched these retrieved plugin metadata files:

- `.tmp-agent-full-retrieve/genAiPlugins/p_16jg5000000TBbB_Case_Creation_And_Update.genAiPlugin-meta.xml`
- `.tmp-agent-full-retrieve/genAiPlugins/p_16jg5000000TBbB_Support_Status_And_Next_Steps.genAiPlugin-meta.xml`

Earlier intended topic composition:

- Support Status And Next Steps should expose only `XC_AFCC_Lookup_Case_By_Number`.
- Case Creation And Update should expose `XC_AFCC_Lookup_Case_By_Number`, `SvcCopilotTmpl__CreateCaseEnhancedData`, and `SvcCopilotTmpl__AddCaseComment`.
- Stock case lookup functions should not be available in the Support Status topic because they keep winning the planner decision and returning verified-customer failures.

Tooling API after deploy showed:

- Support Status topic has custom function id `172g5000006JPX7AAO`.
- Case Creation topic has custom function id plus create/comment functions.

Final working topic composition:

- Support Status And Next Steps exposes only the Builder-native local action `Look Up Case Status Live`.
- The subagent instructions explicitly require `Look Up Case Status Live` when a case number is present.
- The stale instruction references to `XC_AFCC_Lookup_Case_By_Number` and `XC_AFCC_Lookup_Case_Status_Text` were removed from the active planner bundle.

The source of truth for this deployed agent bundle is now:

- `force-app/core/default/genAiPlannerBundles/XC_AFCC_Service_Intake_Agent/XC_AFCC_Service_Intake_Agent.genAiPlannerBundle`
- `force-app/core/default/genAiPlannerBundles/XC_AFCC_Service_Intake_Agent/localActions/.../Look_Up_Case_Status_Live_179g5000000jkoJ/input/schema.json`
- `force-app/core/default/genAiPlannerBundles/XC_AFCC_Service_Intake_Agent/localActions/.../Look_Up_Case_Status_Live_179g5000000jkoJ/output/schema.json`

## Resolved State

Enhanced Web Chat case lookup now works end-to-end.

Final successful customer utterance:

```text
Look up case 00001322 and tell me the status and priority.
```

Visible Enhanced Web Chat answer included:

```text
The status of Case 00001322 is New, and the priority is High.
```

It also returned the expected Account, Contact, subject, and next step. Screenshot evidence:

- `screenshots/agentforce-enhanced-web-chat-case-lookup-success.png`

Final event log evidence:

- `Topic classification succeeded: p_16jg5000000TBbB_Support_Status_And_Next_Steps_16jg5000000TBbB`
- `actionName: Look_Up_Case_Status_Live_179g5000000jkoJ, isSuccessful: true`
- `InstructionAdherence: HIGH. Explanation: This response adheres to the assigned instructions.`
- `Copilot Message: INFORM, Is Output Safe? true`

Important operational lesson:

- Existing Enhanced Web Chat conversations can cache the prior runtime plan/instructions. After changing agent actions or topic instructions, end the current chat and start a fresh conversation before retesting.

## Resolved Failure Path

Enhanced Web Chat previously answered:

```text
I'm unable to look up the case details at the moment. Please contact support directly for assistance with case 00001322.
```

The key trace was:

- `InstructionAdherence: LOW. Explanation: The agent failed to use the required 'XC_AFCC_Lookup_Case_By_Number' action for case lookup, violating instructions.`

That showed the channel was reaching the right topic, but the topic instructions still referenced a stale action name. Updating the planner bundle instructions to require `Look Up Case Status Live`, deactivating the agent, deploying the planner bundle, reactivating the agent, ending the old chat, and starting a new chat fixed it.

## Useful Queries

Recent Agentforce event log:

```bash
sf data query --target-org agentcalc-af \
  --query "SELECT EventDateTime, EventLabel FROM ConversationDefinitionEventLog ORDER BY EventDateTime DESC LIMIT 20"
```

Fresh-session event log window:

```bash
sf data query --target-org agentcalc-af \
  --query "SELECT EventDateTime, EventLabel FROM ConversationDefinitionEventLog WHERE EventDateTime >= 2026-05-14T12:21:20Z ORDER BY EventDateTime ASC"
```

Plugin function composition:

```bash
sf data query --target-org agentcalc-af --use-tooling-api \
  --query "SELECT Id, PluginId, Function FROM GenAiPluginFunctionDef WHERE PluginId IN ('179g5000000jMXUAA2','179g5000000jMXSAA2') ORDER BY PluginId, Function"
```

Runtime user record access:

```bash
sf data query --target-org agentcalc-af \
  --query "SELECT RecordId, HasReadAccess, HasEditAccess FROM UserRecordAccess WHERE UserId = '005g5000006jXArAAM' AND RecordId IN ('500g500000Rg60aAAB')"
```

## Next Best Action

Build on the now-working Enhanced Web Chat path:

1. Scale the production-like Enhanced Web Chat runner to the desired sample size, such as 150 seeded cases.
2. Seed Accounts, Contacts, and Cases first, then drive real conversations so Salesforce creates native Messaging Session and conversation telemetry.
3. Sync native runtime records into AFCC staging and ledger rows.
4. Keep the Builder-native `Look Up Case Status Live` planner bundle metadata in source; do not revert to the broken source-created action asset.

## Enhanced Web Chat Runner

Added:

- `scripts/conversation/run-enhanced-web-chat-conversations.mjs`
- `package.json`
- `package-lock.json`

The runner:

- Uses Playwright to drive the real Enhanced Web Chat browser widget.
- Uses the local Salesforce CLI auth session to open the authenticated Visualforce test page through frontdoor without printing or storing the access token.
- Opens the collapsed `Ask Me Anything` launcher.
- Waits for the agent greeting before sending the customer message. Sending too early can result in the widget accepting text before the Agentforce session is fully engaged.
- Opens one fresh browser context per Case, which creates fresh customer conversations.
- Sends a realistic customer utterance with Contact name, Account name, email, Case number, and the requested status/priority/next-step task.
- Validates that the visible chat reply contains the expected Case number, Case status, and priority.
- Fails if the visible response contains phrases such as "unable to look up", "couldn't retrieve", "technical issue", or "contact support directly".
- Captures a screenshot per conversation.
- Confirms Agentforce runtime evidence by checking that `ConversationDefinitionEventLog` action successes for `Look_Up_Case_Status_Live` increase by the number of passed conversations.

Important implementation notes:

- The Visualforce Enhanced Web Chat test page requires an authenticated Salesforce session in a new browser context. A direct unauthenticated Playwright page shows a Salesforce login/access denied page.
- The chat launcher is collapsed on first load. The runner must click `Ask Me Anything` before waiting for the message textarea.
- The textarea can become visible before the Agentforce greeting is fully ready. The runner must wait for "How can I help you?" before sending.
- `ConversationDefinitionEventLog` rows can arrive/index after the visible chat response. Timestamp-window queries can miss delayed rows, so the runner uses a baseline/delta count of recent `Look_Up_Case_Status_Live` success events.
- Do not print `sf org open --url-only` frontdoor URLs in script output. They can contain one-time login material.

Validated runs:

- Single-case runner smoke test passed for Case `00001322`.
- Three-conversation runner smoke test passed for Cases `00001176`, `00001177`, and `00001178`.
- Five-conversation runner smoke test passed for Cases `00001176` through `00001180`; event summary showed five action successes, five safe outputs, five high instruction-adherence rows, and no failures.
- Step 3 integration passed with `--enhanced-web-chat-url`, `--skip-seed`, `--skip-sync`, and one conversation. Runtime object counts increased from the runner: `MessagingSession`, `AgentWork`, `Conversation`, and `ConversationDefinitionSession`.

## Product Direction Learned

The production-like path should not manufacture Agentforce runtime records directly.

The correct hierarchy is:

1. Seed real Salesforce business records: Accounts, Contacts, Cases.
2. Configure a real Agentforce Service Agent and real channel.
3. Drive conversations through Enhanced Web Chat, Agent API, or BYOC.
4. Let Salesforce create runtime session/conversation records.
5. Sync those native runtime records into AFCC staging and ledger rows.
6. Use synthetic data only for scratch-org math and UX validation where Agentforce is not available.

CSV import is a fallback/admin escape hatch, not the primary model for Agentforce-enabled sandboxes.

## Agent Cost Questions

Added a live Agentforce cost-analysis action:

- Apex action: `XC_AFCC_AgentforceCostQuestionAction`
- Agent action: `Answer Cost Question`
- Planner local action: `Answer_Cost_Question_Live_179g5000000cost`
- Topic: `Cost Analysis`

Supported questions are intentionally deterministic and ledger-backed:

- Total Agentforce cost.
- Cost for a specific Salesforce Case number.
- Cost by queue, agent, topic, channel, outcome, or date.
- Deferred case cost, defaulting to queue when no grouping is specified.
- Unallocated usage count, percentage, and cost.
- Estimated or incomplete cost rows, including missing-rate handling.

The action returns plain text so Agentforce can use a simple Builder-compatible schema. The agent topic instructions require the agent to call `Answer Cost Question` before answering any cost, spend, usage allocation, deferred cost, unallocated usage, estimated cost, missing rate, or case-cost question.

Validation performed on 2026-05-14:

- Focused Apex test passed: `XC_AFCC_AgentforceCostQuestionActionTest`.
- Direct Apex invocation returned ledger-backed answers for total cost, deferred cost by queue, case cost, unallocated usage, and estimated cost.
- Programmatic Agentforce preview answered:
  - `What is total Agentforce cost?`
  - `What did deferred cases cost by queue?`
  - `What did case 00001325 cost and why?`
- Enhanced Web Chat runner passed a custom cost prompt:
  - Prompt: `What is total Agentforce cost?`
  - Visible answer included total cost `$0.95`, 190 rows, 190 credits, and 0 conversations.
  - Event-log delta confirmed one successful `Answer_Cost_Question_Live` action.
  - Evidence: `output/conversations/ewc-20260514165438/summary.json`

Runner update:

- `scripts/conversation/run-enhanced-web-chat-conversations.mjs` now accepts `--message`, repeated `--expect-text`, and `--event-action-regex`.
- Use `--event-action-regex "actionName: Answer_Cost_Question_Live_.*isSuccessful: true"` for cost-question smoke tests.
