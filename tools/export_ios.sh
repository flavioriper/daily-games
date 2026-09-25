#!/usr/bin/env bash
# Exports the iOS Xcode project with godot-iap's GDExtension switched on (it
# is iOS-only and stays .disabled everywhere else), then embeds its frameworks.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ext=$(find addons/godot-iap -name 'godot_iap.gdextension.disabled' | head -1)
on="${ext%.disabled}"
out=build/ios
mkdir -p "$out"
mv "$ext" "$on"
# The export's editor records the switched-on extension in
# .godot/extension_list.cfg; left there, every later run errors on loading it.
# It is the project's only GDExtension, so the list goes with it.
trap 'mv "$on" "$ext"; rm -f .godot/extension_list.cfg' EXIT
godot --headless --path . --export-debug iOS "$out/peeplet-daily.ipa"
IOS_EXPORT_DIR="$(pwd)/$out" GODOT_IAP_ADDON_DIR="$(pwd)/addons/godot-iap" \
  addons/godot-iap/scripts/fix_ios_embed.sh
