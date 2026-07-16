# StepQuest — Plan & Technical Documentation (Flutter Edition)
*A walking-powered life sim: turn real-world steps into currency, spend it on your character and your home.*

*(Working title — folder is "the-walk-culture"; swap in whatever name you land on.)*

---

## 1. Concept in one line

You walk in real life. Every step becomes in-game **Steps** (the currency). Steps compound up a precious-materials ladder (Copper → Silver → Gold → … → Diamond). You spend them to dress up your **character** and decorate your **home**.

Core loop: **Walk → Earn → Customize → Show off → Walk more.** Same family as Pikmin Bloom, Walkr, Wokamon, Sweatcoin — differentiated by a **deep cosmetic economy** (character + home) tied to a **tiered precious-materials currency**.

---

## 2. The stack (decided: Flutter)

**Built in Flutter + Flame + Rive.** This is a polished 2D customization app with light game feel — the hard part is reading steps reliably on both platforms, and Flutter makes that a solved, one-package problem while giving you one codebase for both stores.

- **Flutter** — UI, screens, wallet, shop, wardrobe, room editor, state.
- **Flame** — the 2D game layer (character scene, home scene, animated interactions, particle effects).
- **Rive** — slick vector character/UI animations (idle, walk cycles, tier-up celebrations).

*(For the record: Godot and Unity were the alternatives. Godot would mean hand-writing native Kotlin/Swift step plugins; Unity only makes sense if you go full 3D. For a 2D health-driven app, Flutter is the least friction.)*

### 2.1 Step / health data layer

| Platform | Source of truth | Live counter |
|---|---|---|
| **iOS** | **HealthKit** (permissioned, authoritative) | **CoreMotion `CMPedometer`** for the live in-app tick |
| **Android** | **Health Connect** (Google Fit is retired — end of service late 2026; do NOT build on it) | Raw `TYPE_STEP_COUNTER` sensor / `pedometer` package |

**Rule:** use the live pedometer only for the satisfying in-app "steps ticking up" feel; use HealthKit / Health Connect **aggregated daily totals** as the authoritative number you actually convert into currency. Never trust a live client counter for the economy.

**Running (and other workouts) are supported too — at two levels:**

1. **Free:** the step counter already counts running steps (running is just faster stepping), so every run earns currency through `STEPS` with zero extra work.
2. **Rich:** read `HealthDataType.WORKOUT` — each workout carries a `HealthWorkoutActivityType` (`RUNNING`, `RUNNING_TREADMILL`, `WALKING`, `HIKING`, `BIKING`, …) plus **duration, distance, and energy burned**, and optionally a **GPS route**. Distance/pace also come via `DISTANCE_WALKING_RUNNING` (iOS) / `DISTANCE_DELTA` (Android). This unlocks running-specific features (distance rewards, pace, running challenges, route maps).

⚠️ **Two things before wiring running up:**
- **Workout distance/GPS needs location permission** (`ACCESS_FINE_LOCATION` on Android; a Location usage string on iOS). Without it the plugin returns activity type + energy only, no distance.
- **Don't double-count.** A run's steps are usually *already* inside your `STEPS` total. If you reward `STEPS` **and** the running workout's steps/distance, you pay out twice for the same run. Decide up front: **(a)** steps are the single currency source (running just contributes its steps → simplest), or **(b)** steps are the base and running grants a *separate multiplier/bonus* you're careful not to overlap.

### 2.2 Backend

Server-authoritative currency is mandatory or it's trivially cheated.
- **Auth:** Firebase Auth / Supabase Auth (+ Sign in with Apple & Google).
- **DB:** Firestore or Supabase (Postgres).
- **Server logic:** Cloud Functions / small API that validates reported step deltas → credits currency → records inventory.
- **Push:** daily-goal nudges (sparingly). **Analytics:** funnel/retention only — never send health data to ad/analytics networks.

### 2.3 Data flow

```
[ phone / watch sensors ]
        →  OS aggregates
[ HealthKit  /  Health Connect ]   ← authoritative daily totals
        →  app reads (with permission)
[ compute delta since last sync ]
        →  report delta + metadata
[ server: validate → credit Steps → update wallet ]
        →
[ app: show new balance, animate the counter ]
```
Sync on: app open, foreground, and periodic background fetch (steps accrue while the app is closed).

