#!/usr/bin/env bash
# Puts a themed day tools/themed_days.sh made into this Mac's copy of the
# game as TODAY's pictures, so Pixel Garden, Button Box, Toy Cannons and
# Gumdrop (its `jellies`) can be played on it (core/themed_pictures.gd reads the backend's cache; the
# game run from the editor or the command line wakes the backend). Touches
# nothing but that one cache file; `off` takes it away again and puts the
# backend's own cache back if one was there (kept aside as <file>.real).
#
#   tools/themed_play.sh 20261014      # that made day, as today's
#   tools/themed_play.sh 20261014 pixel   # its pixel art pictures (days/themed-pixel)
#   tools/themed_play.sh 20261019 vistas  # its painted vistas (days/themed-vistas)
#   tools/themed_play.sh off
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cache="$HOME/Library/Application Support/Godot/app_userdata/Peeplet Daily/backend_cache"
file="$cache/pictures-$(date -u +%Y%m%d)-content.json"
vfile="$cache/vistas-$(date -u +%Y%m%d)-content.json"
# The backend's real cache for today (written by its prefetch) is kept aside
# as <file>.real while a made day sits in its place, and put back by `off`;
# without one, `off` just removes the made day's file.
# `keep` marks the slot as holding a made day (<file>.made) so `off` touches
# only slots this script filled: the other cache file stays as it was.
keep() { [ -f "$1" ] && [ ! -f "$1.real" ] && mv "$1" "$1.real" && echo "kept $1.real" || true; touch "$1.made"; }
back() {
  [ -f "$1.made" ] || return 0
  rm -f "$1.made"
  if [ -f "$1.real" ]; then mv -f "$1.real" "$1"; echo "restored $1"; else rm -f "$1"; echo "removed $1"; fi
}
if [ "${1:-}" = "off" ]; then
  back "$file"; back "$vfile"; exit 0
fi
if [ "${2:-}" = vistas ]; then
  mkdir -p "$cache"; keep "$vfile"
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
mkdir -p "$cache"; keep "$file"
dir=themed; [ "${2:-}" = pixel ] && dir=themed-pixel
python3 - "$here/days/$dir/${1:?a made day, yyyymmdd}.json" "$file" <<'PY'
import json, sys
day = json.load(open(sys.argv[1]))
if not day.get("pictures"):
    sys.exit("that day kept no pictures")
json.dump(day["pictures"], open(sys.argv[2], "w"))
print("%s: %s, sizes %s" % (sys.argv[2], day["theme"]["name"]["en"], ", ".join(sorted(day["pictures"]["sizes"], key=int))))
PY
