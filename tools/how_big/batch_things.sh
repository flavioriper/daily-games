#!/usr/bin/env bash
# Makes How Big? things in a batch with the night's own pipeline
# (server/functions/src/things.ts, its writer and three gates), to be folded
# into the bundled table by tools/how_big/fold_batch.py. Same models as the
# night: server/functions/.env, plus the gateway's credentials.
#
#   node tools/how_big/batch_prep.mjs 50                 (once: pool + day files)
#   NEON_ENV=path/to/.env.local tools/how_big/batch_things.sh [want]   (default 70)
#
# Each day file asks the writer for four things on its theme and keeps two at
# most. It stops once `want` new things are kept; run it again to go on.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../.."
batch="$root/build/how_big_batch"
want="${1:-70}"
set -a; source "$root/server/functions/.env"; source "${NEON_ENV:?the file with NEON_AI_GATEWAY_TOKEN}"; set +a
unset ANTHROPIC_API_KEY OPENROUTER_API_KEY VERTEX_PROJECT
cd "$root/server/functions"
npm run build >/dev/null
kept() { node -e 'const p=require(process.argv[1]),n=require(process.argv[2]);console.log(p.filter(t=>!n.includes(t.id)).length)' "$batch/pool.json" "$batch/night_ids.json"; }
for f in "$batch"/day-*.json; do
  done_already=$(node -e 'console.log(require(process.argv[1]).thingTries ? 1 : 0)' "$f")
  [ "$done_already" = 1 ] && continue
  n=$(kept); echo "--- $(date '+%H:%M:%S') $n of $want kept; $(basename "$f")"
  [ "$n" -ge "$want" ] && break
  node lib/cli.js things "$batch/pool.json" "$f" || echo "--- $(basename "$f") failed"
done
echo "--- kept $(kept) new things; review them, then: python3 tools/how_big/fold_batch.py"
