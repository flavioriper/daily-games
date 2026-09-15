#!/usr/bin/env bash
# Build the native Android APK and push it to Firebase App Distribution, so the
# game can be installed and played on a phone.
#
#   tools/deploy_android.sh            build + distribute
#   tools/deploy_android.sh --local    build only, leave the APK in build/android
#
# The build is debug-signed with ~/.android/debug.keystore (a release build
# would need a release keystore, which is deliberately not in this repo).
# Nothing deploys on push; this script is the only way a new build goes out.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

godot_bin="${GODOT:-godot}"
app_id="1:881491152475:android:0e88e9f9a22583fdd0b97e"
testers="${TESTERS:-flavioriper@gmail.com}"
out="build/android/peeplet-daily.apk"

mkdir -p build/android

# The export reads the .godot import cache, so make sure it is current.
"$godot_bin" --headless --path . --import >/dev/null
"$godot_bin" --headless --path . --export-debug Android "$out"

[[ -s "$out" ]] || { echo "export produced no apk"; exit 1; }
echo "built $out ($(du -h "$out" | cut -f1))"

# Godot rewrites project.godot with an editor header on some runs; that is a
# by-product of exporting, not a change worth keeping.
git checkout -- project.godot 2>/dev/null || true

[[ "${1:-}" == "--local" ]] && exit 0

firebase appdistribution:distribute "$out" \
  --app "$app_id" \
  --project peeplet-daily \
  --release-notes "$(git log -1 --pretty='%h %s')" \
  --testers "$testers"
