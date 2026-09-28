#!/usr/bin/env bash
# Build the release AAB for Google Play, signed with the upload key.
#
#   tools/release_android.sh     -> build/android/peeplet-daily.aab
#
# The upload key lives outside the repo (UPLOAD_KEYSTORE, default
# ~/keys/peeplet-upload.jks, alias "upload") and its password in the macOS
# Keychain, stored once by hand:
#
#   security add-generic-password -s peeplet-upload-keystore -a upload -w
#
# The preset is switched to AAB for this one export and put back from a copy
# afterwards (not `git checkout`, which would also throw away uncommitted
# preset edits). versionCode is the commit count on HEAD, so every build from
# a later commit outranks the last one Play saw; override with VERSION_CODE.
# Firebase test builds stay debug-signed (tools/deploy_android.sh), so a Play
# build and a Firebase build will not install over each other.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

godot_bin="${GODOT:-godot}"
keystore="${UPLOAD_KEYSTORE:-$HOME/keys/peeplet-upload.jks}"
out="build/android/peeplet-daily.aab"
code="${VERSION_CODE:-$(git rev-list --count HEAD)}"

[[ -f "$keystore" ]] || { echo "no upload keystore at $keystore"; exit 1; }
pass="$(security find-generic-password -s peeplet-upload-keystore -a upload -w 2>/dev/null)" || {
  echo "no keystore password in the Keychain; store it once with:"
  echo "  security add-generic-password -s peeplet-upload-keystore -a upload -w"
  exit 1
}
[[ -f analytics_secret.cfg ]] || echo "warning: no analytics_secret.cfg, this build reports nothing"

mkdir -p build/android
backup="$(mktemp -d)"
cp project.godot export_presets.cfg "$backup/"
restore() { cp "$backup/project.godot" "$backup/export_presets.cfg" "$root/"; rm -rf "$backup"; }
trap restore EXIT

"$godot_bin" --headless --path . --import >/dev/null
tools/strip_dev_addons.sh
GODOT="$godot_bin" tools/patch_android_template.sh

# AAB rather than APK, and this build's versionCode.
perl -pi -e 's{^gradle_build/export_format=\d+}{gradle_build/export_format=1}; s{^version/code=\d+}{version/code='"$code"'}' export_presets.cfg
grep -q '^gradle_build/export_format=1' export_presets.cfg || { echo "preset did not switch to AAB"; exit 1; }

rm -f "$out"
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keystore" \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$pass" \
  "$godot_bin" --headless --path . --export-release Android "$out"

[[ -s "$out" ]] || { echo "export produced no aab"; exit 1; }
echo "built $out ($(du -h "$out" | cut -f1)), versionCode $code"
