# Mac Computer-Use Test Playbook

## 1. Purpose

This playbook defines how to test the MVP on a Mac using scripts, Salesforce CLI, browser inspection, and repeatable UI smoke tests.

The objective is to flush out defects in deployment, setup, data generation, UI behavior, and reporting.

---

## 2. Local Repo

Repository:

```text
git@github.com:xcthomaswagner/agentforce-cost-calculator.git
```

Local folder:

```text
/Users/thomaswagner/Desktop/Projects.nosync/agentforce cost calculator
```

---

## 3. Prerequisite Checks

Run:

```bash
sf --version
git --version
node --version
jq --version
```

Check Salesforce auth:

```bash
sf org list
sf org list limits --target-org DevHub
```

If DevHub is not authenticated:

```bash
sf org login web --alias DevHub --set-default-dev-hub
```

---

## 4. Step 1 Mac Test

From the repo root:

```bash
cd "/Users/thomaswagner/Desktop/Projects.nosync/agentforce cost calculator"

scripts/mvp/01-create-synthetic-test-org.sh \
  --scenario deferred-hotspot \
  --volume medium \
  --alias xc-afcc-synth-test \
  --duration-days 14 \
  --run-tests
```

Expected:
- scratch org is created
- app opens
- dashboard contains data
- grouped report works
- case explorer works
- readiness scorecard passes

---

## 5. Browser Smoke Test

After the org opens:

1. Open App Launcher.
2. Search for `XC Agentforce Cost Center`.
3. Open the app.
4. Open Setup.
5. Confirm mode is `DEMO` or `TEST`.
6. Open Data Health.
7. Confirm checks exist and at least one warning exists for demo scenario if expected.
8. Open Dashboard.
9. Confirm Total Cost is greater than zero.
10. Confirm Deferred Case Cost is greater than zero.
11. Open Grouped Report.
12. Filter outcome to `DEFERRED`.
13. Group by `Queue`.
14. Run report.
15. Confirm `Billing Support` appears for deferred-hotspot scenario.
16. Confirm cost totals populate.
17. Open Case Explorer.
18. Use the suggested case number from readiness output.
19. Confirm case explanation line items appear.
20. Click the related Salesforce Case link.
21. Confirm standard Case record opens.
22. Return to the app.
23. Export/copy report data if export feature exists.

---

## 6. Step 2 Sandbox Test

After Step 1 passes:

```bash
cd "/Users/thomaswagner/Desktop/Projects.nosync/agentforce cost calculator"

scripts/mvp/02-bootstrap-agentforce-sandbox.sh \
  --target-org customer-agentforce-sandbox \
  --deploy-source
```

Expected:
- Core deploys.
- Demo Harness is absent.
- Synthetic data is absent.
- Native Service Cloud and Agentforce source discovery runs.
- Data health runs.
- App opens.
- If native source objects exist but no usage data exists, script reports `READY_FOR_NATIVE_DATA`.

---

## 7. Defect Template

Use this for every defect:

```markdown
# Defect

## Environment
Org Alias:
Org Type:
Scenario:
Package/Commit:
Browser:
Mac OS:

## Steps to Reproduce

## Expected Result

## Actual Result

## Screenshot / Console Error

## Salesforce Debug Log Reference

## Severity
Blocker / High / Medium / Low
```

---

## 8. Debug Artifact Collection

Run:

```bash
scripts/test/collect-debug-artifacts.sh --target-org xc-afcc-synth-test
```

The script should collect:
- org display
- deploy output
- Apex test output
- readiness output
- scenario config
- recent logs
- package/source composition checks

---

## 9. Pass/Fail Standard

Step 1 passes only when:
- script returns success
- readiness scorecard passes
- Apex tests pass
- browser smoke test passes
- no demo code appears in Core
- known-answer math test passes

Step 2 passes only when:
- Core deploys to sandbox
- Demo Harness is absent
- synthetic records are absent
- native source discovery and data health work
- app is ready for native usage analysis, or reports that native usage data is not available yet
