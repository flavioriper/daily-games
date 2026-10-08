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
# publishDay writes Golden Acorn's day with a model Vertex AI serves from
# this project (server/functions/src/generate.ts), signed in as the
# functions' own identity. That needs the Vertex AI API on and the identity
# allowed to use it, once: tools/vertex_identity.sh. Without it every night
# is the bank's day, not an error. The scheduler runs at 03:00 UTC, so the
# day of a deploy is published by tools/publish_day.sh
# (docs/agents/turns-and-backend.md, "A day written by a model").
set -euo pipefail
cd "$(dirname "$0")/../server"
(cd functions && npm ci && npm run build)
firebase deploy --only functions,firestore:rules --project daily-games-420bf
