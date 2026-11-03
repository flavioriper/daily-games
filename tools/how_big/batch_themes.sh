#!/usr/bin/env bash
# Fresh themes for a How Big? batch: the night's themes repeat after a lap
# and the writer then offers what is already taken. Each new theme is told
# to avoid every theme the batch has used, and lands as a day file that
# tools/how_big/batch_things.sh picks up next.
#
#   NEON_ENV=path/to/.env.local tools/how_big/batch_themes.sh [count]   (default 20)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../.."
batch="$root/build/how_big_batch"
count="${1:-20}"
set -a; source "$root/server/functions/.env"; source "${NEON_ENV:?the file with NEON_AI_GATEWAY_TOKEN}"; set +a
unset ANTHROPIC_API_KEY OPENROUTER_API_KEY VERTEX_PROJECT DAILY_THEME
cd "$root/server/functions"
npm run build >/dev/null
n=$(ls "$batch"/day-*.json | wc -l | tr -d ' ')
for i in $(seq 1 "$count"); do
  n=$((n + 1))
  out="$batch/day-$(printf '%03d' "$n").json"
  # Unique themes so far, one file each, as the ones to avoid.
  avoid=$(node -e 'const fs=require("fs"),seen=new Set(),out=[];for(const f of fs.readdirSync(process.argv[1]).filter(f=>/^day-\d+\.json$/.test(f)).sort()){const t=JSON.parse(fs.readFileSync(process.argv[1]+"/"+f)).theme;if(t&&!seen.has(t.id)){seen.add(t.id);out.push(process.argv[1]+"/"+f)}}console.log(out.join("\n"))' "$batch")
  # shellcheck disable=SC2086
  node lib/cli.js theme "$((20270100 + n))" "$out" $avoid || { echo "--- theme $n failed"; rm -f "$out"; }
done
