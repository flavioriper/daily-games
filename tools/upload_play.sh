#!/usr/bin/env bash
# Put a release AAB on a Google Play track through the Play Android Developer
# API, as a draft release that nobody sees until a person rolls it out in the
# Play Console (Play still measures the bundle: DEX optimisation, size).
#
#   tools/upload_play.sh [build/android/peeplet-daily.aab]
#
#   PLAY_TRACK=internal     the track (internal, alpha, beta, production)
#   PLAY_STATUS=draft       draft | completed (completed rolls out to the
#                           track's testers at once; production needs review)
#   PLAY_SA_KEY=~/keys/play-publisher.json   the service account's key, from
#                           tools/play_api_setup.sh
#
# Needs only openssl, jq and curl: the service account's key signs a JWT
# that the token endpoint swaps for an access token (no google-auth on this
# Mac). The edit is one transaction: insert, upload the bundle, set the
# track, commit. Release notes are HEAD's subject.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

aab="${1:-build/android/peeplet-daily.aab}"
track="${PLAY_TRACK:-internal}"
status="${PLAY_STATUS:-draft}"
key="${PLAY_SA_KEY:-$HOME/keys/play-publisher.json}"
pkg="com.peeplet.daily"
api="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$pkg"
upload="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$pkg"

[[ -s "$aab" ]] || { echo "no aab at $aab (tools/release_android.sh builds it)"; exit 1; }
[[ -s "$key" ]] || { echo "no service account key at $key (bash tools/play_api_setup.sh)"; exit 1; }
case "$status" in draft|completed) ;; *) echo "PLAY_STATUS must be draft or completed"; exit 1;; esac

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# --- a token for the service account -----------------------------------
email="$(jq -r .client_email "$key")"
pem="$(mktemp)"; trap 'rm -f "$pem"' EXIT
jq -r .private_key "$key" > "$pem"
now="$(date +%s)"
header="$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)"
claims="$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/androidpublisher","aud":"https://oauth2.googleapis.com/token","iat":%s,"exp":%s}' "$email" "$now" "$((now + 3600))" | b64url)"
sig="$(printf '%s.%s' "$header" "$claims" | openssl dgst -sha256 -sign "$pem" -binary | b64url)"
token="$(curl -sS -X POST https://oauth2.googleapis.com/token \
  -d grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
  -d "assertion=$header.$claims.$sig" | jq -r '.access_token // empty')"
[[ -n "$token" ]] || { echo "no access token for $email"; exit 1; }
auth=(-H "Authorization: Bearer $token")

fail() { echo "$1:"; echo "$2" | jq . 2>/dev/null || echo "$2"; exit 1; }

# --- the edit ------------------------------------------------------------
res="$(curl -sS -X POST "${auth[@]}" -H "Content-Type: application/json" -d '{}' "$api/edits")"
edit="$(echo "$res" | jq -r '.id // empty')"
[[ -n "$edit" ]] || fail "could not open an edit" "$res"

echo "uploading $aab ($(du -h "$aab" | cut -f1)) ..."
res="$(curl -sS -X POST "${auth[@]}" -H "Content-Type: application/octet-stream" \
  --data-binary "@$aab" "$upload/edits/$edit/bundles?uploadType=media")"
code="$(echo "$res" | jq -r '.versionCode // empty')"
[[ -n "$code" ]] || fail "upload refused" "$res"
echo "uploaded versionCode $code"

notes="$(git log -1 --pretty='%h %s' | cut -c1-500 | jq -Rs .)"
body="$(jq -n --arg track "$track" --arg code "$code" --arg status "$status" --argjson notes "$notes" \
  '{track: $track, releases: [{versionCodes: [$code], status: $status, releaseNotes: [{language: "en-US", text: $notes}]}]}')"
res="$(curl -sS -X PUT "${auth[@]}" -H "Content-Type: application/json" -d "$body" "$api/edits/$edit/tracks/$track")"
echo "$res" | jq -e '.track' >/dev/null 2>&1 || fail "could not set the $track track" "$res"

# A plain commit; when Play answers that the change would need a review it
# is not being sent for, commit it as "not sent for review" instead (a draft
# never needs one, a completed production release does).
res="$(curl -sS -X POST "${auth[@]}" "$api/edits/$edit:commit")"
if ! echo "$res" | jq -e '.id' >/dev/null 2>&1; then
  if echo "$res" | grep -qi "review"; then
    res="$(curl -sS -X POST "${auth[@]}" "$api/edits/$edit:commit?changesNotSentForReview=true")"
  fi
  echo "$res" | jq -e '.id' >/dev/null 2>&1 || fail "commit refused" "$res"
fi
echo "versionCode $code is a $status release on the $track track"
