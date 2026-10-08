#!/usr/bin/env bash
# Prints the day Golden Acorn would publish and writes nothing. The model is
# asked through Vertex AI on the live project, as whoever is signed in to
# application default credentials (`gcloud auth application-default login`,
# an account that may use Vertex AI there): eight short requests, a minute
# or two, a few cents of the project's bill at most. The way to read what
# the model writes before it is trusted with a night.
#
#   tools/acorn_day.sh [yyyymmdd]
#   DAILY_MODEL=google/gemini-2.5-flash tools/acorn_day.sh    # another model
#   DAILY_MODEL=off tools/acorn_day.sh                        # the bank's day
set -euo pipefail
cd "$(dirname "$0")/../server/functions"
npm run build >/dev/null
GOOGLE_CLOUD_PROJECT=daily-games-420bf node lib/cli.js day "$@"
