#!/usr/bin/env bash
# Prints the day Pearl Dive would publish and writes nothing: the model's
# when OPENROUTER_API_KEY is in the environment (some fifty requests through
# OpenRouter, a prompt written and a prompt reviewed, five at a time; a few
# minutes and a few cents), the bank's when it is not. The way to read what
# the model writes before it is trusted with a night.
#
#   tools/pearl_day.sh [yyyymmdd]
#   DAILY_MODEL=google/gemini-3.5-flash-lite tools/pearl_day.sh   # another writer
#   DAILY_MODEL=off tools/pearl_day.sh                            # the bank's day
set -euo pipefail
cd "$(dirname "$0")/../server/functions"
npm run build >/dev/null
node lib/cli.js day pearl "$@"
