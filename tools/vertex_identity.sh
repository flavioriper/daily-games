#!/usr/bin/env bash
# One-time setup: let the deployed functions draw the daily theme's pictures
# on Vertex AI (server/functions/src/generate.ts drawOnVertex, run by the
# drawPictures job in index.ts).
#
# The functions run as daily-games-420bf's Compute Engine default service
# account (tools/functions_identity.sh); the drawings are asked of, and
# billed to, the Vertex project VERTEX_PROJECT names on the function
# (production-506015, the one tools/themed_days.sh draws in on this Mac).
# That project's owner grants the account Vertex AI User there.
#
# Needs gcloud logged in as an owner of that project. Run it by hand; an
# agent session is not allowed to grant IAM roles. Safe to re-run.
set -euo pipefail
VP="${VERTEX_PROJECT:-production-506015}"
SA="260608109943-compute@developer.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$VP" --member "serviceAccount:$SA" \
  --role roles/aiplatform.user --condition=None ${VERTEX_ACCOUNT:+--account "$VERTEX_ACCOUNT"} >/dev/null
echo "granted roles/aiplatform.user on $VP to $SA"
