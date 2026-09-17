#!/usr/bin/env bash
# Deploys the turn backend: the three functions and the Firestore rules.
# Nothing here is wired into CI yet -- that needs a deploy service account
# secret, and is a follow-up rather than part of phase 0.
#
# The live project is daily-games-420bf. Firestore, its rules and anonymous
# sign-in were provisioned by hand on 2026-09-17; the functions need the
# project on the Blaze plan before this will go through.
set -euo pipefail
cd "$(dirname "$0")/../server"
(cd functions && npm ci && npm run build)
firebase deploy --only functions,firestore:rules --project daily-games-420bf
