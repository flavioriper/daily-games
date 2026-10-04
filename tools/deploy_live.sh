#!/usr/bin/env bash
# Deploys the Realtime Database rules that Versus online runs on
# (server/database.rules.json): the queue, the claim, a move in turn, the
# clocks and the results. There is no function behind them -- the rules are
# the whole server.
#
# The live project is daily-games-420bf. Its Realtime Database instance has
# to be created once by hand first (Firebase console, Build > Realtime
# Database, United States); an instance anywhere else has a different host,
# and core/live.gd's HOST has to say so. Run by a person, like
# tools/deploy_functions.sh; prove a change first with
# tests/_probe_live_rules.sh against the emulator.
set -euo pipefail
cd "$(dirname "$0")/../server"
firebase deploy --only database --project daily-games-420bf
