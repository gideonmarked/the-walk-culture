# Android — Setup & Run

**Android is the primary/first test target.** This project's Flutter SDK lives
inside the **WSL "Ubuntu" distro** (`~/flutter`), and the project is at
`~/Projects/the-walk-culture`. These instructions assume that layout.

> Design references: manifest/permissions in
> [`../StepGame_Plan_and_Documentation.md`](../StepGame_Plan_and_Documentation.md)
> §3.4, and the ready-to-merge snippets in
> [`../platform_config/`](../platform_config/).

---

## 1. Prerequisites

| Need | Notes |
|---|---|
| Flutter SDK (in WSL) | already installed at `~/flutter`; ensure `~/flutter/bin` is on `PATH` |
| **JDK 17** | `sudo apt install openjdk-17-jdk` (or a no-sudo tarball — see §2) |
| **Android SDK** (cmdline-tools) | installed headless into WSL — see §2 |
| **Physical Android device** | step sensors do **not** exist on emulators — you must use real hardware |
| **Health Connect app** on the device | the data store the `health` plugin reads (Play Store on Android 8–13; built-in on 14+) |

Add Flutter to your shell permanently (`~/.bashrc`):
```bash
export PATH="$HOME/flutter/bin:$PATH"
```

---

## 2. Install the Android SDK inside WSL (headless, no Android Studio)

```bash
# 1) JDK 17
sudo apt update && sudo apt install -y openjdk-17-jdk
#    (no sudo? download a JDK 17 tarball, unpack to ~/jdk17, and
#     export JAVA_HOME="$HOME/jdk17" ; export PATH="$JAVA_HOME/bin:$PATH")

# 2) Android command-line tools
mkdir -p ~/Android/sdk/cmdline-tools
cd ~/Android/sdk/cmdline-tools
curl -O https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-*.zip
mv cmdline-tools latest        # final path: ~/Android/sdk/cmdline-tools/latest

# 3) Environment (add to ~/.bashrc)
export ANDROID_HOME="$HOME/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# 4) SDK packages + licenses  (Flutter 3.44.x needs API 36)
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
yes | sdkmanager --licenses

# 5) Point Flutter at the SDK and verify
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor -v
```

`flutter doctor` should show a green check for "Android toolchain". Ignore the
Android Studio / Chrome / Linux-desktop lines — not needed for device builds.

---

## 3. Connect a physical device from WSL

WSL can't see USB by default. **Wireless debugging is the easy path** (Android 11+):

```bash
# On the phone: Settings → Developer options → Wireless debugging → ON
#   → "Pair device with pairing code"  (shows an IP:PORT and a 6-digit code)
adb pair 192.168.x.x:PORT       # enter the pairing code
#   Then use the main IP:PORT shown on the Wireless debugging screen:
adb connect 192.168.x.x:PORT
flutter devices                 # your phone should appear
```

<details>
<summary>Alternative: USB passthrough with usbipd-win</summary>

In **Windows PowerShell (admin):**
```powershell
winget install usbipd
usbipd list                      # find the phone's BUSID
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```
Then in WSL `adb devices` should list it. Re-attach after replug.
</details>

---

## 4. One-time project config (after `flutter create`)

The bootstrap script (`setup.sh`) generates `android/`. Then merge the design's
required config (doc §3.4):

1. `android/app/src/main/AndroidManifest.xml` ← merge
   [`../platform_config/AndroidManifest.additions.xml`](../platform_config/AndroidManifest.additions.xml)
   (queries, health permissions, activity-alias, rationale intent-filter).
2. `MainActivity.kt` must extend `FlutterFragmentActivity` — the script copies
   [`../platform_config/MainActivity.kt`](../platform_config/MainActivity.kt) into place.
3. Apply [`../platform_config/build.gradle.notes.md`](../platform_config/build.gradle.notes.md):
   `minSdk 26`, `compileSdk`/`targetSdk` 34, AndroidX + Jetifier.

> The **location/foreground-service** permissions stay commented out — they
> belong to the TURBO release (Phase 4), not this Android-first build.

---

## 5. Run & build

```bash
flutter pub get
flutter devices                       # confirm the phone is listed
flutter run -d <device-id>            # debug run on the phone

flutter build apk --debug             # installable debug APK
flutter build apk --release           # release APK
flutter build appbundle --release     # Play Store .aab
```

Hot reload: press `r` in the `flutter run` console; hot restart: `R`.

---

## 6. Granting Health Connect data on the device

1. Install **Health Connect** (Play Store) if not present; open it once.
2. First app launch → the onboarding screen explains, then requests
   Activity Recognition + Health Connect **steps** read access (doc §3.6).
3. To generate test steps without walking: walk with the phone, or add step
   data via another connected app, **or** use the in-app **+500 steps
   (simulate)** button (works even with no health permission).

See [`TESTING.md`](TESTING.md) for the full device test plan.

---

## 7. Common issues

| Symptom | Fix |
|---|---|
| `flutter devices` empty | re-run `adb connect ip:port`; confirm phone + PC on same network |
| "Health Connect not installed" | install it from the Play Store, open once |
| Steps always 0 | grant Activity Recognition + Health Connect steps; ensure the device has recorded steps today |
| Gradle/Java errors | confirm JDK **17** (`java -version`), `minSdk 26` applied |
| `adb` not found | ensure `$ANDROID_HOME/platform-tools` is on `PATH` |
