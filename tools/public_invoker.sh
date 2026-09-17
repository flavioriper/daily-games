#!/usr/bin/env bash
# One-time setup: let anyone on the internet call submitTurn.
#
# submitTurn is a public endpoint by design: the game's players are anonymous
# Firebase users, not Google identities, so Cloud Run cannot authenticate
# them, and the function verifies the Firebase ID token itself. Being public
# means the Cloud Run service grants roles/run.invoker to `allUsers`. The
# organisation daily-games-420bf sits in enforces domain-restricted sharing
# (constraints/iam.allowedPolicyMemberDomains), which rejects `allUsers`, so
# `firebase deploy` created the service with no invoker at all and every call
# answered 403 before the function ran.
#
# This overrides that constraint on this one project only, keeping the
# organisation's own members allowed and adding the "public" principal set,
# then grants the invoker the deploy could not. Safe to re-run.
#
# Needs gcloud logged in as an owner of the project who is also an
# organisation policy administrator. Run it by hand; an agent session is not
# allowed to change policies or grant roles, which is the right default.
set -euo pipefail
P=daily-games-420bf

tmp="$(mktemp)"
cat > "$tmp" <<EOF
name: projects/$P/policies/iam.allowedPolicyMemberDomains
spec:
  inheritFromParent: true
  rules:
  - values:
      allowedValues:
      - principalSet://goog/public:all
EOF
gcloud org-policies set-policy "$tmp" --project "$P" >/dev/null
rm -f "$tmp"

gcloud run services add-iam-policy-binding submitturn --region us-central1 --project "$P" \
  --member allUsers --role roles/run.invoker >/dev/null

echo "submitTurn is public; a POST without a token should now answer 401 from the function:"
curl -s -w "\n%{http_code}\n" -X POST -H "Content-Type: application/json" -d '{}' \
  "https://us-central1-$P.cloudfunctions.net/submitTurn"