### 2.4 Two tracking layers: passive Steps vs. TURBO sessions

The app tracks in two clearly separated layers. This is the same split real fitness apps use, and it puts every expensive/sensitive thing behind one explicit button.

**Layer 1 — Passive Steps (always on, zero cost).**
Steps are never tracked *by your app*. The OS health app (HealthKit / Health Connect) counts them continuously in the background whether your app is open, closed, or deleted. **When the user opens your app, you read the step delta since the last sync and credit currency.** No GPS, no Location permission, no foreground service, no battery cost from you — you're just reading a number the phone already has. This is the whole baseline economy.

**Layer 2 — TURBO sessions (opt-in, the only thing that uses GPS).**
Distance, route, live pace, etc. are captured **only while a TURBO session is running** — the user taps **TURBO**, walks/runs, taps stop. During the session your app runs a live GPS/location stream and records the path; on stop it saves the session (distance, route polyline, duration) and can write it back to the health store as a workout.

| | Layer 1 — Steps | Layer 2 — TURBO |
|---|---|---|
| Trigger | automatic (health app) | user taps **TURBO** |
| Synced | on app open | live during session |
| Needs GPS / Location perm | ✘ no | ✔ yes (requested on first TURBO) |
| Foreground service / battery | none | only during the session |
| Produces | Steps → currency | distance, route, pace, session stats |
| Works app-closed | ✔ (OS counts, you read later) | only while session is active |

**Why this split is great:** the Location permission is requested **just-in-time on the first TURBO tap** (clear context = high grant rate + easy store review), and GPS/foreground-service battery drain exists **only during a session** — never in the background. Layer 1 ships from day one; Layer 2 is your later "heavy" release, fully isolated.

#### What TURBO gives the player (so there's a reason to tap it)
Passive steps already earn currency, so TURBO needs a payoff. Good options (mix as you like):
- **An earning boost** — steps taken *during* a TURBO session earn a multiplier (fits the name: TURBO = boosted). *(See double-count rule below — implement this as a bonus, not a second credit.)*
- **Distance goals / cosmetic crates** — the "walk 5 km → open a crate" mechanic runs on TURBO distance.
- **Route trophies** — a framed map of the session you can hang in your home (routes only exist from TURBO).
- **Session stats & personal bests** — pace, longest walk, etc.

#### ⚠️ Double-count rule (important)
During a TURBO session the health app is *also* counting those steps, so they'll be credited by Layer 1 on the next app open. **Don't also credit them from the session.** Cleanest model: **steps are credited exactly once, from the health store (Layer 1); TURBO only adds (a) a multiplier on the steps taken during the session window and (b) distance/route data.** Mark the session's time window as "boosted" so Layer 1 applies the multiplier when it credits that window.

