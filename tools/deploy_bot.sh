#!/usr/bin/env bash
# Builds and deploys the Swarm's call server (server/bot) to Cloud Run as `peeplet-bot`. PERSON-RUN: this changes
# production, so an agent session does not run it. Setup that must exist first (secrets, bucket, service account,
# Artifact Registry repo): docs/agents/bot.md, "Deploy".
#
#   tools/deploy_bot.sh --project daily-games-420bf
#
# The project has to be named on the command line, and gcloud has to be logged in as an account allowed to deploy
# there (the navlio account was refused on 2026-11-04).
set -euo pipefail

P=daily-games-420bf
if [ "${1:-}" != "--project" ] || [ "${2:-}" != "$P" ]; then
  echo "usage: tools/deploy_bot.sh --project $P   (the project is named on purpose: this deploys to production)" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "gcloud account: $(gcloud config get-value account 2>/dev/null)"
echo "deploying peeplet-bot to $P (us-central1)"

# The bot's pixel-garden bank is a copy of the game's; take it fresh so the two never drift.
cp content/pixel_garden.json server/bot/content/pixel_garden.json

TAG="$(git rev-parse --short HEAD)-$(date -u +%Y%m%d%H%M%S)"
if [ -n "$(git status --porcelain -- server/bot content/pixel_garden.json)" ]; then
  echo "note: server/bot has uncommitted changes; the tag is $TAG but the image holds the working tree" >&2
fi

gcloud builds submit server/bot --config server/bot/cloudbuild.yaml --project "$P" --substitutions "_TAG=$TAG"

URL="$(gcloud run services describe peeplet-bot --region us-central1 --project "$P" --format 'value(status.url)')"
echo "deployed $TAG at $URL"
echo "next: tools/public_invoker.sh peeplet-bot (first deploy only), then: curl $URL/health"
