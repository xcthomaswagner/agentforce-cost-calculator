# XC Agentforce Cost Calculator — Docs Index

Repository: `git@github.com:xcthomaswagner/agentforce-cost-calculator.git`  
Local folder: `/Users/thomaswagner/Desktop/Projects.nosync/agentforce cost calculator`

This docs set defines the MVP for the Salesforce-native **XC Agentforce Cost Calculator**.

## MVP Definition

The MVP has two sequential steps:

1. **Synthetic Test Environment**
   - A developer runs one script on a Mac.
   - The script creates a Salesforce scratch org.
   - The script deploys the Salesforce source.
   - The script installs/enables the demo harness.
   - The script seeds deterministic synthetic Salesforce data and ledger data.
   - The app is ready for test/demo when the script completes.

2. **Agentforce Sandbox Without Synthetic Data**
   - A developer runs one script against an existing Agentforce-enabled sandbox.
   - The script deploys the Core package/source only.
   - No synthetic data or demo harness is installed.
   - The app runs against native Service Cloud and Agentforce data.
   - Native source discovery, native sync, and data health prove the app works without synthetic data.

Production deployment is explicitly **not included** in the MVP.

## Documents

| Document | Purpose |
|---|---|
| `CODEX_GOAL_PROMPT.md` | Copy/paste prompt for Codex Goal |
| `MVP_EXECUTION_SPEC.md` | Full functional and technical MVP spec |
| `MVP_EXECUTION_SPEC_V2.md` | Corrected native Agentforce/Service Cloud MVP spec |
| `NATIVE_AGENTFORCE_SOURCE_SPEC.md` | Native object discovery and sync model |
| `SALESFORCE_METADATA_SPEC.md` | Salesforce objects, fields, classes, LWCs, permissions |
| `DEPLOYMENT_SCRIPTS_SPEC.md` | Required Mac/CLI scripts and expected behavior |
| `SYNTHETIC_DATA_AND_TESTING_SPEC.md` | Synthetic scenario model, test data contracts, readiness checks |
| `MAC_COMPUTER_USE_TEST_PLAYBOOK.md` | Manual/computer-use UI testing flow on Mac |
| `ACCEPTANCE_CRITERIA.md` | Definition of done for Step 1 and Step 2 |
| `IMPLEMENTATION_BACKLOG.md` | Ordered backlog for Codex implementation |

## Highest Priority Build Order

1. Build Salesforce DX project structure.
2. Build Core metadata.
3. Build Demo Harness metadata.
4. Build Step 1 synthetic scratch-org script.
5. Build deterministic synthetic data factory.
6. Build readiness validation.
7. Build dashboard/report/case-explorer functionality.
8. Build native Service Cloud/Agentforce source discovery and Step 2 sandbox bootstrap.
9. Run Mac/browser smoke testing.