#### TURBO technical notes (for the release that builds it)
- **Foreground-only first (simplest):** track only while the app is on-screen — `ACCESS_FINE_LOCATION` "while in use" (Android) / "When In Use" (iOS), no foreground service. User must keep the app open during the walk.
- **Screen-off / backgrounded (fuller):** to keep tracking with the phone pocketed — Android **foreground service** with `foregroundServiceType="location"` (+ `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`) and a persistent notification; iOS `UIBackgroundModes: location` + `allowsBackgroundLocationUpdates` (the blue status pill shows — "When In Use" is enough, you don't need "Always").
- **Packages:** `geolocator` for the position stream; `flutter_foreground_task` to host it in an Android foreground service.
- **Anti-cheat:** apply the **speed cap** (§4.1) to TURBO segments — drop anything above walking/jogging pace, hard-flag impossible jumps.
- **Store routes portably** (§8): raw points (`lat, lng, alt, timestamp, horizontalAccuracy`) for recomputing pace/distance + filtering bad GPS, plus an **encoded polyline** for fast map rendering; keep them in their own table keyed by session id.

*(Note: you could still read passive distance from the health store for free at any time — but per this design, distance is a TURBO output, which keeps the passive layer dead simple: steps only.)*

---

## 3. Development setup & requirements

This section is the buildable spec. Everything here is verified against the current `health` package (**v13.3.1**).

### 3.1 Prerequisites (tooling)

| Need | For |
|---|---|
| **Flutter SDK (current stable 3.x)** + Dart 3 | the app |
| **VS Code** or **Android Studio** (+ Flutter/Dart plugins) | IDE |
| **macOS + Xcode + CocoaPods** | building/signing iOS — *required, iOS can only be built on a Mac* |
| **Android Studio + Android SDK + JDK 17** | building Android |
| **Apple Developer account** (paid, $99/yr) | HealthKit entitlement + App Store; **HealthKit apps can't ship on a free account** |
| **Google Play Developer account** ($25 one-time) | Play Store |
| A **physical device** of each platform | step sensors don't exist on simulators/emulators — you must test on real hardware |
| **Health Connect app** installed on the Android test device | Health Connect is the data store the plugin talks to |

### 3.2 Project dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # --- Health / steps ---
  health: ^13.3.1            # HealthKit (iOS) + Health Connect (Android)
  pedometer: ^4.0.0          # live streamed step count for the in-app counter
  permission_handler: ^11.3.1 # runtime perms (activity recognition, etc.)

  # --- Game / animation ---
  flame: ^1.18.0             # 2D game layer (scenes, sprites, particles)
  rive: ^0.13.0              # vector character / UI animation

  # --- State management (pick ONE) ---
  flutter_riverpod: ^2.5.1   # recommended
  # or: provider / flutter_bloc

  # --- Backend (Firebase example) ---
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_messaging: ^15.0.0
  # or the Supabase route: supabase_flutter

  # --- Utility ---
  workmanager: ^0.5.2        # periodic background step sync
  intl: ^0.19.0
```
> Pin to whatever is current on pub.dev at build time; the caret ranges above are a starting point.

### 3.3 iOS setup

**a) `ios/Runner/Info.plist`** — add usage strings (App Store rejects health apps without clear ones):

```xml
<key>NSHealthShareUsageDescription</key>
<string>StepQuest reads your step count to turn your walking into in-game currency.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>StepQuest can save workout data back to Apple Health.</string>
<key>NSMotionUsageDescription</key>
<string>StepQuest uses motion data to show your steps updating live.</string>

<!-- TURBO sessions only (§2.4) — not needed for the passive-steps release -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>StepQuest tracks your route and distance during a TURBO session.</string>
<!-- Add ONLY if TURBO must keep tracking with the screen off: -->
<!-- UIBackgroundModes → location, and set allowsBackgroundLocationUpdates -->
```

**b) Enable the HealthKit capability**
Open `ios/Runner.xcworkspace` in Xcode → select the **Runner** target → **Signing & Capabilities** → **+ Capability** → **HealthKit**.

**c) Minimum iOS version:** target **iOS 13.0+** (some data types need newer). Set in the Podfile / Xcode deployment target.

**Gotchas:**
- The device **must be unlocked** to read HealthKit data, or you get a "Protected health data is inaccessible" error.
- iOS deliberately **won't report whether READ permission was granted** — you infer it by attempting a read and handling an empty result gracefully.

### 3.4 Android setup

**a) `android/app/src/main/AndroidManifest.xml`**

Detect Health Connect + declare the permission-rationale intent:
```xml
<!-- Is Health Connect installed? + rationale intent -->
<queries>
  <package android:name="com.google.android.apps.healthdata" />
  <intent>
    <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
  </intent>
</queries>
```

Declare the specific health permissions you use (steps + the extras that power multipliers/anti-cheat):
```xml
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_DISTANCE"/>
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.READ_FLOORS_CLIMBED"/>

<!-- Read history older than 30 days (Health Connect defaults to 30) -->
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_HISTORY"/>
<!-- Read steps while the app is backgrounded -->
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND"/>
<!-- Required to access fitness/step data -->
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>

<!-- TURBO sessions only (§2.4) — add in the TURBO release, not the passive-steps release -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- Add these ONLY if TURBO tracks with the screen off (foreground service): -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
```
> These belong to the **TURBO release**, not the first (passive-steps) release. Passive step counting needs none of them — only a live GPS session does.

Point Health Connect's permission screen at your privacy policy (**needed to pass Google review**):
```xml
<activity-alias
    android:name="ViewPermissionUsageActivity"
    android:exported="true"
    android:targetActivity=".MainActivity"
    android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
  <intent-filter>
    <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
    <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
  </intent-filter>
</activity-alias>
```

Add the rationale intent-filter to `.MainActivity`:
```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    ... >
  <intent-filter>
    <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
  </intent-filter>
</activity>
```

**b) `MainActivity.kt` must extend `FlutterFragmentActivity`** (required for the Android 14 permission flow):
```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() { }
```

**c) `android/gradle.properties`**
```properties
org.gradle.jvmargs=-Xmx1536M
android.enableJetifier=true
android.useAndroidX=true
```

**d) `android/app/build.gradle`** — `minSdkVersion 26` (Health Connect's floor is Android 8.0), `compileSdk`/`targetSdk` current (34+).

**Gotchas:**
- The **Health Connect app must be installed** on the device (framework-level on Android 14+, otherwise from Play Store). Prompt users to install it if missing.
- On Android, manually-entered steps sometimes register as `RecordingMethod.unknown` rather than `.manual`, so manual-entry filtering isn't perfect (see §5 anti-cheat).

### 3.5 Minimal working code (read steps → convert to currency)

```dart
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

final health = Health();

Future<int> getTodaySteps() async {
  await health.configure();

  // Android needs the Activity Recognition runtime permission
  await Permission.activityRecognition.request();

  // Ask HealthKit / Health Connect for step read access
  final granted = await health.requestAuthorization(
    [HealthDataType.STEPS],
    permissions: [HealthDataAccess.READ],
  );
  if (!granted) return 0;

  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);

  // Authoritative "steps today"
  final steps = await health.getTotalStepsInInterval(midnight, now);
  return steps ?? 0;
}

