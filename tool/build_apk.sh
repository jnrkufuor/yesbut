#!/usr/bin/env bash
# One command: ./tool/build_apk.sh  → build/app/outputs/flutter-apk/app-release.apk
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "Flutter isn't installed. See README → Build on your Mac."; exit 1; }
./tool/setup_platforms.sh
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ./YesBut.apk
echo "✔ Done: $(pwd)/YesBut.apk"
