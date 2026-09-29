#!/usr/bin/env bash
# Writes the ads configuration document into the live Firestore, the way the
# backend reads it: config/ads with a single `json` field. This is a production
# write, so a person runs it (or allows it), the same as a deploy.
#
#   tools/set_ads_config.sh '{"grace_days":3,"hearts_first":true}'
#
# Upsert: writes or overwrites the entire document. Needs gcloud signed in to
# an account with Firestore write on daily-games-420bf.
set -euo pipefail
json="${1:?the config as one JSON string}"
project="${FIREBASE_PROJECT:-daily-games-420bf}"
base="https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents"
token="$(gcloud auth print-access-token)"
body="$(python3 -c 'import json,sys; print(json.dumps({"fields":{"json":{"stringValue":sys.argv[1]}}}))' "$json")"
curl -s -X PATCH "$base/config/ads?updateMask.fieldPaths=json" \
  -H "Authorization: Bearer $token" -H "x-goog-user-project: $project" \
  -H "Content-Type: application/json" -d "$body" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); f=d.get("fields",{}).get("json",{}).get("stringValue"); print(("wrote " + f) if f else ("refused: " + d.get("error",{}).get("message","?")))'
