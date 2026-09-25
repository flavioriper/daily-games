#!/usr/bin/env bash
# Install the Android build template (if android/ has none) and raise its
# Android Gradle plugin from 8.6.1 to 8.9.1.
#
# Why: godot-iap's openiap-google 3.5.2 pulls androidx.core 1.18, which
# refuses to build under AGP older than 8.9.1, and Godot 4.7's template pins
# 8.6.1 (its Gradle wrapper, 8.11.1, already carries 8.9).
#
# Why this script installs the template too: Godot only honours
# --install-android-build-template as part of a full Android export (not with
# --quit, --editor or --export-pack), and that export would build with the
# unpatched 8.6.1 and fail. So this unpacks the engine's own
# android_source.zip the way Godot does (android/build, its .gdignore, and
# android/.build_version, which the exporter checks against the engine), and
# the export then runs WITHOUT --install-android-build-template.
#
# Run before the export; safe to run twice. Fails loudly if the pinned line
# is not found, so a new template is noticed here and not in a Gradle error.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
godot_bin="${GODOT:-godot}"
cfg=android/build/config.gradle
want="8.9.1"

if [[ ! -f android/.build_version ]]; then
  # "4.7.stable.official.5b4e0cb0f" -> "4.7.stable", the templates' folder name.
  version="$("$godot_bin" --version | sed -E 's/\.[^.]+\.[^.]+$//')"
  if [[ "$(uname)" == "Darwin" ]]; then
    templates="$HOME/Library/Application Support/Godot/export_templates/$version"
  else
    templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version"
  fi
  src="$templates/android_source.zip"
  [[ -f "$src" ]] || { echo "patch_android_template: no $src; install the $version export templates" >&2; exit 1; }
  rm -rf android/build
  mkdir -p android/build
  unzip -q "$src" -d android/build
  : > android/build/.gdignore
  printf '%s\n' "$version" > android/.build_version
  echo "patch_android_template: installed the $version build template"
fi

[[ -f "$cfg" ]] || { echo "patch_android_template: $cfg not found" >&2; exit 1; }
if grep -q "androidGradlePlugin: '$want'" "$cfg"; then
  echo "patch_android_template: AGP already $want"
  exit 0
fi
if ! grep -q "androidGradlePlugin: '8.6.1'" "$cfg"; then
  echo "patch_android_template: expected androidGradlePlugin: '8.6.1' in $cfg, found:" >&2
  grep -n "androidGradlePlugin" "$cfg" >&2 || echo "  (no androidGradlePlugin line)" >&2
  exit 1
fi
perl -pi -e "s/androidGradlePlugin: '8\.6\.1'/androidGradlePlugin: '$want'/" "$cfg"
grep -q "androidGradlePlugin: '$want'" "$cfg"
echo "patch_android_template: AGP 8.6.1 -> $want"
