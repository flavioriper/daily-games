#!/usr/bin/env bash
# One-time setup: let the functions ask a model on Vertex AI.
#
# publishDay writes Golden Acorn's day with a model Vertex AI serves from
# this project (server/functions/src/generate.ts). Two things have to be
# true first: the Vertex AI API is on, and the functions' identity -- the
# Compute Engine default service account, which this organisation creates
# with no roles (tools/functions_identity.sh) -- may call it. Safe to re-run.
#
# The open models (OpenAI's gpt-oss among them) may also want their terms
# accepted once in the console before the first request answers: open
# Vertex AI > Model Garden, find the model, and press Enable if it offers to.
#
# Needs gcloud logged in as an owner of the project. Run it by hand; an agent
# session is not allowed to grant IAM roles, which is the right default.
set -euo pipefail
P=daily-games-420bf
N=260608109943
SA="$N-compute@developer.gserviceaccount.com"

gcloud services enable aiplatform.googleapis.com --project "$P"
# Run: send requests to models Vertex AI serves.
gcloud projects add-iam-policy-binding "$P" --member "serviceAccount:$SA" \
  --role roles/aiplatform.user --condition=None >/dev/null

echo "$SA may now ask Vertex AI's models"
echo "next: tools/acorn_day.sh to read a day, then tools/deploy_functions.sh"
