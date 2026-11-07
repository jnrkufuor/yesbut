#!/usr/bin/env bash
# Generates the native Android/iOS shells (matched to your Flutter version)
# and applies YesBut's Android customizations on top.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f android/app/src/main/AndroidManifest.xml ]; then
  echo "▶ Generating native platform folders…"
  flutter create --org com.yesbutapp --project-name yesbut --platforms=android,ios . >/dev/null
fi

echo "▶ Applying YesBut Android overlay (name, icon, permissions)…"
cp -R platform_overlay/android/. android/

# Release shrinking: make sure our ProGuard rules are picked up.
GRADLE_KTS=android/app/build.gradle.kts
GRADLE_GROOVY=android/app/build.gradle
if [ -f "$GRADLE_KTS" ] && ! grep -q "proguard-rules.pro" "$GRADLE_KTS"; then
  perl -0pi -e 's/(buildTypes\s*\{\s*release\s*\{)/$1\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")/' "$GRADLE_KTS"
elif [ -f "$GRADLE_GROOVY" ] && ! grep -q "proguard-rules.pro" "$GRADLE_GROOVY"; then
  perl -0pi -e "s/(buildTypes\s*\{\s*release\s*\{)/\$1\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'/" "$GRADLE_GROOVY"
fi

flutter pub get
echo "✔ Platforms ready."
