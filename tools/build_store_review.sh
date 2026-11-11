#!/bin/bash
# Builds the store rating sheet plugin (native/store_review) into addons/store_review.
# Android: both AARs with the plugin's gradle wrapper, against android/build's godot-lib.
# core/review.gd decides when it asks.
# iOS: debug and release xcframeworks (device + simulator) into ios/plugins/store_review,
# compiled against ~/dev/godot-4.7-src with the defines its iOS templates use.
# `--ios` builds only iOS, `--android` only Android; nothing builds both.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
want_android=1; want_ios=1
case "${1:-}" in
  --ios) want_android=0 ;;
  --android) want_ios=0 ;;
esac

if [ $want_ios = 1 ]; then
  G="${GODOT_SRC:-$HOME/dev/godot-4.7-src}"
  test -f "$G/core/object/object.h" || { echo "no Godot source at $G (GODOT_SRC)"; exit 1; }
  OUT="$ROOT/ios/plugins/store_review"
  TMP="$(mktemp -d)"
  mkdir -p "$OUT"
  for cfg in debug release; do
    defs="-DIOS_ENABLED -DAPPLE_EMBEDDED_ENABLED -DUNIX_ENABLED -DTHREADS_ENABLED"
    if [ $cfg = debug ]; then defs="$defs -DDEBUG_ENABLED"; else defs="$defs -DNDEBUG"; fi
    args=()
    for sdk in iphoneos iphonesimulator; do
      mkdir -p "$TMP/$cfg/$sdk"
      if [ $sdk = iphoneos ]; then min=-miphoneos-version-min=14.0; else min=-mios-simulator-version-min=14.0; fi
      # Godot's simulator template is x86_64 (and arm64 on newer ones): give the simulator both
      if [ $sdk = iphoneos ]; then archs="arm64"; else archs="arm64 x86_64"; fi
      objs=()
      for arch in $archs; do
        xcrun -sdk $sdk clang++ -c native/store_review/ios/store_review.mm -o "$TMP/$cfg/$sdk/store_review.$arch.o" \
          -arch $arch -isysroot "$(xcrun --sdk $sdk --show-sdk-path)" $min -std=gnu++17 -fobjc-arc -fno-exceptions \
          -fvisibility=hidden -O2 -I"$G" -I"$G/platform/ios" $defs
        objs+=("$TMP/$cfg/$sdk/store_review.$arch.o")
      done
      xcrun -sdk $sdk libtool -static -o "$TMP/$cfg/$sdk/libstore_review.a" "${objs[@]}"
      args+=(-library "$TMP/$cfg/$sdk/libstore_review.a")
    done
    rm -rf "$OUT/StoreReview.$cfg.xcframework"
    xcodebuild -create-xcframework "${args[@]}" -output "$OUT/StoreReview.$cfg.xcframework" > /dev/null
  done
  rm -rf "$TMP"
  echo "built ios/plugins/store_review/StoreReview.{debug,release}.xcframework"
fi
[ $want_android = 1 ] || exit 0
# the SDK Godot exports with; this Mac's ANDROID_HOME names an empty folder
for d in "${ANDROID_HOME:-}" /opt/homebrew/share/android-commandlinetools "$HOME/Library/Android/sdk"; do
  if [ -n "$d" ] && [ -d "$d/platforms" ]; then export ANDROID_HOME="$d"; break; fi
done
test -f android/build/libs/release/godot-lib.template_release.aar || { echo "android/build is missing: run tools/patch_android_template.sh"; exit 1; }
cd native/store_review/android
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew -q assembleDebug assembleRelease
mkdir -p "$ROOT/addons/store_review/android"
cp build/outputs/aar/store_review-debug.aar "$ROOT/addons/store_review/android/store_review.debug.aar"
cp build/outputs/aar/store_review-release.aar "$ROOT/addons/store_review/android/store_review.release.aar"
echo "built addons/store_review/android/store_review.{debug,release}.aar"
