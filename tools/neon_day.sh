#!/usr/bin/env bash
# One themed day made on the Neon AI Gateway alone: Claude writes, maps and
# judges (Haiku, then Sonnet, then Opus for the maps; Sonnet reviews, Opus has
# the last word) and gpt-image-2 draws. Publishes nothing; the day lands in
# tools/days/themed-pixel/ for tools/themed_play.sh <day> pixel.
#
#   NEON_ENV=path/to/.env.local tools/neon_day.sh 20261102 ["the zoo"]
#
# NEON_ENV holds NEON_AI_GATEWAY_TOKEN and NEON_AI_GATEWAY_BASE_URL (neon env
# pull from a folder linked to the peeplet project's ai-gateway branch).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
set -a; source "${NEON_ENV:?the file with the gateway credentials}"; set +a
export DAILY_PICTURE_STYLE=pixel DAILY_IMAGE_MODEL=neon/gpt-image-2 DAILY_SHAPES_MODEL=neon/gpt-image-2
export DAILY_MODEL=anthropic/claude-haiku-5.5 DAILY_REVIEW_MODEL=anthropic/claude-sonnet-5.5
export DAILY_ROWS_MODEL=anthropic/claude-sonnet-5.5 DAILY_FINAL_MODEL=anthropic/claude-opus-5.5
export DAILY_MAP_TIERS="anthropic/claude-haiku-5.5,anthropic/claude-sonnet-5.5,anthropic/claude-opus-5.5"
[ -n "${2:-}" ] && export DAILY_THEME="$2"
unset ANTHROPIC_API_KEY OPENROUTER_API_KEY VERTEX_PROJECT
cd "$here/../server/functions"
npm run build >/dev/null
out="$here/days/themed-pixel"
node lib/cli.js themed "${1:?yyyymmdd}" 1 "$out"
# A step that fails leaves the others: the day is judged on what it kept.
for step in hoops quizzes vistas; do
  echo "--- $step $(date '+%H:%M:%S')"
  node lib/cli.js "$step" "$out/$1.json" || echo "--- $step failed"
done
