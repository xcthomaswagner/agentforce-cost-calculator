# Release Readiness Scorecard

| Area | Status | Notes |
|---|---|---|
| Salesforce-only architecture | PASS | No external service, database, middleware, or LLM dependency added. |
| Core / Demo Harness separation | PASS | Core and Demo Harness live in separate package directories. |
| Core data model | PASS | Required objects and fields are scaffolded from the metadata spec. |
| Native Agentforce source path | PASS PENDING ORG RUN | Core discovers native Service Cloud/Agentforce objects and materializes live usage into ledger rows where available. |
| CSV fallback | PASS | Core importer is retained as an explicit fallback/admin utility and is disabled by default. |
| Synthetic generator | PASS | Demo Harness creates Accounts, Contacts, Cases, links, staging rows, and ledger rows. |
| Guardrails | PASS | Demo Harness checks non-production, custom permission, and expiring override outside scratch orgs. |
| Step 1 script | PASS | Creates scratch org, deploys Core and Demo Harness, seeds, validates, tests, and opens app. |
| Step 2 script | PASS | Deploys Core only, blocks production, checks Demo Harness absence, validates readiness. |
| Step 3 prod-like sandbox harness | PARTIAL | Script, business seed, readiness check, and runner contract are present. Needs an Agentforce-enabled sandbox and channel-specific runner execution. |
| Apex tests | PASS PENDING ORG RUN | Tests are present; full pass requires an authenticated Salesforce org. |
| Browser smoke test | PASS PENDING ORG RUN | Checklist is documented; execution requires a deployed org. |

## Known Release Limitations

- Native Agentforce object availability varies by org configuration; Core discovers supported objects dynamically and reports gaps instead of hard failing.
- The CSV importer is intentionally synchronous and fallback-only; it is not the primary native sandbox path.
- Dashboard visuals use Lightning data tables and summary cards; richer charts can be added after acceptance.
- Package scripts assume package records already exist in the Dev Hub.
- Step 3 requires a configured Agentforce/Messaging runtime channel; the repo provides the harness and runner contract, not customer-specific Agentforce setup.
- Production deployment, upgrade flows, and managed-package hardening are out of scope for this release.
