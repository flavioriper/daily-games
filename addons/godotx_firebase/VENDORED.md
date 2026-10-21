Vendored from https://github.com/godot-x/firebase at 4cbe0806510024617b096893060ddea5ddc077fe (MIT).

Peeplet changes, all in export_plugin.gd and marked "Peeplet":
- the Android AARs live in addons/godotx_firebase/android/<module>/ (the repo
  ignores /android/), built from that commit with `make build-android`;
- firebase-crashlytics-ndk rides with Crashlytics.

The iOS plugins (ios/plugins/firebase_{core,analytics,crashlytics}, ~135 MB of
Firebase 12.16.0 frameworks) are not in git: rebuild them from that commit with
`make build-godot-headers setup-sdk build-apple` and copy ios/plugins/firebase_*
over. Messaging is not used.
