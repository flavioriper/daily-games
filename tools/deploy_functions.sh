#!/usr/bin/env bash
# Deploys the turn backend: the three functions and the Firestore rules.
# Nothing here is wired into CI yet -- that needs a deploy service account
# secret, and is a follow-up rather than part of phase 0.
#
# The live project is daily-games-420bf, provisioned by hand on 2026-09-17.
# A fresh project needs tools/functions_identity.sh before this can build,
# and tools/public_invoker.sh after the first deploy so submitTurn can be
# called at all; see CLAUDE.md, "Turns and the backend".
#
# publishDay writes Golden Acorn's day and Pearl Dive's with a model asked
# through OpenRouter (server/functions/src/generate.ts; acorn.ts, pearl.ts)
# and reads its key from the secret OPENROUTER_API_KEY. The deploy fails until that secret exists; set it once:
#   cd server && firebase functions:secrets:set OPENROUTER_API_KEY --project daily-games-420bf
# The scheduler runs at 03:00 UTC, so the day of a deploy is published by
# tools/publish_day.sh (docs/agents/turns-and-backend.md, "A day written by
# a model").
set -euo pipefail
cd "$(dirname "$0")/../server"
(cd functions && npm ci && npm run build)
firebase deploy --only functions,firestore:rules --project daily-games-420bf
