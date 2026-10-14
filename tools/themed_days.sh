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
# VERTEX_PROJECT names one: the token is VERTEX_ACCOUNT's gcloud login, asked for each drawing.
#   VERTEX_PROJECT=production-506015 VERTEX_ACCOUNT=andressa.t@navlio.io tools/themed_days.sh
# Asked for each drawing: the token gcloud holds may have minutes left.
if [ -n "${VERTEX_PROJECT:-}" ] && [ -z "${VERTEX_ACCESS_TOKEN:-}" ]; then
  export VERTEX_TOKEN_COMMAND="gcloud auth print-access-token ${VERTEX_ACCOUNT:+--account $VERTEX_ACCOUNT}"
fi
# DAILY_PICTURE_STYLE=pixel draws pixel art (gemini-3-pro-image unless
# DAILY_IMAGE_MODEL says otherwise) into days/themed-pixel/, on the themes
# of the days already in days/themed/, so the page shows the two side by side.
out="$here/days/themed"; lend=()
if [ "${DAILY_PICTURE_STYLE:-}" = pixel ]; then
  out="$here/days/themed-pixel"; lend=("$here/days/themed")
  [ -n "${VERTEX_PROJECT:-}" ] && export DAILY_IMAGE_MODEL="${DAILY_IMAGE_MODEL:-gemini-3-pro-image}"
fi
cd "$here/../server/functions"
npm run build >/dev/null
node lib/cli.js themed "$from" "${2:-3}" "$out" ${lend[@]+"${lend[@]}"}
python3 "$here/build_dashboard.py"