/// Adventure-Sync-style distance (metres today) — a plain health read,
/// NO GPS and NO location permission. Works with the app closed.
Future<double> getTodayDistanceMeters() async {
  final type = Platform.isIOS
      ? HealthDataType.DISTANCE_WALKING_RUNNING
      : HealthDataType.DISTANCE_DELTA;

  final granted = await health.requestAuthorization(
    [type], permissions: [HealthDataAccess.READ]);
  if (!granted) return 0;

  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);

  final points = health.removeDuplicates(
    await health.getHealthDataFromTypes(
      types: [type], startTime: midnight, endTime: now),
  );
  return points.fold<double>(
    0, (sum, p) => sum + (p.value as NumericHealthValue).numericValue.toDouble());
}

// --- Currency conversion (see §5 for the tier strategy) ---
const tiers = ['Steps','Copper','Silver','Gold','Titanium',
               'Platinum','Tanzanite','Emerald','Ruby','Diamond'];

/// Converts a raw lifetime step total into the highest whole tier it reaches.
/// Uniform 1000x here — swap in your chosen (non-uniform) multipliers.
Map<String,int> toWallet(int totalSteps) {
  final wallet = <String,int>{};
  var remaining = totalSteps;
  for (final tier in tiers) {
    wallet[tier] = remaining % 1000;
    remaining ~/= 1000;
    if (remaining == 0) break;
  }
  return wallet;
}
```

**Anti-cheat filter — credit only OS-recorded steps:**
```dart
final data = await health.getHealthDataFromTypes(
  types: [HealthDataType.STEPS],
  startTime: midnight,
  endTime: now,
  recordingMethodsToFilter: [RecordingMethod.manual, RecordingMethod.unknown],
);
// Sum `data` server-side; never trust the client's total alone.
```
> Caveat: the manual/unknown distinction is reliable on iOS but leaky on Android — pair it with server-side plausibility caps (§5.1).

**Reading running workouts (optional, for running-specific features):**
```dart
Future<List<HealthDataPoint>> getTodayRuns() async {
  await Permission.activityRecognition.request();
  await Permission.location.request(); // needed for workout DISTANCE

  final granted = await health.requestAuthorization(
    [HealthDataType.WORKOUT],
    permissions: [HealthDataAccess.READ],
  );
  if (!granted) return [];

  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);

  final workouts = await health.getHealthDataFromTypes(
    types: [HealthDataType.WORKOUT],
    startTime: midnight,
    endTime: now,
  );

  // Keep only running; each point's value is a WorkoutHealthValue with
  // workoutActivityType, totalDistance, totalEnergyBurned, totalSteps.
  return workouts.where((p) {
    final w = p.value as WorkoutHealthValue;
    return w.workoutActivityType == HealthWorkoutActivityType.RUNNING ||
           w.workoutActivityType == HealthWorkoutActivityType.RUNNING_TREADMILL;
  }).toList();
}
```
> Remember the **double-count rule** from §2.1: if `STEPS` is already your currency source, use running workouts only for *stats and bonuses*, not to re-credit the steps a second time.

### 3.6 Permission & consent flow (order matters)

1. **Explain first** — a friendly screen: "StepQuest turns your steps into currency. Connect your health data?" *(don't fire the OS prompt cold — it hurts grant rates and store review.)*
2. Request **Activity Recognition** (Android) via `permission_handler`.
3. Call `requestAuthorization([STEPS])` → routes to HealthKit / Health Connect.
4. Handle **partial / denied** gracefully (user may grant steps but deny everything).
5. If Health Connect isn't installed (Android), deep-link them to install it.
6. **Location is NOT requested here.** Ask for it only on the **first TURBO tap** (§2.4), with its own one-line explainer — so the passive-steps onboarding never mentions GPS.
7. Optionally request **history** (`requestHealthDataHistoryAuthorization`) and **background** (`requestHealthDataInBackgroundAuthorization`) access.

### 3.7 Pre-launch requirements checklist

- [ ] Apple Developer + Google Play accounts
- [ ] HealthKit capability enabled; all `Info.plist` usage strings written
- [ ] Android manifest: queries, health permissions, activity-alias, rationale intent-filter
- [ ] `MainActivity` extends `FlutterFragmentActivity`; `minSdk 26`; AndroidX/Jetifier on
- [ ] **Privacy policy** published and linked (required by both platforms for health data)
- [ ] App Store Privacy labels + Play Data Safety form filled accurately
- [ ] Tested on **physical** iOS and Android devices
- [ ] Server-authoritative currency + plausibility caps live before launch

---

## 4. Step detection & anti-cheat (design)

### 4.1 Anti-cheat, in order of value
1. **Only credit OS-recorded steps** (filter manual entries — §3.5).
2. **Read aggregated totals from the health store**, not a raw live client counter.
3. **Server-side plausibility caps** — humans can't do 40k steps/hour; cap per-hour and per-day; flag outliers.
4. **Speed cap (Pokémon GO's trick)** — for distance, compute speed = distance ÷ time per synced segment and **discard anything above walking/jogging pace (~10.5 km/h)** so driving and fast cycling don't count; treat physically impossible jumps (80+ km/h between samples) as a hard flag. This is the single most effective distance anti-cheat and it's cheap.
5. **Velocity checks** — sudden jumps vs. the user's history get held for review.
6. **Device integrity** (later) — Play Integrity / App Attest to spot modified clients.

It's a cosmetic economy, not real money — aim to make casual cheating annoying and keep leaderboards honest-ish.

### 4.2 Inclusivity
Health Connect / HealthKit also expose **distance, active energy, flights climbed, and wheelchair pushes**. Credit an "activity" umbrella so wheelchair users and cyclists aren't excluded — broader audience, and it's the right call.

---

## 5. The currency system — and an important design flag

Your ladder: **Steps → Copper → Silver → Gold → Titanium → Platinum → Tanzanite → Emerald → Ruby → Diamond**, each tier = **1,000×** the previous, **1 real step = 1 Step**.

### 5.1 What that actually costs, in real walking

| Tier | = of previous | Steps to earn ONE | Effort @ 10,000 steps/day |
|---|---|---:|---|
| Step | — | 1 | instant |
| **Copper** | 1,000 Steps | 1,000 | ~2.4 hours ✅ |
| **Silver** | 1,000 Copper | 1,000,000 | ~100 days ✅ |
| **Gold** | 1,000 Silver | 1,000,000,000 | **~274 years** ⚠️ lifetime feat |
| **Titanium** | 1,000 Gold | 1×10¹² | ~274,000 years ❌ |
| **Platinum** | 1,000 Titanium | 1×10¹⁵ | ~274 million years ❌ |
| **Tanzanite** | 1,000 Platinum | 1×10¹⁸ | older than the universe ❌ |
| **Emerald / Ruby / Diamond** | 1,000× each | 10²¹ / 10²⁴ / 10²⁷ | absurd ❌ |

**The flag:** with a strict uniform 1,000× ladder, **only Copper and Silver are reachable by walking; Gold is a multi-lifetime feat; everything above Gold is mathematically unreachable by a human.** (Even 20k/day for 80 years ≈ 584M steps — not even one Gold.) Choose how to handle the top on purpose:

- **A — Prestige framing:** keep 1000× untouched; top tiers are mythical, reachable only via multipliers/events. Great hook, but top cosmetics rarely get used.
- **B — Non-uniform multipliers *(recommended)*:** 1000× through Gold for the epic early climb, then 10×–50× per tier above Gold so the whole ladder is climbable over a play-lifetime.
- **C — Two-track:** Steps→Copper→Silver→Gold is spendable currency; Titanium→Diamond are **achievement medals** earned via milestones/events that gate the rarest cosmetics.

**Suggested: B + C hybrid** — keep 1000× through Gold, soften above it, and let streaks/events feed the prestige tiers. Your creative call; the table just makes sure you choose with eyes open.

### 5.2 Earning multipliers
Daily **streaks** (+5%/day, cap ~2×) · **goal bonuses** · **quest rewards** · small multipliers from **distance / active-minutes / floors** · **boosts** (double steps for an hour) · **guild pooling**.

**Running bonus (option b from §2.1):** because running is more intense than walking, give running-detected activity a modest multiplier or a per-kilometre bonus *on top of* the steps it already produces — e.g. running steps count as ×1.25, or +50 Steps per km run. Just make sure the bonus is additive and doesn't re-credit the underlying steps (the double-count trap). This rewards runners without breaking the "1 real step = 1 Step" promise for walkers.

---

## 6. Core loop & feature set

**MVP loop:** walk → sync → currency ticks up → open shop → buy cosmetic → equip → see it on character/home.

Layer in (priority order): **wallet with a great tier-up animation** · **character customizer** · **home customizer** · **daily goal + streaks** · **quests/challenges** · **achievements/trophy room** (display milestones *in the home*) · **companion pet** that grows with your steps · **seasonal events** · **social** (visit friends' homes, leaderboards, gifting) · **guilds** (pooled goals).

**TURBO-session features (Phase 4, §2.4):** because distance/route come from a TURBO session, these all live there — a **TURBO earning boost**, distance/pace stats and personal bests, running/walking challenges ("cover 5 km in one TURBO"), and a **framed route map** of a session to hang in your home. All opt-in; non-TURBO players still earn fully from passive steps.

**Distance goal track — the "egg" mechanic, adapted.** Pokémon GO turns distance into eggs that hatch rewards; do the same with **cosmetic crates**: *"walk 5 km in TURBO to open a Bronze crate,"* *10 km → Silver crate,* etc. Distance becomes a **second progression track** parallel to your Steps currency — steps buy what you *choose*, distance-crates deliver *surprise* cosmetics — so people care about how far they go, not just how many steps. Runs on TURBO distance (Phase 4). *(If you ever randomize crate contents, mind the loot-box rules in §9, especially for minors — fixed contents or "pick one of three" avoids that entirely.)*

---

## 7. Customization catalog

**Principle:** tie rarity to currency tier — every tier unlocks a visibly cooler shelf.

**Character**
- *Appearance:* skin tones (inclusive), body types/heights, faces (eyes, brows, nose, mouth, freckles, makeup), hair styles + colors (natural + fantasy), facial hair.
- *Outfits:* tops/bottoms/dresses/shoes as mix-and-match slots; themed sets — Casual, Formal, Athletic/Streetwear, Fantasy, Sci-fi, Cottagecore, Cyberpunk, Historical, Seasonal.
- *Accessories:* hats, glasses, jewelry, scarves, bags, gloves, a **fitness-watch** accessory (meta nod), **running gear** (running shoes, tracksuits, sweatbands, race bibs earned from running challenges), wings/tails/ears.
- *High-tier flex (Gold→Diamond):* auras & particle trails, animated/glowing outfits, victory emotes & dances, custom idle/walk animations, titles & badges ("Diamond Walker"), nameplate frames.

**Home**
- *Surfaces:* room types (living, bed, kitchen, study, **home gym**, garden, bath), wallpaper/paint, flooring, rugs, curtains, lighting; exterior later (house style, roof, door, mailbox).
- *Furniture:* seating, beds, tables, desks, shelves, storage.
- *Decor:* wall art, mirrors, plants, aquariums, clocks, books, candles.
- *Themes (sell as bundles):* Cozy, Modern/Minimalist, Fantasy, Sci-fi, Cottagecore, Cyberpunk, Japandi, Seasonal.
- *Synergy items (unique to you):* **trophy/display case** showing currency-tier milestones, a **step-counter clock**, a **treadmill/gym rig** that animates faster the more you walk *or run*, a **framed route map** of a favourite run, a **pet area**, items that **react when you hit your daily goal** (confetti, lights, pet celebrates).
- *High-tier flex:* animated environments (swimming fish, fireplace flicker, aurora window), particle ambience (petals, snow, fireflies), rare "wonder" pieces (indoor waterfall, glowing crystal tree), and **home expansions** (extra rooms / second floor) as big Gold+ buys.

**Pricing philosophy**

| Rarity | Price band | Feels like |
|---|---|---|
| Common | 200–1,000 Steps | a short walk |
| Uncommon | 1–10 Copper | a day or two |
| Rare | 5–50 Copper | a couple weeks |
| Epic | 1–20 Silver | months |
| Legendary | Gold+ / prestige-gated | a long-haul goal or event exclusive |

---

## 8. Backend data model (sketch)

```
User        id, auth_provider, display_name, avatar_config, home_config, settings
Wallet      user_id, total_steps_lifetime, total_steps_spent
            (derive tier balances from these two numbers — no per-tier storage)
