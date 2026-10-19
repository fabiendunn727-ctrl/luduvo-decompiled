#!/bin/sh
# Builds the Luduvo Android client with nothing but the Android SDK
# build-tools and platform (aapt2 / javac / d8 / zipalign / apksigner).
#
# The Gradle project in this directory needs the full SDK + NDK, which is a
# much heavier toolchain. This script produces the same APK from the plain
# SDK and is what CI uses.
#
#   SDK_DIR=/path/to/android-sdk ./build.sh [output.apk]
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
SDK_DIR=${SDK_DIR:-/tmp/opencode/androidsdk}
BT=$SDK_DIR/android-14
AJ=$SDK_DIR/android-34/android.jar
OUT=${OUT:-$HERE/build}

if [ ! -x "$BT/aapt2" ] || [ ! -f "$AJ" ]; then
    echo "Android SDK not usable: expected $BT/aapt2 and $AJ" >&2
    echo "Set SDK_DIR to an SDK with build-tools r34 and platform 34." >&2
    exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT/dex" "$OUT/classes"

cd "$HERE"

"$BT/aapt2" compile --dir app/src/main/res -o "$OUT/res.zip"
"$BT/aapt2" link -o "$OUT/base.apk" -I "$AJ" --manifest app/src/main/AndroidManifest.xml \
    --min-sdk-version 24 --target-sdk-version 34 \
    --auto-add-overlay -A "$HERE/app/src/main/assets" \
    "$OUT/res.zip"

find app/src/main/java -name "*.java" > "$OUT/sources.txt"
javac -source 17 -target 17 -classpath "$AJ" -d "$OUT/classes" @"$OUT/sources.txt"

"$BT/d8" --release --min-api 24 --lib "$AJ" --output "$OUT/dex" \
    $(find "$OUT/classes" -name "*.class")

cd "$OUT/dex"
zip -q -j "$OUT/base.apk" classes.dex
cd "$HERE"

"$BT/zipalign" -f -p 4 "$OUT/base.apk" "$OUT/aligned.apk"

KS="$OUT/ks.jks"
if [ ! -f "$KS" ]; then
    keytool -genkeypair -keystore "$KS" -storepass buildoverse -keypass buildoverse \
        -alias buildoverse -keyalg RSA -keysize 2048 -validity 10950 \
        -dname "CN=Luduvo, O=Luduvo, C=US" -storetype JKS >/dev/null 2>&1
fi

"$BT/apksigner" sign --ks "$KS" --ks-pass pass:buildoverse --key-pass pass:buildoverse \
    --out "$OUT/luduvo.apk" "$OUT/aligned.apk"
"$BT/apksigner" verify "$OUT/luduvo.apk" && echo "APK_SIGNED_OK"
ls -la "$OUT/luduvo.apk"
