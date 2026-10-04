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
`android_source.zip` when it is missing, then patches it. Two patches, each
skipped when already there, both run on every call (2026-10-04; before, the
script left as soon as the first was found done):

1. the Android Gradle plugin, 8.6.1 to 8.9.1, for godot-iap;
2. the friend link's `.FriendLink` activity-alias in
   `android/build/src/main/AndroidManifest.xml` (`docs/agents/friends.md`,
   "The link").

A manifest change belongs in that script, never by hand in `android/build`:
a fresh checkout and CI install the template anew. To see what a build's
manifest really holds after Gradle's merge:

    /opt/homebrew/share/android-commandlinetools/build-tools/<ver>/aapt2 dump xmltree --file AndroidManifest.xml <apk>

and `apksigner verify --print-certs <apk>` beside it names the certificate
the build was signed with -- the one
`server/site/.well-known/assetlinks.json` has to list for an https friend
link to open the game without asking.