StepLedger  user_id, synced_at, source, delta_steps, credited_steps, flagged?  (append-only)
Inventory   user_id, owned_item_ids[]
ShopItem    id, name, slot, theme, rarity, price{tier,amount}, is_animated, event_id?
Streak/Ach  user_id, streak_current, streak_best, milestones[]

# --- Distance & routes: define now, populate in a later release (§2.4) ---
DailyStats     user_id, date, steps, distance_m, active_minutes, floors   # distance_m nullable
WorkoutSession user_id, id, type (running/walking/...), start, end,
               distance_m, energy_kcal, avg_pace, source, has_route
Route          session_id, encoded_polyline,                              # compact, for map display
               points[ {lat, lng, alt, t, h_accuracy} ]                   # raw, for pace/distance recompute + GPS filtering
               # keep in its own table keyed by session_id — routes are large, don't inline them
```
**Tip:** store one authoritative `total_steps_lifetime` integer and DERIVE all tier balances from it (spending increments `total_steps_spent`). The whole ladder becomes a pure function of two numbers — kills desync/duplication bugs.

**Distance/route tip:** `distance_m` and the `WorkoutSession`/`Route` tables can exist from v1 (empty) so nothing needs migrating when you switch capture on. `distance_m` is backfillable from the health store; `Route.points` are not (for self-recorded runs) — they start accumulating only once GPS recording ships.

---

## 9. Privacy, compliance & store policy (don't skip)

Health data is the **most sensitive** category; stores reject sloppy handling.
- Explicit, purpose-specific **consent** before the OS prompt.
- **Privacy policy is mandatory** — Health Connect links to it from its permission screen; HealthKit requires one.
- **Never** use health data for ads or sell it; keep it out of analytics/ad SDKs.
- **Data minimization** — request only the types you use.
- **Location/routes:** don't request Location or record GPS until the TURBO/route feature ships — location history is highly sensitive PII and draws extra store review. When it ships, give it its own consent screen and let users use the app fully without it.
- **Regional law:** GDPR (EU), CCPA (California); **COPPA/age rules** if minors may use it — be extra careful with any randomized (loot-box) purchases.
- Fill **App Store Privacy labels** and **Play Data Safety** accurately.

---

## 10. Monetization (optional, ethical)

Economy is cosmetic-only, so you can monetize without pay-to-win: buy currency/**boosts**, a **seasonal cosmetic pass** (free + paid track), **direct cosmetic purchases**, **remove-ads/supporter tier**. Avoid predatory loot boxes, especially for minors. Your best retention is the *habit*, not the wallet.

---

## 11. Build roadmap

| Phase | Goal | Contents |
|---|---|---|
| **0 — Prototype** | Prove the feel | Read steps (one platform), live counter, convert to Copper, one equippable item |
| **1 — MVP** | Shippable loop, both platforms | Passive steps→currency (credit health-store delta on app open), basic character customizer, small shop, wallet + tier-up animation, auth + cloud save, anti-cheat v1. **Create the empty distance/route/session schema (§8) so nothing needs migrating later — but no GPS/location yet.** |
| **2 — v1.0** | Retention | Home customizer, daily goals + streaks, quests, achievements/trophy room, companion pet |
| **3 — Growth** | Social & seasons | Friends, home visits, leaderboards, first seasonal event, more themes |
| **4 — TURBO (the GPS release)** | Active sessions | The **TURBO button**: live GPS session capturing distance + route + pace, just-in-time Location permission, TURBO earning boost, distance crates, route-map trophies in the home. *This is the only release that touches GPS/location/foreground service — see §2.4.* |
| **5 — Scale** | Depth & revenue | Guilds/pooling, cosmetic pass, boosts, home expansions, prestige tiers |

Start Phase 0 now: "watch my real steps turn into Copper and buy a hat" is the moment that tells you if the concept sings.

---

## 12. Open questions to decide before building

1. **Currency ladder:** strict 1000× (A), softened top (B), or two-track (C)? *(Recommend B+C.)*
2. **Art style:** 2D (fits this Flutter stack) vs. eventual 3D?
3. **Activity metric:** step-only vs. broader (distance/wheelchair/cycling)?
4. **Social scope at launch:** solo-first vs. friends day one?
5. **Monetization:** free/cosmetic-IAP vs. fully free?
6. **Name & vibe:** cozy life-sim, cute/kawaii, fantasy-RPG, or sleek-modern?

---

### TL;DR
- **Flutter + Flame + Rive.** Steps via **`health`** (HealthKit + Health Connect) + **`pedometer`** for the live counter; **Google Fit is retired — don't use it.**
- **Setup essentials:** HealthKit capability + `Info.plist` strings (iOS); Health Connect manifest queries, health permissions, activity-alias, rationale intent-filter, `FlutterFragmentActivity`, `minSdk 26` (Android); privacy policy required by both; test on **physical devices**.
- **Server-authoritative currency**, credit only OS-recorded steps + plausibility caps = your anti-cheat base.
- **Currency heads-up:** strict 1000× makes only Copper/Silver reachable and everything above Gold impossible by walking — pick a top-of-ladder strategy on purpose (recommend softening above Gold + a prestige track).
- **Tie cosmetic rarity to currency tier** so every tier unlocks a cooler shelf.
- **Running is covered:** it already earns currency as steps, and reading `WORKOUT` data adds running distance/pace/routes for extra features — just add Location permission for distance and avoid double-counting a run's steps.
- **Two layers:** **Steps** are passive — the OS counts them, you read the delta and credit on app open (no GPS, no Location, works app-closed). **Distance + route** are captured **only during a TURBO session** (the user taps TURBO) — that's the one place GPS/Location/foreground-service live, requested just-in-time. TURBO adds an earning boost + distance crates + route-map trophies; credit steps once (passively) and treat TURBO as a bonus, never a second credit.
