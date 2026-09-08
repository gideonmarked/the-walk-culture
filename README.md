# StepQuest (working title) — `the-walk-culture`

A walking-powered life sim: real steps become in-game **Steps** currency you
spend on your character and home. Full design in
[`StepGame_Plan_and_Documentation.md`](StepGame_Plan_and_Documentation.md).

Working build: passive steps → currency → shop → buy → equip, plus daily
goal/streak, house decorating, settings and consent-first onboarding.
Flutter + Riverpod, local persistence, no backend yet. **`flutter analyze` is
clean and all tests pass.**

## Docs

| Doc | What |
|---|---|
| [`StepGame_Plan_and_Documentation.md`](StepGame_Plan_and_Documentation.md) | full product/technical design |
| [`docs/FEATURES.md`](docs/FEATURES.md) | what's built today, per feature |
| [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) | architecture + how to add a module |
| [`docs/BACKEND.md`](docs/BACKEND.md) | Phase 1 server setup + provider choice (Supabase vs Firebase) |
| [`docs/ANDROID.md`](docs/ANDROID.md) | Android setup & run (**primary target**) |
| [`docs/IOS.md`](docs/IOS.md) | iOS setup & run (Mac only, deferred) |
| [`docs/TESTING.md`](docs/TESTING.md) | automated + manual test plan (Android-first) |

---

## What's here (feature-first modules)

```
lib/
  main.dart · app.dart          entry + onboarding gate
  core/                         currency.dart, streaks.dart, theme.dart (pure logic)
  models/                       player_state.dart, shop_item.dart
  data/shop_catalog.dart        seed cosmetics
  services/health_service.dart  passive step read (doc §2.4 Layer 1)
  state/app_providers.dart      PlayerController + OnboardingController
  features/
    shell/        bottom-nav host (Home·Quests·Pass·Shop·Profile)
    onboarding/   consent-first health opt-in (doc §3.6)
    home/         avatar + goal + pet + wallet + sync/simulate
    quests/       daily step-goal quests → bonus Steps
    achievements/ trophy room (derived milestones)
    pass/         Travel Pass — seasonal 30-level free/VIP reward track
    shop/         buy cosmetics
    character/    equip wearables + CharacterView
    house/        place home decor in the room
    wallet/       tier balances strip
    settings/     daily goal · privacy · reset (via Home app bar)
test/                           currency, streak, controller, widget-smoke tests
platform_config/                native config snippets (merged into android/)
setup.sh / setup.ps1            one-shot native bootstrap
```

### Design decisions already wired in
- **Passive Steps only** (doc §2.4 Layer 1): the app reads today's steps from
  HealthKit / Health Connect and credits the delta on open. No GPS, no location.
- **TURBO is deferred to Phase 4** — the Home screen shows a disabled TURBO
  button so the model is visible, but no GPS/location code or permissions exist
  yet.
- Wallet is **derived from two numbers** (`lifetimeSteps`, `spentSteps`) per
  doc §8 — no per-tier storage.

---

## Environment (this machine)

- **Flutter 3.44.6 stable** is installed inside the WSL **"Ubuntu"** distro at
  `~/flutter`. Run everything there: `wsl -d Ubuntu` (NOT the default
  "Ubuntu-22.04"), with `export PATH="$HOME/flutter/bin:$PATH"`.
- The native `android/` folder is already generated and configured (health
  permissions, `FlutterFragmentActivity`, `minSdk 26`).
- To build/run on an Android device you still need the **Android SDK + JDK 17**
  in WSL — see [`docs/ANDROID.md`](docs/ANDROID.md).
- Step sensors **don't exist on emulators** — use a physical device, or the
  in-app **+500 steps (simulate)** button.

---

## Bootstrap (only needed to regenerate native folders)

`setup.sh` backs up `lib/`+`pubspec.yaml`, runs `flutter create`, restores them,
installs `MainActivity.kt`, and runs `pub get`:

```bash
wsl -d Ubuntu -e bash -lc 'export PATH=$HOME/flutter/bin:$PATH; cd ~/Projects/the-walk-culture && bash setup.sh'
```

> The Android manifest + Gradle config are **already merged**. The only
> outstanding platform work is **iOS** (Mac only, deferred): merge
> [`platform_config/Info.plist.additions.xml`](platform_config/Info.plist.additions.xml)
> and enable the HealthKit capability in Xcode — see [`docs/IOS.md`](docs/IOS.md).

---

## Run

```bash
export PATH="$HOME/flutter/bin:$PATH"    # inside: wsl -d Ubuntu
flutter pub get
flutter analyze       # clean
flutter test          # all tests pass
flutter run -d <device>   # physical Android device — see docs/ANDROID.md
```

On a device without granted health data, tap **+500 steps (simulate)** to
exercise the full earn → shop → equip loop.

---

## Roadmap (from the design doc §11)

| Phase | Status | Focus |
|---|---|---|
| 0 Prototype | **done** | steps → currency → buy → equip |
| 2 (slice) | **done** | daily goal + streak, quests, achievements, companion pet, house decorating, settings, onboarding |
| 1 MVP | next | server-authoritative currency (Firebase/Supabase), auth, anti-cheat v1 |
| 3 Growth | | friends, leaderboards, seasons |
| 4 TURBO | | live GPS session: distance, route, pace (the only GPS release) |
| 5 Scale | | guilds, prestige tiers *(cosmetic pass: built)* |

> `health` API note: pinned to `^13.3.1`. If a method signature differs on the
> version you resolve (e.g. `configure()` / `requestAuthorization`), adjust
> `lib/services/health_service.dart` — the shape is documented in doc §3.5.
