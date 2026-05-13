# Deployment Scripts Spec

## 1. Design Principle

The release must be script deployable.

A developer should not have to manually click through Salesforce setup to create the first synthetic test environment or bootstrap an Agentforce sandbox.

---

## 2. Required Scripts

### 2.1 `scripts/mvp/01-create-synthetic-test-org.sh`

Purpose: create a full synthetic scratch org for development/testing/demo.

Usage:

```bash
scripts/mvp/01-create-synthetic-test-org.sh   --scenario deferred-hotspot   --volume medium   --alias xc-afcc-synth-test   --duration-days 14
```

Options:

| Option | Required | Description |
|---|---:|---|
| `--scenario` | No | default `deferred-hotspot` |
| `--volume` | No | small, medium, large |
| `--alias` | No | scratch org alias |
| `--duration-days` | No | scratch org duration |
| `--fresh` | No | delete/recreate existing alias |
| `--reuse-org` | No | use existing scratch org |
| `--reset-data` | No | delete/reseed synthetic data |
| `--skip-open` | No | do not open browser |
| `--run-tests` | No | run Apex tests |

Required steps:

1. Validate local tools:
   - `sf`
   - `git`
   - `jq`
2. Validate Dev Hub authentication.
3. Check scratch org limits.
4. Create scratch org unless reuse requested.
5. Deploy Core source.
6. Deploy Demo Harness source.
7. Assign permission sets.
8. Seed synthetic data.
9. Run data health.
10. Run readiness validation.
11. Run Apex tests if requested/defaulted.
12. Open org unless skipped.
13. Print readiness scorecard.

---

### 2.2 `scripts/mvp/02-bootstrap-agentforce-sandbox.sh`

Purpose: deploy Core only to an existing sandbox and prepare for native Agentforce/Service Cloud analysis.

Usage:

```bash
scripts/mvp/02-bootstrap-agentforce-sandbox.sh   --target-org customer-agentforce-sandbox   --deploy-source
```

Options:

| Option | Required | Description |
|---|---:|---|
| `--target-org` | Yes | target sandbox alias |
| `--deploy-source` | No | deploy Core source |
| `--install-package` | No | install Core package version |
| `--csv` | No | fallback-only CSV import after deploy |
| `--validate-only` | No | validate only |
| `--skip-open` | No | do not open browser |

Required steps:

1. Validate target org is authenticated.
2. Validate target org is not production.
3. Deploy/install Core only.
4. Confirm Demo Harness is not deployed.
5. Assign `XC_AFCC_Admin`.
6. Create or validate org config.
7. Discover native Service Cloud/Agentforce source objects.
8. Sync/analyze native source rows unless validate-only.
9. Import CSV only if explicitly provided as fallback.
10. Run data health.
11. Run sandbox readiness validation.
12. Open org unless skipped.

---

### 2.3 `scripts/mvp/03-run-prod-like-agentforce-sandbox.sh`

Purpose: create production-like sandbox data by seeding real business records and driving real Agentforce runtime conversations.

Usage:

```bash
scripts/mvp/03-run-prod-like-agentforce-sandbox.sh \
  --target-org customer-agentforce-sandbox \
  --deploy-core \
  --case-count 150 \
  --conversation-runner scripts/conversation/customer-runner.sh
```

Options:

| Option | Required | Description |
|---|---:|---|
| `--target-org` | Yes | target sandbox alias |
| `--case-count` | No | number of Accounts, Contacts, and Cases to seed; default 150 |
| `--run-key` | No | explicit run key for traceability |
| `--deploy-core` | No | deploy Core before running |
| `--skip-seed` | No | skip business record seeding |
| `--conversation-runner` | No | executable runner that drives real Agentforce conversations |
| `--skip-sync` | No | skip native sync and data health |
| `--validate-only` | No | validate only |
| `--skip-open` | No | do not open browser |

Required behavior:

1. Validate target org is authenticated.
2. Refuse production.
3. Deploy Core only when requested.
4. Confirm Demo Harness is absent.
5. Assign `XC_AFCC_Admin`.
6. Seed real Accounts, Contacts, and Cases unless skipped.
7. Validate native runtime source availability.
8. Run the configured conversation runner if provided.
9. Sync native runtime-created rows.
10. Run data health.
11. Print a scorecard.

The conversation runner must not insert Agentforce runtime objects or XC ledger objects directly.

---

## 3. Validation Scripts

### `scripts/validate/no-demo-in-core.sh`

Fails if demo/synthetic terms appear in `force-app/core`.

Terms to block:

```text
Synthetic
DemoSeeder
DemoHarness
DemoScenario
DemoReset
Fake
SampleData
SyntheticDataFactory
DemoLauncher
```

Allow exceptions only in documentation, not metadata source.

### `scripts/validate/package-composition-check.sh`

Verifies:

- Core source contains no demo classes/LWCs/permissions.
- Demo Harness source depends on Core concepts.
- Demo Harness has a custom permission.
- Core can be deployed without Demo Harness.

---

## 4. Test Scripts

### `scripts/test/run-apex-tests.sh`

Runs all Apex tests.

```bash
sf apex run test   --target-org "$TARGET_ORG"   --test-level RunLocalTests   --wait 20   --result-format human
```

### `scripts/test/run-data-health-check.sh`

Runs Apex method or anonymous Apex to execute data health.

### `scripts/test/run-demo-readiness-check.sh`

Runs demo readiness validation.

### `scripts/test/collect-debug-artifacts.sh`

Collects:

- org display
- deploy reports
- Apex test output
- package install status
- readiness output
- scenario config
- latest debug logs if available

---

## 5. Apex Script Files

### `scripts/apex/seedSyntheticData.apex`

Should call:

```apex
XC_AFCC_DemoSeeder.seed('deferred-hotspot', 'medium');
```

Accepting script arguments directly in anonymous Apex is awkward, so the shell script can generate a temporary anonymous Apex file with the selected scenario/volume.

### `scripts/apex/validateSyntheticReadiness.apex`

Should call:

```apex
System.debug(JSON.serializePretty(XC_AFCC_DemoReadinessService.validateCurrentScenario()));
```

### `scripts/apex/validateSandboxReadiness.apex`

Should call:

```apex
System.debug(JSON.serializePretty(XC_AFCC_DataHealthService.validateSandboxReadiness()));
```

### `scripts/apex/seedProdLikeBusinessData.apex`

Used by Step 3 to create real sandbox business records. The shell script replaces placeholders before execution:

```apex
Integer caseCount = __CASE_COUNT__;
String runKey = '__RUN_KEY__';
```

### `scripts/apex/validateAgentforceRuntimeReadiness.apex`

Prints standard object counts, supported runtime source availability, `LIVE` staging rows, `LIVE` ledger rows, and Core native readiness.

### `scripts/apex/resetSyntheticData.apex`

Should call:

```apex
XC_AFCC_DemoResetService.resetSyntheticData();
```

---

## 6. Script Output Standard

Every major script should end with a clear scorecard.

Example:

```text
Agentforce Cost Calculator Step 1 Readiness

Org Alias: xc-afcc-synth-test
Scenario: deferred-hotspot
Core Deploy: PASS
Demo Harness Deploy: PASS
Permission Sets: PASS
Synthetic Seed: PASS
Data Health: PASS
Apex Tests: PASS
Dashboard Data: PASS
Grouped Report Data: PASS
Case Explorer Data: PASS

Result: PASS
```

If not ready:

```text
Result: FAIL
Blocking Issues:
- No deferred cases found
- Ledger rows did not reconcile with staging rows
- Case Explorer explanation query returned zero rows
```
