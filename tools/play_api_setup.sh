#!/usr/bin/env bash
# One-time: a service account that tools/upload_play.sh uses to put an AAB on
# a Play track through the Google Play Android Developer API.
#
#   bash /Users/flavioriper/dev/daily/tools/play_api_setup.sh
#
# Run by a person (the auto-mode classifier refuses identity and IAM steps),
# with a gcloud login that owns the Firebase project daily-games-420bf
# (flavio@hypertradeworx.xyz; `gcloud auth login` in a real Terminal if its
# token has expired). What it does, each step skipped when already done:
#
#   1. enables androidpublisher.googleapis.com on the project;
#   2. creates the service account play-publisher;
#   3. enables the IAM Credentials API and makes the login Token Creator on
#      the account, so tools/upload_play.sh can impersonate it (the org
#      policy forbids service account keys).
#
# The service account gets no project role: its power comes from the Play
# Console, where it has to be invited as a user (Users and permissions >
# Invite new users, its email below) with "Release apps to testing tracks"
# on Peeplet: Daily Puzzles. Google says a new invite can take a while to be
# honoured by the API.
set -euo pipefail

project="${PLAY_GCP_PROJECT:-daily-games-420bf}"
account="${PLAY_GCP_ACCOUNT:-flavio@hypertradeworx.xyz}"
sa_name="play-publisher"
sa_email="$sa_name@$project.iam.gserviceaccount.com"

g() { gcloud --account "$account" --project "$project" "$@"; }

g auth print-access-token >/dev/null 2>&1 || {
  echo "gcloud's token for $account has expired; in a Terminal window run:"
  echo "  gcloud auth login $account"
  exit 1
}

if g services list --enabled --format="value(config.name)" | grep -q '^androidpublisher.googleapis.com$'; then
  echo "play_api_setup: Play Android Developer API already enabled"
else
  g services enable androidpublisher.googleapis.com
  echo "play_api_setup: enabled androidpublisher.googleapis.com"
fi

if g iam service-accounts describe "$sa_email" >/dev/null 2>&1; then
  echo "play_api_setup: $sa_email already exists"
else
  g iam service-accounts create "$sa_name" --display-name "Play uploads from tools/upload_play.sh"
  echo "play_api_setup: created $sa_email"
fi

# 3. Keyless: the organisation policy iam.disableServiceAccountKeyCreation
# forbids keys (seen 2026-10-28), so tools/upload_play.sh impersonates the
# account instead -- the IAM Credentials API mints it a short-lived token on
# the strength of $account's own gcloud login, which needs Token Creator on
# the account. (If PLAY_SA_KEY exists, the upload script uses that instead.)
if g services list --enabled --format="value(config.name)" | grep -q '^iamcredentials.googleapis.com$'; then
  echo "play_api_setup: IAM Credentials API already enabled"
else
  g services enable iamcredentials.googleapis.com
  echo "play_api_setup: enabled iamcredentials.googleapis.com"
fi
if g iam service-accounts get-iam-policy "$sa_email" --format=json | jq -e --arg m "user:$account" '.bindings[]? | select(.role=="roles/iam.serviceAccountTokenCreator") | .members[] | select(.==$m)' >/dev/null; then
  echo "play_api_setup: $account already Token Creator on $sa_email"
else
  g iam service-accounts add-iam-policy-binding "$sa_email" --member "user:$account" --role roles/iam.serviceAccountTokenCreator >/dev/null
  echo "play_api_setup: $account made Token Creator on $sa_email"
fi

echo
echo "Now invite $sa_email in the Play Console:"
echo "  Users and permissions > Invite new users > that email"
echo "  App permissions > Peeplet: Daily Puzzles > Release apps to testing tracks"
echo "Then: tools/upload_play.sh build/android/peeplet-daily.aab"
