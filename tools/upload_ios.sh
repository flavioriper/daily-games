#!/usr/bin/env bash
# Archive the Xcode project tools/export_ios.sh --release wrote and send it to
# App Store Connect, where it lands in TestFlight.
#
#   tools/export_ios.sh --release --beta && tools/upload_ios.sh   TestFlight
#   tools/export_ios.sh --release && tools/upload_ios.sh          App Store
#   tools/upload_ios.sh --archive-only     build the .xcarchive, upload nothing
#   tools/upload_ios.sh --upload-only      upload the .xcarchive already built
#
# Signing is manual: the team's Apple Distribution certificate (in this Mac's
# keychain) and the "Peeplet Daily App Store" profile from the developer portal.
# Automatic signing would archive for development first, which needs a
# registered iPhone, and the team has none. The upload goes through the Apple
# account signed in to Xcode (Settings > Accounts). The build number is the
# commit count on HEAD, like the Android versionCode, so every upload from a later commit
# outranks the last one; override with BUILD_NUMBER. A store build (exported
# without --beta) is the count plus ".1", so it can follow a beta build of the
# same commit, and App Store Connect tells the two apart at a glance: **only a
# build ending in .1 may go to App Review** -- a beta build shows the
# testers-only parts (bot/call.gd testers_build).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

project=build/ios/peeplet-daily.xcodeproj
archive=build/ios/peeplet-daily.xcarchive
channel="$(cat build/ios/channel 2>/dev/null || echo unknown)"
case "$channel" in
  beta) build="${BUILD_NUMBER:-$(git rev-list --count HEAD)}" ;;
  store) build="${BUILD_NUMBER:-$(git rev-list --count HEAD).1}" ;;
  *) echo "build/ios/channel is '$channel': export with tools/export_ios.sh --release [--beta] first" >&2; exit 1 ;;
esac
echo "uploading the $channel build as $build"
team=R6H9QS77XM
profile="Peeplet Daily App Store"

[[ -d "$project" ]] || { echo "no $project; run tools/export_ios.sh --release first"; exit 1; }

if [[ "${1:-}" != "--upload-only" ]]; then
rm -rf "$archive"
xcodebuild -project "$project" -scheme peeplet-daily -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive" \
  -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$build" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution" \
  DEVELOPMENT_TEAM="$team" PROVISIONING_PROFILE_SPECIFIER="$profile" \
  archive
echo "archived $archive, build $build"
fi

[[ "${1:-}" == "--archive-only" ]] && exit 0

opts="$(mktemp -d)/export.plist"
cat > "$opts" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict><key>com.peeplet.daily</key><string>$profile</string></dict>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$opts" \
  -exportPath build/ios/upload -allowProvisioningUpdates
echo "uploaded build $build; it shows in TestFlight once App Store Connect finishes processing it"
