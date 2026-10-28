#!/usr/bin/env bash
# Install the Android build template (if android/ has none), raise its
# Android Gradle plugin from 8.6.1 to 8.9.1, give its manifest the way in
# for a friend link, wire the Firebase Gradle plugins, and turn R8 on for the
# release build (patch 4 at the bottom says why).
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
# The friend link (docs/agents/friends.md, "The link"): an activity-alias on
# the game's one activity, .FriendLink, beside the launcher's, with a filter
# for peepletdaily://f/<CODE> and one for
# https://daily-games-420bf.web.app/f/<CODE> (autoVerify; verified against
# server/site/.well-known/assetlinks.json). It goes in the template's
# src/main manifest because the exporter writes only src/debug and
# src/release, and Gradle merges main under them. core/deep_link.gd reads
# what arrives.
#
# Run before the export; safe to run twice: each patch is skipped when it is
# already there, and both always get their turn. Fails loudly if what a patch
# expects is not found, so a new template is noticed here and not in a Gradle
# error (or, for the link, not at all).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
godot_bin="${GODOT:-godot}"
cfg=android/build/config.gradle
manifest=android/build/src/main/AndroidManifest.xml
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

# 1. The Android Gradle plugin.
[[ -f "$cfg" ]] || { echo "patch_android_template: $cfg not found" >&2; exit 1; }
if grep -q "androidGradlePlugin: '$want'" "$cfg"; then
  echo "patch_android_template: AGP already $want"
else
  if ! grep -q "androidGradlePlugin: '8.6.1'" "$cfg"; then
    echo "patch_android_template: expected androidGradlePlugin: '8.6.1' in $cfg, found:" >&2
    grep -n "androidGradlePlugin" "$cfg" >&2 || echo "  (no androidGradlePlugin line)" >&2
    exit 1
  fi
  perl -pi -e "s/androidGradlePlugin: '8\.6\.1'/androidGradlePlugin: '$want'/" "$cfg"
  grep -q "androidGradlePlugin: '$want'" "$cfg"
  echo "patch_android_template: AGP 8.6.1 -> $want"
fi

# 2. The friend link's alias, after the launcher's.
[[ -f "$manifest" ]] || { echo "patch_android_template: $manifest not found" >&2; exit 1; }
if grep -q 'android:name="\.FriendLink"' "$manifest"; then
  echo "patch_android_template: FriendLink alias already there"
else
  # The template as 4.7 ships it: one .GodotApp activity and one alias,
  # .GodotAppLauncher, whose closing tag is the only </activity-alias>.
  if ! grep -q 'android:name="\.GodotApp"' "$manifest" \
      || ! grep -q 'android:name="\.GodotAppLauncher"' "$manifest" \
      || [[ "$(grep -c '</activity-alias>' "$manifest")" != "1" ]]; then
    echo "patch_android_template: expected one .GodotApp activity and one .GodotAppLauncher alias in $manifest, found:" >&2
    grep -n '<activity\|</activity-alias>\|android:name="\.' "$manifest" >&2 || echo "  (no activity at all)" >&2
    exit 1
  fi
  ALIAS='        <activity-alias
            android:name=".FriendLink"
            android:targetActivity=".GodotApp"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="peepletdaily" android:host="f" />
            </intent-filter>
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="daily-games-420bf.web.app" android:pathPrefix="/f/" />
            </intent-filter>
        </activity-alias>' perl -0pi -e 's{(</activity-alias>[ \t]*\n)}{$1$ENV{ALIAS}\n}' "$manifest"
  grep -q 'android:name="\.FriendLink"' "$manifest"
  echo "patch_android_template: FriendLink alias added"
fi

# Firebase (addons/godotx_firebase): the Google Services plugin turns
# google-services.json (the export copies it in from the project root) into
# the app's Firebase resources, and the Crashlytics plugin stamps the build id
# Crashlytics refuses to start without. Versions are the addon's.
settings=android/build/settings.gradle
app_gradle=android/build/build.gradle
[[ -f "$settings" && -f "$app_gradle" ]] || { echo "patch_android_template: $settings or $app_gradle not found" >&2; exit 1; }
if grep -q "com.google.gms.google-services" "$settings"; then
  echo "patch_android_template: Firebase plugin versions already there"
