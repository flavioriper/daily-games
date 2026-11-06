#!/bin/bash
# Builds the Swarm's call audio plugin (native/swarm_voice) into addons/swarm_voice.
# Android: both AARs with the plugin's gradle wrapper, against android/build's godot-lib.
# docs/agents/bot.md, "Echo cancelling".
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
# the SDK Godot exports with; this Mac's ANDROID_HOME names an empty folder
for d in "${ANDROID_HOME:-}" /opt/homebrew/share/android-commandlinetools "$HOME/Library/Android/sdk"; do
  if [ -n "$d" ] && [ -d "$d/platforms" ]; then export ANDROID_HOME="$d"; break; fi
done
test -f android/build/libs/release/godot-lib.template_release.aar || { echo "android/build is missing: run tools/patch_android_template.sh"; exit 1; }
cd native/swarm_voice/android
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew -q assembleDebug assembleRelease
mkdir -p "$ROOT/addons/swarm_voice/android"
cp build/outputs/aar/swarm_voice-debug.aar "$ROOT/addons/swarm_voice/android/swarm_voice.debug.aar"
cp build/outputs/aar/swarm_voice-release.aar "$ROOT/addons/swarm_voice/android/swarm_voice.release.aar"
echo "built addons/swarm_voice/android/swarm_voice.{debug,release}.aar"
