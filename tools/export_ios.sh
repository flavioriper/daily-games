#!/usr/bin/env bash
# Exports the iOS Xcode project with godot-iap's GDExtension switched on (it
# is iOS-only and stays .disabled everywhere else), then embeds its frameworks.
#
#   tools/export_ios.sh             debug export (Godot's debug engine)
#   tools/export_ios.sh --release   the App Store build: release engine, and the
#                                   editor-only MCP addon stripped out
#
# Archiving and uploading the Xcode project it writes is tools/upload_ios.sh.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ext=$(find addons/godot-iap -name 'godot_iap.gdextension.disabled' | head -1)
on="${ext%.disabled}"
out=build/ios
mode=--export-debug
keep=""
restore() {
  mv "$on" "$ext"
  # The export's editor records the switched-on extension in
  # .godot/extension_list.cfg; left there, every later run errors on loading it.
  # It is the project's only GDExtension, so the list goes with it.
  rm -f .godot/extension_list.cfg
  if [[ -n "$keep" ]]; then cp "$keep/project.godot" "$keep/export_presets.cfg" .; rm -rf "$keep"; fi
}
mv "$ext" "$on"
trap restore EXIT
if [[ "${1:-}" == "--release" ]]; then
  mode=--export-release
  # strip_dev_addons.sh edits both files; put them back from a copy, which also
  # keeps any uncommitted edit to them (a `git checkout` would not).
  keep="$(mktemp -d)"
  cp project.godot export_presets.cfg "$keep/"
  tools/strip_dev_addons.sh
fi
rm -rf "$out"; mkdir -p "$out"
godot --headless --path . "$mode" iOS "$out/peeplet-daily.ipa"
IOS_EXPORT_DIR="$(pwd)/$out" GODOT_IAP_ADDON_DIR="$(pwd)/addons/godot-iap" \
  addons/godot-iap/scripts/fix_ios_embed.sh
