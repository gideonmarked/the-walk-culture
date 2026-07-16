#!/usr/bin/env bash
# Bootstrap the native Flutter scaffolding around the authored source.
# Run from the project root:  bash setup.sh
set -euo pipefail

ORG="com.perfeos"
NAME="step_quest"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: Flutter SDK not found on PATH."
  echo "Install it (https://docs.flutter.dev/get-started/install), then re-run."
  exit 1
fi

echo "==> Flutter found: $(flutter --version | head -1)"

# Back up authored source so 'flutter create' can't clobber it.
BAK=".sq_backup"
rm -rf "$BAK"; mkdir -p "$BAK"
for p in lib pubspec.yaml analysis_options.yaml test; do
  [ -e "$p" ] && cp -r "$p" "$BAK"/ || true
done

echo "==> Generating native scaffolding (android, ios)…"
flutter create --org "$ORG" --project-name "$NAME" --platforms=android,ios .

# Restore authored source over the generated template.
echo "==> Restoring authored source…"
for p in lib pubspec.yaml analysis_options.yaml test; do
  [ -e "$BAK/$p" ] && cp -r "$BAK/$p" ./ || true
done
rm -rf "$BAK"

# Drop in the FlutterFragmentActivity MainActivity.
KOTLIN_DIR="android/app/src/main/kotlin/com/perfeos/step_quest"
if [ -d "android" ]; then
  mkdir -p "$KOTLIN_DIR"
  cp platform_config/MainActivity.kt "$KOTLIN_DIR/MainActivity.kt"
  echo "==> Installed MainActivity.kt (FlutterFragmentActivity)."
fi

echo "==> flutter pub get…"
flutter pub get

cat <<'EOF'

Done with the automated part. Two MANUAL merges remain (one-time):
  1. android/app/src/main/AndroidManifest.xml
       ← merge platform_config/AndroidManifest.additions.xml
  2. ios/Runner/Info.plist
       ← merge platform_config/Info.plist.additions.xml
       + enable HealthKit capability in Xcode, set iOS target 13.0+
  3. Apply platform_config/build.gradle.notes.md (minSdk 26, AndroidX/Jetifier)

Then run on a PHYSICAL device (sensors don't exist on simulators):
  flutter run
EOF
