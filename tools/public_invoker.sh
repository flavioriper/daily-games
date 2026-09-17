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
# The legacy constraint has no way to admit `allUsers` and nobody else: Google
# documents that a public exception needs a custom organisation policy, an
# organisation-wide migration this game does not justify. So this lifts the
# domain restriction on this one project (the organisation keeps it), then
# grants the invoker the deploy could not. What that means for the project:
# any principal may be added to its IAM by an owner, including accounts from
# other domains. The project holds a public game and nothing else, and only
# its owners can add members, so that is acceptable here. Safe to re-run.
#
# Needs gcloud logged in as an owner of the project who is also an
# organisation policy administrator. Run it by hand; an agent session is not
# allowed to change policies or grant roles, which is the right default.
set -euo pipefail
P=daily-games-420bf

# Off by default on a fresh project, and gcloud would stop to ask.
gcloud services enable orgpolicy.googleapis.com --project "$P"

tmp="$(mktemp)"
cat > "$tmp" <<EOF
name: projects/$P/policies/iam.allowedPolicyMemberDomains
spec:
  rules:
  - allowAll: true
EOF
gcloud org-policies set-policy "$tmp" --project "$P" >/dev/null
rm -f "$tmp"

# IAM caches the domain restriction for some minutes after the policy changes,
# so the grant can still be refused right after the override lands. Cloud
# Run's own answer for restricted organisations is to skip the invoker IAM
# check on the service altogether: no `allUsers` member exists, the service
# simply accepts unauthenticated calls, and the function's token check is the
# gate, as designed. Either path leaves submitTurn callable by the game.
if gcloud run services add-iam-policy-binding submitturn --region us-central1 --project "$P" \
    --member allUsers --role roles/run.invoker >/dev/null 2>&1; then
  echo "granted roles/run.invoker to allUsers"
else
  echo "allUsers grant refused (restriction still cached); disabling the invoker IAM check instead"
  gcloud run services update submitturn --region us-central1 --project "$P" --no-invoker-iam-check >/dev/null
fi

echo "submitTurn is public; a POST without a token should now answer 401 from the function:"
curl -s -w "\n%{http_code}\n" -X POST -H "Content-Type: application/json" -d '{}' \
  "https://us-central1-$P.cloudfunctions.net/submitTurn"
