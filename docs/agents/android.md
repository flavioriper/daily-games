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
