#!/usr/bin/env bash
# One-time setup: give the Cloud Functions build and runtime identity the
# roles the organisation policy withholds from it.
#
# Cloud Functions v2 builds and runs as the project's Compute Engine default
# service account. The organisation daily-games-420bf sits in enforces
# constraints/iam.automaticIamGrantsForDefaultServiceAccounts, so that
# account is created with no roles at all: the first deploy failed inside
# Cloud Build fetching its own source ("missing permission on the build
# service account"), and a function that did deploy would fail on its first
# Firestore write. Safe to re-run; grants are idempotent.
#
# Needs gcloud logged in as an owner of the project. Run it by hand; an agent
# session is not allowed to grant IAM roles, which is the right default.
set -euo pipefail
P=daily-games-420bf
N=260608109943
SA="$N-compute@developer.gserviceaccount.com"

# Build: fetch the source bucket, push the image, write build logs.
gcloud projects add-iam-policy-binding "$P" --member "serviceAccount:$SA" \
  --role roles/cloudbuild.builds.builder --condition=None >/dev/null
# Run: read and write Firestore documents (submits, shards, tally, content).
gcloud projects add-iam-policy-binding "$P" --member "serviceAccount:$SA" \
  --role roles/datastore.user --condition=None >/dev/null

echo "$SA may now build and run the functions"
echo "next: tools/deploy_functions.sh"
