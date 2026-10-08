#!/usr/bin/env bash
# Prints the day Golden Acorn would publish and writes nothing: the model's
# day when ANTHROPIC_API_KEY is set in the environment (two requests to the
# Claude API, a few minutes, well under a dollar), the bank's when it is not.
# The way to read what the model writes before it is trusted with a night.
#
#   ANTHROPIC_API_KEY=sk-ant-... tools/acorn_day.sh [yyyymmdd]
set -euo pipefail
cd "$(dirname "$0")/../server/functions"
npm run build >/dev/null
node lib/cli.js day "$@"
