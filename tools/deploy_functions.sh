#!/usr/bin/env bash
# Deploys the turn backend: the three functions and the Firestore rules.
# Nothing here is wired into CI yet -- that needs a deploy service account
# secret, and is a follow-up rather than part of phase 0.
#
# The live project is daily-games-420bf, provisioned by hand on 2026-09-17.
# A fresh project needs tools/functions_identity.sh before this can build,
# and tools/public_invoker.sh after the first deploy so submitTurn can be
# called at all; see CLAUDE.md, "Turns and the backend".
set -euo pipefail
cd "$(dirname "$0")/../server"
(cd functions && npm ci && npm run build)
firebase deploy --only functions,firestore:rules --project daily-games-420bf
