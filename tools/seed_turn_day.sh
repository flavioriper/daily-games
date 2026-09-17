#!/usr/bin/env bash
# Writes one day's content document for a turn game into the live Firestore,
# the way publishDay would have: days/<day>/turns/<game> with a single `json`
# field. For the day the scheduler will never reach -- the one a game ships
# on, since publishDay writes today and tomorrow at 03:00 UTC and a deploy
# lands after that -- or for a hand-picked day written ahead of it.
#
#   tools/seed_turn_day.sh how_big 20260917 '{"item":"cairn","metres":0.5}'
#
# Create-only: a day already published answers 409 and is left exactly as it
# is, the same rule publishDay keeps. Needs gcloud signed in to an account
# with Firestore write on daily-games-420bf. It is a production write, so a
# person runs it (or allows it), the way the deploy is.
set -euo pipefail
game="${1:?game id, e.g. how_big}"
day="${2:?day key, yyyymmdd in UTC}"
json="${3:?the content as one JSON string}"
project="${FIREBASE_PROJECT:-daily-games-420bf}"
base="https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents"
token="$(gcloud auth print-access-token)"
body="$(python3 -c 'import json,sys; print(json.dumps({"fields":{"json":{"stringValue":sys.argv[1]}}}))' "$json")"
curl -s -X POST "$base/days/$day/turns?documentId=$game" \
  -H "Authorization: Bearer $token" -H "x-goog-user-project: $project" \
  -H "Content-Type: application/json" -d "$body" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); f=d.get("fields",{}).get("json",{}).get("stringValue"); print(("wrote " + f) if f else ("refused: " + d.get("error",{}).get("message","?")))'
