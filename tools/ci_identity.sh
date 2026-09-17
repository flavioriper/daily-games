#!/usr/bin/env bash
# One-time setup: let this repo's GitHub Actions act as the App Distribution
# service account in the Firebase project, with no stored key.
#
# The organisation daily-games-420bf sits in forbids service-account keys
# (constraints/iam.disableServiceAccountKeyCreation), so CI signs in through
# Workload Identity Federation instead: the run's own OIDC token is exchanged
# for the service account, and only runs from flavioriper/daily-games may do
# so. .github/workflows/android.yml's "Sign in to Google" step names the
# provider this creates. Safe to re-run: what exists is left alone.
#
# Needs gcloud logged in as an owner of the project. Run it by hand; an agent
# session is not allowed to grant IAM roles, which is the right default.
set -euo pipefail
P=daily-games-420bf
N=260608109943
REPO=flavioriper/daily-games
SA_NAME=app-distribution
SA="$SA_NAME@$P.iam.gserviceaccount.com"

gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  firebaseappdistribution.googleapis.com --project "$P"

if ! gcloud iam service-accounts describe "$SA" --project "$P" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SA_NAME" --display-name "CI App Distribution" --project "$P"
fi
gcloud projects add-iam-policy-binding "$P" --member "serviceAccount:$SA" \
  --role roles/firebaseappdistro.admin --condition=None >/dev/null

if ! gcloud iam workload-identity-pools describe github --location=global --project "$P" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create github --location=global \
    --display-name="GitHub Actions" --project "$P"
fi
if ! gcloud iam workload-identity-pools providers describe github-oidc --location=global \
    --workload-identity-pool=github --project "$P" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc github-oidc \
    --location=global --workload-identity-pool=github \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository == '$REPO'" \
    --project "$P"
fi
gcloud iam service-accounts add-iam-policy-binding "$SA" \
  --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/projects/$N/locations/global/workloadIdentityPools/github/attribute.repository/$REPO" \
  --project "$P" >/dev/null

echo "provider: projects/$N/locations/global/workloadIdentityPools/github/providers/github-oidc"
echo "runs from $REPO may now act as $SA"
