#!/usr/bin/env bash
# Prints the day Golden Acorn would publish and writes nothing: the model's
# when OPENROUTER_API_KEY is in the environment (eight requests through
# OpenRouter, three or four minutes, a few cents), the bank's when it is not.
# The way to read what the model writes before it is trusted with a night.
#
#   tools/acorn_day.sh [yyyymmdd]
#   DAILY_MODEL=google/gemini-3.5-flash-lite tools/acorn_day.sh   # another writer
#   DAILY_MODEL=off tools/acorn_day.sh                            # the bank's day
set -euo pipefail
cd "$(dirname "$0")/../server/functions"
npm run build >/dev/null
node lib/cli.js day "$@"
