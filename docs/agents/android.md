<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Playing on an Android phone

The game ships as a native APK through Firebase App Distribution (project
`daily-games-420bf`, package `com.peeplet.daily`). Run `tools/deploy_android.sh`
to export and distribute; the build lands in the Firebase App Tester app on
the phone. Nothing deploys on push.

The export is the Gradle path (`use_gradle_build=true`, since
`feat/gradle-export`), arm64-v8a only, debug-signed. Machine-local setup it
depends on: the Android SDK at
`/opt/homebrew/share/android-commandlinetools` and `~/.android/debug.keystore`,
both wired into Godot's editor settings, plus the 4.7 Android export
templates. `build/` is ignored -- it is output.

## What `tools/patch_android_template.sh` does to the template

`android/` is not in git: the script unpacks the engine's own
`android_source.zip` when it is missing, then patches it. Four patches, each
skipped when already there, all run on every call (2026-10-04; before, the
script left as soon as the first was found done):

1. the Android Gradle plugin, 8.6.1 to 8.9.1, for godot-iap;
2. the friend link's `.FriendLink` activity-alias in
   `android/build/src/main/AndroidManifest.xml` (`docs/agents/friends.md`,
   "The link");
3. the Firebase Gradle plugins (google-services, crashlytics) for
   `addons/godotx_firebase`;
4. R8 on the release build type (2026-10-28): `minifyEnabled true`,
   `shrinkResources true`, AGP's `proguard-android-optimize.txt` plus
   `android/build/proguard-rules.pro`, which the script seeds with
   `-keepattributes SourceFile,LineNumberTable` (the optimize file drops
   them; without them a Crashlytics trace retraces to a method, not a
   line). Debug exports are untouched.

## R8 on the Play build

Play's bundle page showed "DEX code optimization: Low" and "obfuscation 8%"
for every AAB up to 1980: the template's release build ran no R8 at all, and
the 8% was what Firebase and the ads SDK ship pre-obfuscated (23.7 MB of
unshrunk DEX). Patch 4 above turns it on. The keep rules Godot needs
(`org.godotengine.**` whole, every `GodotPlugin` subclass, JNI natives,
activities) come from the AdMob addon's exporter
(`addons/admob/internal/exporters/android/export_plugin.gd`,
`_patch_android_r8`), which writes them into `proguard-rules.pro` on every
`--export-release` because `project.godot` has
`admob/general/android/enable_r8_optimization=true`. Turn that off and a
minified build crashes at launch with no plugins. The addon also prepends a
`com.android.tools:r8:8.8.27` classpath pin to `build.gradle`, older than
AGP 8.9.1's own R8; harmless, and not ours.

The optimize variant matters: AGP's plain `proguard-android.txt` carries
`-dontoptimize`, which keeps Play's optimization row a dash. Obfuscation
never reaches the 90s because Godot's own classes are kept whole; the gain
is AndroidX, Kotlin, Firebase, openiap and the ads SDK shrinking. The
Crashlytics Gradle plugin uploads the mapping file on its own
(`uploadCrashlyticsMappingFileRelease` in the build log), so traces stay
readable. `shrinkResources` is the one new risk: a missing splash or icon
on first launch is its symptom.

A manifest change belongs in that script, never by hand in `android/build`:
a fresh checkout and CI install the template anew. To see what a build's
manifest really holds after Gradle's merge:

    /opt/homebrew/share/android-commandlinetools/build-tools/<ver>/aapt2 dump xmltree --file AndroidManifest.xml <apk>

and `apksigner verify --print-certs <apk>` beside it names the certificate
the build was signed with -- the one
`server/site/.well-known/assetlinks.json` has to list for an https friend
link to open the game without asking.
