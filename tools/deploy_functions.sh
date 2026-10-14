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
# publishDay writes Golden Acorn's day and Pearl Dive's with Anthropic's
# models, asked of Anthropic's own API (server/functions/src/generate.ts;
# acorn.ts, pearl.ts), and keeps OpenRouter for any other model: it reads the
# secrets ANTHROPIC_API_KEY and OPENROUTER_API_KEY. The deploy fails until
# both exist; set each once:
#   cd server && firebase functions:secrets:set ANTHROPIC_API_KEY --project daily-games-420bf
#   cd server && firebase functions:secrets:set OPENROUTER_API_KEY --project daily-games-420bf
# themeDay (every half hour) makes the daily theme a step at a time and
# draws its pictures on Vertex AI in the project functions/.env names; the
# functions' account needs Vertex AI User there first: tools/vertex_identity.sh.
# The scheduler runs at 03:00 UTC, so the day of a deploy is published by
# tools/publish_day.sh (docs/agents/turns-and-backend.md, "A day written by
# a model").
set -euo pipefail
cd "$(dirname "$0")/../server"
(cd functions && npm ci && npm run build)
firebase deploy --only functions,firestore:rules --project daily-games-420bf
