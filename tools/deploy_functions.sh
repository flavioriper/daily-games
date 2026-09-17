#!/usr/bin/env bash
# Deploys the turn backend: the three functions and the Firestore rules.
# Nothing here is wired into CI yet -- that needs a deploy service account
# secret, and is a follow-up rather than part of phase 0.
#
# Not run as part of this task: peeplet-daily has no Cloud Firestore enabled,
# no Firebase Web app (so core/backend.gd's API_KEY is still the placeholder
# PASTE_WEB_API_KEY_HERE) and this machine's gcloud credentials are expired.
# Provisioning the project is the repo owner's call, raised separately.
set -euo pipefail
cd "$(dirname "$0")/../server"
(cd functions && npm ci && npm run build)
firebase deploy --only functions,firestore:rules --project peeplet-daily
