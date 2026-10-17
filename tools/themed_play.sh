#!/usr/bin/env bash
# Puts a themed day tools/themed_days.sh made into this Mac's copy of the
# game as TODAY's pictures, so Pixel Garden, Button Box, Toy Cannons and
# Gumdrop (its `jellies`) can be played on it (core/themed_pictures.gd reads the backend's cache; the
# game run from the editor or the command line wakes the backend). Touches
# nothing but that one cache file; `off` takes it away again.
#
#   tools/themed_play.sh 20261014      # that made day, as today's
#   tools/themed_play.sh 20261014 pixel   # its pixel art pictures (days/themed-pixel)
#   tools/themed_play.sh 20261019 vistas  # its painted vistas (days/themed-vistas)
#   tools/themed_play.sh off
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cache="$HOME/Library/Application Support/Godot/app_userdata/Peeplet Daily/backend_cache"
file="$cache/pictures-$(date -u +%Y%m%d)-content.json"
if [ "${1:-}" = "off" ]; then
  rm -f "$file" "$cache/vistas-$(date -u +%Y%m%d)-content.json"; echo "removed $file and today's vistas"; exit 0
fi
if [ "${2:-}" = vistas ]; then
  mkdir -p "$cache"
  python3 - "$here/days/themed-vistas/$1.json" "$cache/vistas-$(date -u +%Y%m%d)-content.json" <<'PY'
import json, sys
day = json.load(open(sys.argv[1]))
if not day.get("vistas"):
    sys.exit("that day kept no vistas")
json.dump(day["vistas"], open(sys.argv[2], "w"))
print("%s: %s" % (sys.argv[2], day["theme"]["name"]["en"]))
PY
  exit 0
fi
mkdir -p "$cache"
dir=themed; [ "${2:-}" = pixel ] && dir=themed-pixel
python3 - "$here/days/$dir/${1:?a made day, yyyymmdd}.json" "$file" <<'PY'
import json, sys
day = json.load(open(sys.argv[1]))
if not day.get("pictures"):
    sys.exit("that day kept no pictures")
json.dump(day["pictures"], open(sys.argv[2], "w"))
print("%s: %s, sizes %s" % (sys.argv[2], day["theme"]["name"]["en"], ", ".join(sorted(day["pictures"]["sizes"], key=int))))
PY
