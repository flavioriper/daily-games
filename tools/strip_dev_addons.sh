#!/usr/bin/env bash
# Take the editor-only godot_mcp addon out of an export: its MCPGameBridge
# autoload and its plugin entry leave project.godot, and the addon's files
# leave the package. The bridge is inert without a debugger attached, but a
# store build carries none of it. Run right before an export, on a working
# copy that is thrown away (CI) or restored afterwards
# (tools/deploy_android.sh does `git checkout` on both files).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Only godot_mcp's entry leaves the plugin list: the AdMob plugin stays
# enabled, because its exporter runs during the export. (godot-iap is not in
# the list at all since 2026-10-27: core/store.gd says why.)
perl -ni -e 'print unless /^MCPGameBridge=/' project.godot
perl -pi -e 's{"res://addons/godot_mcp/plugin\.cfg",\s*}{}; s{,\s*"res://addons/godot_mcp/plugin\.cfg"}{}; s{^enabled=PackedStringArray\("res://addons/godot_mcp/plugin\.cfg"\)\n}{}' project.godot
perl -pi -e 's{^exclude_filter="([^"]*)"}{my $f = $1; $f =~ /addons\/godot_mcp/ ? qq(exclude_filter="$f") : qq(exclude_filter="$f, addons/godot_mcp/*")}e' export_presets.cfg
if grep -q 'MCPGameBridge\|addons/godot_mcp/plugin' project.godot; then
  echo "strip_dev_addons: godot_mcp is still in project.godot" >&2
  exit 1
fi
echo "stripped godot_mcp from this export"
