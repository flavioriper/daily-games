#!/usr/bin/env bash
# Makes themed days as the night would -- the theme, the drawings, the bead
# pictures and what the supervisor said of each -- into tools/days/themed/,
# and rebuilds the dashboard, whose Themed days shows them. Publishes
# nothing. Needs OPENROUTER_API_KEY; a day is about a hundred seconds and
# US$0.20 (read off the first one, 2026-10-13). A day already made is kept.
#
#   tools/themed_days.sh [yyyymmdd] [days]     # from tomorrow, three days
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
from="${1:-$(date -u -v+1d +%Y%m%d)}"
# Drawn on Vertex AI, on a Google Cloud project's bill (its credits), when
# VERTEX_PROJECT names one: the token is VERTEX_ACCOUNT's gcloud login.
#   VERTEX_PROJECT=production-506015 VERTEX_ACCOUNT=andressa.t@navlio.io tools/themed_days.sh
if [ -n "${VERTEX_PROJECT:-}" ] && [ -z "${VERTEX_ACCESS_TOKEN:-}" ]; then
  VERTEX_ACCESS_TOKEN="$(gcloud auth print-access-token ${VERTEX_ACCOUNT:+--account "$VERTEX_ACCOUNT"})"
  export VERTEX_ACCESS_TOKEN
fi
cd "$here/../server/functions"
npm run build >/dev/null
node lib/cli.js themed "$from" "${2:-3}" "$here/days/themed"
python3 "$here/build_dashboard.py"