else
  if ! grep -q "id 'org.jetbrains.kotlin.android' version versions.kotlinVersion" "$settings"; then
    echo "patch_android_template: expected the kotlin plugin line in $settings's pluginManagement" >&2
    exit 1
  fi
  perl -pi -e "s{^(\s*)(id 'org\.jetbrains\.kotlin\.android' version versions\.kotlinVersion)\s*\$}{\$1\$2\n\$1id 'com.google.gms.google-services' version '4.4.4'\n\$1id 'com.google.firebase.crashlytics' version '3.0.6'\n}" "$settings"
  grep -q "com.google.firebase.crashlytics" "$settings"
  echo "patch_android_template: Firebase plugin versions added"
fi
if grep -q "id 'com.google.gms.google-services'" "$app_gradle"; then
  echo "patch_android_template: Firebase plugins already applied"
else
  if [[ "$(grep -c "^    id 'org.jetbrains.kotlin.android'\$" "$app_gradle")" != "1" ]]; then
    echo "patch_android_template: expected one kotlin plugin id in $app_gradle's plugins block" >&2
    exit 1
  fi
  perl -pi -e "s{^(    id 'org\.jetbrains\.kotlin\.android')\$}{\$1\n    id 'com.google.gms.google-services'\n    id 'com.google.firebase.crashlytics'}" "$app_gradle"
  grep -q "id 'com.google.firebase.crashlytics'" "$app_gradle"
  echo "patch_android_template: Firebase plugins applied"
fi

# 4. R8 on the release build (2026-10-28; Play's "DEX code optimization: Low"
# and "obfuscation 8%" rows). minify + shrinkResources, with the optimize
# variant of AGP's default rules (the plain proguard-android.txt carries
# -dontoptimize, which leaves Play's optimization row a dash). The keep rules
# Godot needs (org.godotengine.**, every GodotPlugin, JNI natives) are written
# into proguard-rules.pro by the AdMob addon's exporter on every release
# export, when project.godot has admob/general/android/enable_r8_optimization
# on; that addon also prepends a com.android.tools:r8:8.8.27 classpath pin to
# build.gradle, older than AGP 8.9.1's own R8 -- harmless, and not ours.
# Debug exports (Firebase App Distribution) are untouched.
if grep -q "minifyEnabled true" "$app_gradle"; then
  echo "patch_android_template: R8 already on for release"
else
  # Two 'release {' blocks: signingConfigs' and buildTypes'. The build type's
  # is the one followed by "signingConfig signingConfigs.release".
  if [[ "$(perl -0ne 'my @m = /        release \{\n(?:.*\n){0,6}?.*signingConfig signingConfigs\.release/g; print scalar @m' "$app_gradle")" != "1" ]]; then
    echo "patch_android_template: expected one release build type (release { ... signingConfig signingConfigs.release) in $app_gradle, found:" >&2
    grep -n 'release {\|signingConfigs.release' "$app_gradle" >&2 || echo "  (none)" >&2
    exit 1
  fi
  perl -0pi -e 's{(        release \{\n)((?:.*\n){0,6}?.*signingConfig signingConfigs\.release)}{$1            minifyEnabled true\n            shrinkResources true\n            proguardFiles getDefaultProguardFile(\x27proguard-android-optimize.txt\x27), \x27proguard-rules.pro\x27\n$2}' "$app_gradle"
  grep -q "minifyEnabled true" "$app_gradle"
  echo "patch_android_template: R8 on for release"
fi
# Our own rules go in proguard-rules.pro ahead of the addon's: line numbers
# and source names, which AGP's optimize file drops, so a Crashlytics trace
# retraces to a line and not just a method.
rules=android/build/proguard-rules.pro
if [[ -f "$rules" ]] && grep -q "LineNumberTable" "$rules"; then
  echo "patch_android_template: proguard-rules.pro already keeps line numbers"
else
  printf '%s\n' "# Keep line numbers and source names for Crashlytics retrace (tools/patch_android_template.sh)." "-keepattributes SourceFile,LineNumberTable" "-renamesourcefileattribute SourceFile" >> "$rules"
  echo "patch_android_template: proguard-rules.pro keeps line numbers"
fi
