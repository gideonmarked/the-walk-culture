# Feature Catalog

What's implemented today, where the code lives, and which design-doc section it
maps to. Product spec:
[`../StepGame_Plan_and_Documentation.md`](../StepGame_Plan_and_Documentation.md).

> Everything below is **local/offline** (SharedPreferences). Server-authoritative
> currency + auth is Phase 1 (doc §2.2). **TURBO / GPS is Phase 4** and not built.

---

## Core loop

| Feature | Where | Doc |
|---|---|---|
| **Passive step sync** — reads today's steps from Health Connect/HealthKit, credits the delta; time-bounded calls so it can never hang; `null`-safe fallback | `services/health_service.dart`, `state/app_providers.dart` (`syncSteps`) | §2.4 Layer 1 |
| **Auto-sync** — re-reads the health store every 5s while open + on app resume; no-op guard avoids needless rebuilds | `state/app_providers.dart` (`startAutoSync`), `app.dart` (lifecycle) | §2.3 |
| **Live per-step ticker** — the Today counter ticks up in real time from the device pedometer, re-baselined to the authoritative health total each sync | `state/app_providers.dart` (`LiveStepsController`/`liveStepsProvider`), `features/home/home_screen.dart` | §2.1 |
| **Simulate steps** — `+500` button to exercise the loop with no sensor | `features/home/home_screen.dart` | — |
| **Currency ladder** — Steps→Copper→…→Diamond, wallet derived from `lifetimeSteps`/`spentSteps`; shown as **tappable icons** (tap reveals amount + name) | `core/currency.dart`, `features/wallet/wallet_bar.dart` | §5, §8 |
| **Tier-up celebration** — one-shot dialog the moment a new tier is first reached | `core/currency.dart` (`highestTierIndex`), `widgets/tier_up_dialog.dart`, `state/app_providers.dart` (`tierUpProvider`) | §6 |
| **Shop** — 22 cosmetics across hat/top/bottom/shoes/accessory/home & tiers | `features/shop/`, `data/shop_catalog.dart` | §7 |
| **Character** — equip/unequip wearables (incl. bottoms); avatar re-renders | `features/character/` | §7 |
| **House** — place/remove home decor in a room | `features/house/` | §7 Home |

## Retention layer (Phase 2 slice)

| Feature | Where | Doc |
|---|---|---|
| **Daily goal + streak** — 🔥 streak increments on consecutive goal days, resets on a gap, tracks best | `core/streaks.dart`, `features/home/widgets/daily_goal_card.dart` | §5.2, §6 |
| **Daily quests** — reach a step target today for **bonus Steps**; reset daily; claim-once | `core/quests.dart`, `features/quests/` | §6 |
| **Mystery Spheres** — daily; tiers 3k/5k/10k/16k/21k/50k steps (base Common→Legendary), **glow** when today's steps reach them, tap to open once/day for a random item per a transparent odds table; Celestial is real-money only | `core/spheres.dart`, `features/spheres/`, `state/app_providers.dart` (`openSphere`/`sphereReady`) | §6 |
| **Achievements / Trophy Room** — milestones derived live from state (lifetime, streak, collection) | `core/achievements.dart`, `data/achievements_catalog.dart`, `features/achievements/` | §6 |
| **Companion sphere** — shifts tier (Warm-up→Bronze→…→Mythic) as **today's** steps grow, using the same thresholds as the Mystery Spheres (3k/5k/10k/16k/21k/50k) so tier names are consistent | `core/companion.dart`, `features/home/widgets/companion_card.dart` | §6 |
| **Earning boost** — activate a **2× Steps** multiplier for 1 hour (applies to credited steps, not `todaySteps`, so goals/quests aren't inflated) | `features/home/widgets/boost_card.dart`, `state/app_providers.dart` (`activateBoost`) | §5.2 |
| **Collection** — "collect them all" gallery of every cosmetic (owned in colour, locked items greyed), with a completion % — fed by Shop + Spheres | `features/collection/`, Home app bar 🔲 | §6/§7 |
| **Settings** — daily-goal picker, privacy note, reset progress | `features/settings/` | — |
| **Onboarding** — consent-first health opt-in with a Skip path | `features/onboarding/` | §3.6 |

## Anti-double-count note (important)
Quest rewards add **bonus** Steps to `lifetimeSteps`; they never re-credit walked
steps and don't touch `todaySteps`, so claiming can't inflate quest progress or
break the "1 real step = 1 Step" promise (doc §2.4 double-count rule).

---

## Navigation map

- **Bottom nav:** Home · Quests · Spheres · Shop · Profile
- **Profile tabs:** Avatar (character customiser) · Home (room decor)
- **Home app bar:** 🔲 Collection · 🏆 Trophy Room · ⚙️ Settings · 🔄 Sync
- **Home cards:** avatar · today/lifetime/spendable · daily-goal+streak · pet · wallet

---

## Not yet built (roadmap, doc §11)

- **Phase 1:** server-authoritative currency, auth (Firebase/Supabase), anti-cheat v1 — see [`BACKEND.md`](BACKEND.md) for the setup plan & provider choice
- **Phase 2 (remaining):** seasonal events, richer home/character catalogs, live pedometer tick
- **Phase 3:** friends, home visits, leaderboards, gifting
- **Phase 4:** **TURBO** — live GPS session (distance, route, pace), the only GPS release
- **Phase 5:** guilds/pooling, cosmetic pass, boosts, prestige tiers

The Home screen shows a disabled **TURBO — coming in Phase 4** button as a
placeholder; no GPS/location code or permissions exist yet, by design.
