#!/usr/bin/env bash
# Exports the iOS Xcode project. (Until 2026-11-05 it also switched on
# godot-iap's GDExtension and embedded its frameworks; the purchase and the
# addon left the game that day.)
#
#   tools/export_ios.sh             debug export (Godot's debug engine)
#   tools/export_ios.sh --release   the App Store build: release engine, and the
#                                   editor-only MCP addon stripped out
#
# Archiving and uploading the Xcode project it writes is tools/upload_ios.sh.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
out=build/ios
mode=--export-debug
keep=""
restore() {
  if [[ -n "$keep" ]]; then cp "$keep/project.godot" "$keep/export_presets.cfg" .; rm -rf "$keep"; fi
}
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
# The exporter writes the launcher label from config/name ("Peeplet Daily",
# which must stay: it names the save folder). The home-screen label is "Peeplet".
sed -i '' 's/INFOPLIST_KEY_CFBundleDisplayName = "Peeplet Daily";/INFOPLIST_KEY_CFBundleDisplayName = "Peeplet";/' \
  "$out/peeplet-daily.xcodeproj/project.pbxproj"
grep -q 'INFOPLIST_KEY_CFBundleDisplayName = "Peeplet";' "$out/peeplet-daily.xcodeproj/project.pbxproj" \
  || { echo "display name not patched"; exit 1; }
