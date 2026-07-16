# Bootstrap the native Flutter scaffolding around the authored source.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File setup.ps1
$ErrorActionPreference = 'Stop'

$Org  = 'com.perfeos'
$Name = 'step_quest'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host 'ERROR: Flutter SDK not found on PATH.'
  Write-Host 'Install it (https://docs.flutter.dev/get-started/install), then re-run.'
  exit 1
}

Write-Host "==> Flutter found:"
flutter --version | Select-Object -First 1

# Back up authored source so 'flutter create' can't clobber it.
$Bak = '.sq_backup'
if (Test-Path $Bak) { Remove-Item -Recurse -Force $Bak }
New-Item -ItemType Directory -Path $Bak | Out-Null
foreach ($p in 'lib','pubspec.yaml','analysis_options.yaml','test') {
  if (Test-Path $p) { Copy-Item -Recurse -Force $p $Bak }
}

Write-Host '==> Generating native scaffolding (android, ios)...'
flutter create --org $Org --project-name $Name --platforms=android,ios .

Write-Host '==> Restoring authored source...'
foreach ($p in 'lib','pubspec.yaml','analysis_options.yaml','test') {
  $src = Join-Path $Bak $p
  if (Test-Path $src) { Copy-Item -Recurse -Force $src '.' }
}
Remove-Item -Recurse -Force $Bak

$KotlinDir = 'android/app/src/main/kotlin/com/perfeos/step_quest'
if (Test-Path 'android') {
  New-Item -ItemType Directory -Force -Path $KotlinDir | Out-Null
  Copy-Item -Force 'platform_config/MainActivity.kt' (Join-Path $KotlinDir 'MainActivity.kt')
  Write-Host '==> Installed MainActivity.kt (FlutterFragmentActivity).'
}

Write-Host '==> flutter pub get...'
flutter pub get

Write-Host @'

Done with the automated part. Two MANUAL merges remain (one-time):
  1. android/app/src/main/AndroidManifest.xml
       <- merge platform_config/AndroidManifest.additions.xml
  2. ios/Runner/Info.plist
       <- merge platform_config/Info.plist.additions.xml
       + enable HealthKit capability in Xcode, set iOS target 13.0+
  3. Apply platform_config/build.gradle.notes.md (minSdk 26, AndroidX/Jetifier)

Then run on a PHYSICAL device (sensors do not exist on simulators):
  flutter run
'@
