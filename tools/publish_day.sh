#!/usr/bin/env bash
# Publishes today's and tomorrow's content to the live project, exactly as
# the 03:00 UTC scheduler does (publishDays in server/functions/src/index.ts):
# for the day a game ships on, which the scheduler never reaches, or a night
# it missed. A day already published is left as it is.
#
# Writes to production, so a person runs it, not an agent session. Needs
# application default credentials (`gcloud auth application-default login`)
# that may write the project's Firestore and, for Golden Acorn's day to be
# the model's rather than the bank's, use Vertex AI there.
#
#   tools/publish_day.sh
set -euo pipefail
cd "$(dirname "$0")/../server/functions"
npm run build >/dev/null
GOOGLE_CLOUD_PROJECT=daily-games-420bf GCLOUD_PROJECT=daily-games-420bf node lib/cli.js publish
