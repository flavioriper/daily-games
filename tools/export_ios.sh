#!/usr/bin/env bash
# Exports the iOS Xcode project. (Until 2026-11-05 it also switched on
# godot-iap's GDExtension and embedded its frameworks; the purchase and the
# addon left the game that day.)
#
#   tools/export_ios.sh                    debug export (Godot's debug engine)
#   tools/export_ios.sh --release          the App Store build: release engine,
#                                          the editor-only MCP addon stripped out
#   tools/export_ios.sh --release --beta   the TestFlight build: the same, plus
#                                          the `beta` feature tag, which shows
#                                          the testers-only parts (the Swarm,
#                                          bot/call.gd testers_build)
#
# TestFlight and the App Store share one binary, so a beta build must never
# be the one sent to App Review. The channel goes to build/ios/channel, and
# tools/upload_ios.sh numbers the two apart (store builds end in .1).
# Archiving and uploading the Xcode project it writes is tools/upload_ios.sh.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
out=build/ios
mode=--export-debug
release=0
beta=0
for arg in "$@"; do
  case "$arg" in
    --release) release=1 ;;
    --beta) beta=1 ;;
    *) echo "unknown option $arg" >&2; exit 2 ;;
  esac
done
# Both files may be edited below; put them back from a copy, which also keeps
# any uncommitted edit to them (a `git checkout` would not).
keep="$(mktemp -d)"
cp project.godot export_presets.cfg "$keep/"
restore() {
  cp "$keep/project.godot" "$keep/export_presets.cfg" .; rm -rf "$keep"
}
trap restore EXIT
if [[ $release == 1 ]]; then
  mode=--export-release
  tools/strip_dev_addons.sh
fi
channel=store
[[ $release == 1 ]] || channel=debug
if [[ $beta == 1 ]]; then
  channel=beta
  # The iOS preset's custom_features (preset.1): empty in git, `beta` here.
  perl -0pi -e 's/(name="iOS"\n(?:[^\[]*?\n)?custom_features=)""/$1"beta"/' export_presets.cfg
  grep -q 'custom_features="beta"' export_presets.cfg \
    || { echo "could not set the beta feature on the iOS preset" >&2; exit 1; }
fi
rm -rf "$out"; mkdir -p "$out"
godot --headless --path . "$mode" iOS "$out/peeplet-daily.ipa"
echo "$channel" > "$out/channel"
echo "exported the $channel build"
# The exporter writes the launcher label from config/name ("Peeplet Daily",
# which must stay: it names the save folder). The home-screen label is "Peeplet".
sed -i '' 's/INFOPLIST_KEY_CFBundleDisplayName = "Peeplet Daily";/INFOPLIST_KEY_CFBundleDisplayName = "Peeplet";/' \
  "$out/peeplet-daily.xcodeproj/project.pbxproj"
grep -q 'INFOPLIST_KEY_CFBundleDisplayName = "Peeplet";' "$out/peeplet-daily.xcodeproj/project.pbxproj" \
  || { echo "display name not patched"; exit 1; }
