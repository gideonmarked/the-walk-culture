# Development & Architecture Guide

How the code is organized and how to add to it. Product spec lives in
[`../StepGame_Plan_and_Documentation.md`](../StepGame_Plan_and_Documentation.md);
this doc is about the codebase.

---

## Stack

- **Flutter** (stable 3.44.x) + **Dart 3** — installed inside the WSL "Ubuntu"
  distro at `~/flutter`.
- **Riverpod** (`flutter_riverpod`) for state.
- **shared_preferences** for local persistence (Phase 0). Replaced by a
  server-authoritative backend in Phase 1 (doc §2.2).
- **health** + **pedometer** + **permission_handler** for step data.
- Flame/Rive/Firebase are listed but **commented out** in `pubspec.yaml` until
  the phase that needs them.

---

## Module layout (feature-first)

```
lib/
  main.dart                  entry — wraps app in ProviderScope
  app.dart                   MaterialApp + onboarding gate

  core/                      pure, dependency-light logic (easy to unit-test)
    currency.dart            tier ladder, toWallet(), priceInSteps()
    streaks.dart             computeStreak(), dayKey()
    quests.dart              Quest type + daily quest list
    achievements.dart        Achievement type (predicate over state)
    pet.dart                 pet stage/progress from lifetime steps
    theme.dart               ThemeData factory + seed color

  models/                    immutable data types
    player_state.dart        wallet + inventory + goal/streak + quests snapshot
    shop_item.dart           ShopItem, ItemSlot, Rarity

  data/
    shop_catalog.dart        seed cosmetics (emoji placeholder art)
    achievements_catalog.dart  seed achievements

  services/                  side-effecting integrations
    health_service.dart      passive step read (doc §2.4 Layer 1)

  state/
    app_providers.dart       PlayerController + OnboardingController + providers

  features/                  one folder per screen/feature
    shell/root_scaffold.dart       bottom-nav host (Home·Quests·Shop·Character·House)
    onboarding/                    consent-first health opt-in (doc §3.6)
    home/                          avatar + goal + pet + wallet + sync/simulate
      widgets/daily_goal_card.dart
      widgets/pet_card.dart
    quests/                        daily step-goal quests → bonus Steps
    achievements/                  trophy room (derived milestones)
    wallet/wallet_bar.dart         tier balances strip
    shop/                          buy cosmetics
    character/                     equip wearables + CharacterView
    house/                         place home decor in the room
    settings/                      daily goal, privacy, reset (via Home app bar)
```

See [`FEATURES.md`](FEATURES.md) for a per-feature catalog with doc references.

### Layering rule
`features/` → depends on → `state/` → `services/` + `models/` + `core/`.
`core/` and `models/` depend on nothing app-specific. Keep new pure logic in
`core/` so it stays unit-testable without a device.

---

## State management

Two `StateNotifier`s in `state/app_providers.dart`:

- **`PlayerController`** (`playerControllerProvider`) — the single source of
  truth for wallet, inventory, goal and streak. All mutations go through it
  (`syncSteps`, `addSimulatedSteps`, `buy`, `equip`/`unequip`,
  `placeHome`/`removeHome`, `setDailyGoal`, `resetProgress`) and each persists
  via `_save()`.
- **`OnboardingController`** (`onboardingProvider`) — boolean "has the user
  finished onboarding".

Screens are `ConsumerWidget`/`ConsumerStatefulWidget`; they `ref.watch` the
player for reads and `ref.read(...notifier)` for actions.

### Key invariants (doc §8)
- The wallet is **derived** from `lifetimeSteps` and `spentSteps` — never stored
  per tier. `spendableSteps = lifetimeSteps - spentSteps`.
- Passive step credit uses the **delta** since last sync, clamped `>= 0`.
- Steps are credited **once**, from the health store. TURBO (Phase 4) will add
  bonuses on top — never a second credit (doc §2.4 double-count rule).

---

## Adding a feature module

1. Create `lib/features/<name>/<name>_screen.dart` (+ a `widgets/` subfolder if
   needed).
2. If it needs new persistent state, add fields to `PlayerState` (update
   `copyWith`/`toJson`/`fromJson`) and a mutator on `PlayerController`.
3. Put any non-trivial rule in `core/` as a pure function and unit-test it.
4. Register the screen in `features/shell/root_scaffold.dart` if it's a tab.
5. `flutter analyze` must stay clean; add tests; run `flutter test`.

---

## Running things (WSL "Ubuntu" distro)

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
flutter analyze
flutter test
flutter run -d <device>     # see docs/ANDROID.md for device setup
```

- **Bootstrap** (regenerate native folders): `bash setup.sh`.
- Android device setup / wireless debugging: [`ANDROID.md`](ANDROID.md).
- iOS (Mac only, deferred): [`IOS.md`](IOS.md).
- Test plan: [`TESTING.md`](TESTING.md).

---

## Current status vs roadmap (doc §11)

**Done (Phase 0 + a Phase 2 slice):** passive steps→currency, shop, buy, equip,
wallet with tiers, daily goal + streak, **daily quests, achievements/trophy room,
companion pet**, house/room placement, settings, consent-first onboarding, local
persistence.

**Not yet:** server-authoritative currency + auth (Phase 1), social (Phase 3),
**TURBO GPS sessions** (Phase 4), guilds/cosmetic-pass (Phase 5). The Home screen
shows a disabled TURBO button as a placeholder — no GPS/location code exists yet,
by design. Full catalog in [`FEATURES.md`](FEATURES.md).

---

## Known environment notes

- Flutter lives in the WSL **"Ubuntu"** distro (not the default "Ubuntu-22.04").
  Always target it: `wsl -d Ubuntu`.
- `flutter pub get` reports "15 packages have newer versions incompatible with
  dependency constraints" — expected; the pinned versions resolve and build.
- `flutter create` printed a Gradle/JDK compatibility warning. Building an APK
  needs the Android SDK + JDK 17 installed in WSL — see [`ANDROID.md`](ANDROID.md).
