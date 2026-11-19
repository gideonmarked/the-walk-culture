# iOS / iPhone — Setup, Build & App Store

Everything the app needs on iOS is in the code: HealthKit steps, StoreKit 2
purchases verified by the server, AdMob, Sign in with Apple, optional Google
sign-in, account deletion, and Restore Purchases. What's left is account setup
that only you can do (below), and testing on a real iPhone.

## Requirements

| Need | Notes |
|---|---|
| A Mac with **Xcode 27+** | Run `sudo xcodebuild -license accept` and `sudo xcodebuild -runFirstLaunch` once |
| **CocoaPods** | `brew install cocoapods`; set `export LANG=en_US.UTF-8` in `~/.zshrc` |
| Flutter **3.44.6** | `~/flutter/bin` on your PATH |
| **Apple Developer Program** ($99/yr) | HealthKit, Sign in with Apple and in-app purchases all need it |
| **Disk space** | ~15 GB free for Xcode builds and a simulator |
| A **physical iPhone** for real testing | The simulator has no step sensor or Health data |

**Minimum iOS: 15.0.** Xcode 27 can't build for anything older, and the
`health` plugin needs 14+. The Podfile lifts every plugin to 15.

## One-time setup

### 1. Signing and capabilities (Xcode)
Open `ios/Runner.xcworkspace` → **Runner** target → **Signing & Capabilities**:
- **Team:** your developer team. **Bundle Identifier:** `com.perfeos.stepQuest`.
- Capabilities already declared in `Runner.entitlements`: **HealthKit** and
  **Sign in with Apple**. Xcode registers them on your App ID the first time
  you sign; if it doesn't, enable both on the App ID at
  developer.apple.com → Identifiers.
- Add **In-App Purchase** if Xcode lists it as missing.

### 2. `ios/Flutter/AppConfig.xcconfig`
| Setting | Value |
|---|---|
| `ADMOB_IOS_APP_ID` | Your iOS app's AdMob **app** ID (AdMob → Apps → add an iOS app). Defaults to Google's test ID |
| `GOOGLE_REVERSED_CLIENT_ID` | The **reversed** iOS OAuth client ID, e.g. `com.googleusercontent.apps.1234-abcd`, only if you offer Google sign-in on iOS |

Never put a URL in this file: `//` starts a comment in `.xcconfig`.

### 3. App Store Connect
1. Create the app with bundle ID `com.perfeos.stepQuest`.
2. **In-app purchases**, with the same product IDs as Android
   (`lib/core/premium.dart`):
   - Consumables: `com.perfeos.step_quest.currency.pouch` / `.sack` / `.chest` / `.vault`
   - One subscription group "VIP" with auto-renewable subscriptions
     `com.perfeos.step_quest.vip.weekly` / `.monthly` / `.annual`
3. **Users and Access → Integrations → In-App Purchase** → generate a key.
   Download the `.p8` (only possible once) and note the **Key ID** and
   **Issuer ID**.
4. Give those to the purchase-check function and redeploy it:

   ```bash
   supabase secrets set APPLE_IAP_KEY_ID=ABC123DEFG APPLE_IAP_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   supabase secrets set APPLE_IAP_PRIVATE_KEY="$(cat SubscriptionKey_ABC123DEFG.p8)"
   supabase secrets set APPLE_BUNDLE_ID=com.perfeos.stepQuest
   supabase functions deploy validate-purchase
   ```

   The app sends each StoreKit 2 transaction ID to `validate-purchase`, which
   looks it up with Apple's App Store Server API (production first, then
   sandbox for TestFlight) before granting anything. Without these secrets,
   iOS purchases stay pending and are retried; they are never granted
   unverified.

### 4. Sign in with Apple (Supabase)
**Authentication → Providers → Apple** → enable, and add
`com.perfeos.stepQuest` under **Client IDs**. The native iOS flow needs no
secret key. **Allow manual linking** must be on (it already is if Google
linking works).

### 5. Google sign-in on iOS (optional)
Google Cloud Console → Credentials → **Create OAuth client ID → iOS**, bundle
ID `com.perfeos.stepQuest`. Then:
- put its reversed ID in `AppConfig.xcconfig` (step 2),
- add the iOS client ID to Supabase's Google provider **Authorized Client IDs**,
- build with `--dart-define=GOOGLE_IOS_CLIENT_ID=<iOS client id>` as well as
  `GOOGLE_WEB_CLIENT_ID`.

Sign in with Apple is always offered on iOS. App Review guideline 4.8 requires
it whenever another social login is offered.

### 6. AdMob iOS rewarded unit
AdMob → the iOS app → **Ad units → Rewarded**, then build with
`--dart-define=ADMOB_IOS_REWARDED_UNIT=ca-app-pub-XXXX/YYYY` together with
`REAL_ADS=true`. Without it, iOS serves Google's test ads.

## Build and run

```bash
flutter run -d <simulator or iPhone id> \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=REAL_ADS=true --dart-define=ADMOB_IOS_REWARDED_UNIT=... \
  --dart-define=GOOGLE_WEB_CLIENT_ID=... --dart-define=GOOGLE_IOS_CLIENT_ID=...
```

Upload the `.ipa` with Xcode's Organizer or the Transporter app.

> **Known tool bug (Flutter 3.44 + Xcode 27):** `flutter build ios --simulator`
> fails with *"does not contain architectures arm64 x86_64"*: Xcode 27's `lipo`
> no longer accepts two architectures in one check. Use `flutter run -d
> <simulator>` instead, which builds only for your Mac's chip. Device and
> App Store builds (arm64 only) are not affected.

## iOS behaviour to know

- iOS **never says whether Health read access was granted**. A denied
  permission looks like zero steps; `HealthService.getTodaySteps()` handles it.
- HealthKit can't be read while the phone is **locked**.
- Restore: StoreKit 2 restore reads the device's current entitlements, so it
  never prompts for an Apple ID password.

## App Store submission checklist

- [ ] HealthKit and Sign in with Apple enabled on the App ID; usage strings
      present (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`,
      `NSMotionUsageDescription`)
- [ ] Privacy policy URL: `https://gideonmarked.github.io/the-walk-culture/privacy.html`
- [ ] **App Privacy** labels: Health & Fitness (steps; app functionality; not
      linked to tracking), Email (only if the player links an account), User
      ID, Purchases, User Content (prayer requests, usernames), Diagnostics
      (crash reports), Device ID (AdMob)
- [ ] Account deletion in the app (Settings → Delete account) ✅
- [ ] Restore Purchases button (Store → VIP) ✅
- [ ] Subscription terms next to the buy buttons, with Terms and Privacy links ✅
      Also add the Terms of Use (EULA) link to the App Store description
- [ ] Sign in with Apple offered alongside Google ✅
- [ ] **Open item: revoking Apple tokens on account deletion.** Guideline
      5.1.1(v) expects apps with Sign in with Apple to revoke the user's Apple
      tokens (Apple's `/auth/revoke` REST API) when they delete their account.
      Today deletion removes all our data but doesn't call Apple. It needs the
      authorization code from sign-in plus a Sign in with Apple key on the
      server; not built yet.
- [ ] Review notes: "No login required; the app creates an anonymous account.
      Steps come from Apple Health; with no Health data the wallet starts near
      zero but every screen opens."
- [ ] Tested on a physical iPhone
