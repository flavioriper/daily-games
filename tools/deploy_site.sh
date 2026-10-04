#!/usr/bin/env bash
# Deploys the hosted site (server/site, by server/firebase.json's hosting
# block) to https://daily-games-420bf.web.app: the friend link's page
# (/f/<CODE>, every one rewritten to f/index.html), the Android App Links
# statement (/.well-known/assetlinks.json, which names the certificates a
# build must be signed with for an https friend link to open the game
# without asking), the privacy policy and app-ads.txt.
#
# Hosting only: no rules, no functions. Run by a person, like
# tools/deploy_live.sh. After it, the statement can be read back with
#   curl -i https://daily-games-420bf.web.app/.well-known/assetlinks.json
# (200, application/json), and a link with any code shows the page.
set -euo pipefail
cd "$(dirname "$0")/../server"
firebase deploy --only hosting --project daily-games-420bf
