# iOS / iPhone — Setup & Run

> **Deferred.** We are testing **Android first**. iOS is documented here so it's
> ready, but you don't need any of this to develop the Android build.

## Hard requirement: a Mac

iOS apps **can only be built and signed on macOS with Xcode**. You cannot build
the iPhone version from Windows or WSL. When you're ready for iOS, clone this
repo onto a Mac and follow the steps below there.

| Need | Notes |
|---|---|
| A **Mac** | with macOS current enough for the latest Xcode |
| **Xcode** + Command Line Tools | `xcode-select --install` |
| **CocoaPods** | `sudo gem install cocoapods` |
| Flutter SDK (macOS) | install per https://docs.flutter.dev |
| **Apple Developer account** (paid, $99/yr) | HealthKit apps **cannot** ship on a free account (doc §3.1) |
| **Physical iPhone** | step sensors don't exist in the simulator |

---

## Setup steps (on the Mac)

```bash
git clone <your-repo> the-walk-culture
cd the-walk-culture
flutter pub get
cd ios && pod install && cd ..
```

Then configure the native project (doc §3.3):

1. **Info.plist** — merge
   [`../platform_config/Info.plist.additions.xml`](../platform_config/Info.plist.additions.xml)
   into `ios/Runner/Info.plist` (health + motion usage strings).
2. **HealthKit capability** — open `ios/Runner.xcworkspace` in Xcode → **Runner**
   target → **Signing & Capabilities** → **+ Capability** → **HealthKit**.
3. **Signing** — select your Team; set a unique Bundle Identifier
   (e.g. `com.perfeos.stepQuest`).
4. **Deployment target** — set iOS **13.0+** (Podfile `platform :ios, '13.0'`
   and the Xcode target).

> Keep the **location** usage string commented out until the TURBO route
> feature (Phase 4). Passive steps need only Health + Motion.

---

## Run on a physical iPhone

```bash
flutter devices                 # iPhone should appear once plugged in & trusted
flutter run -d <iphone-id>
flutter build ipa               # archive for TestFlight / App Store
```

On first launch, unlock the device — **HealthKit refuses to read while the
device is locked** (doc §3.3). On the iPhone: Settings → General → VPN & Device
Management → trust your developer certificate.

---

## iOS gotchas (doc §3.3)

- iOS **won't tell you whether READ permission was granted** — infer it by
  attempting a read and handling an empty result. `HealthService.getTodaySteps()`
  already returns `null` gracefully in that case.
- The device must be **unlocked** to read HealthKit data.
- App Store review rejects health apps **without clear usage strings** and
  **without a published privacy policy** (doc §9) — have both ready before
  submitting.

---

## App Store pre-submission (doc §3.7, §9)

- [ ] HealthKit capability enabled; all Info.plist usage strings present
- [ ] Privacy policy published + linked
- [ ] App Store **Privacy labels** filled accurately (health data: not used for
      tracking, not sold, not shared with ad/analytics SDKs)
- [ ] Tested on a physical iPhone
