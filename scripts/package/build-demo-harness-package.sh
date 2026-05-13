#!/usr/bin/env bash
set -euo pipefail
sf package version create --package "XC Agentforce Cost Calculator Demo Harness" --installation-key-bypass --wait 30 --code-coverage
