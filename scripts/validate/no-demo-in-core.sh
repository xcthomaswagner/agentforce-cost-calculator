#!/usr/bin/env bash
set -euo pipefail
blocked='Synthetic|DemoSeeder|DemoHarness|DemoScenario|DemoReset|Fake|SampleData|SyntheticDataFactory|DemoLauncher'
matches="$(rg -n "$blocked" force-app/core || true)"
if [[ -n "$matches" ]]; then
  echo "Demo or generated-data terms found in Core source:" >&2
  echo "$matches" >&2
  exit 1
fi
echo "PASS: no Demo Harness terms found in Core source."
