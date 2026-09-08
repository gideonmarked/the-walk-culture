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
| **Travel Pass** — seasonal 30-level track, free column + VIP column; 60-day seasons derived from a fixed UTC epoch (never stored); **XP = raw walked steps** (VIP/boost multiply currency, not XP) plus +100/quest, +100/devotion, +50/sphere; every cell a named reward, claim-once, **retro-claims** the whole earned VIP column when you subscribe | `core/travel_pass.dart` (seasons, levels, `kPassTrack`), `data/pass_catalog.dart` (17 exclusives), `features/pass/`, `state/app_providers.dart` (`claimPassReward`/`claimAllPassRewards`/`passClaimableCount`) | §11 Phase 5 |
| **Pass-exclusive cosmetics** — 5 free-track + 12 VIP-track items that exist nowhere else: `inShop: false`, priced 0, `passExclusive: true`, so `kRollableCatalog` drops them and no sphere or devotion roll can hand one out | `data/pass_catalog.dart`, `models/shop_item.dart` (`passExclusive`), `data/shop_catalog.dart` (`kRollableCatalog`) | §7 |
| **Collection** — "collect them all" gallery of every cosmetic (owned in colour, locked items greyed), with a completion % — fed by Shop + Spheres + Pass | `features/collection/`, Home app bar 🔲 | §6/§7 |
| **Settings** — daily-goal picker, privacy note, reset progress | `features/settings/` | — |
| **Onboarding** — consent-first health opt-in with a Skip path | `features/onboarding/` | §3.6 |

## Feedback (beta)

| Feature | Where | Doc |
|---|---|---|
| **Report a bug / suggest a feature** — Bug · Idea · Other; body ≤ `kFeedbackMaxChars` (1,000), optional email ≤ `kFeedbackContactMaxChars` (120) and only if you want a reply; the bug prompt asks what you were doing just before | `core/feedback.dart`, `features/feedback/feedback_screen.dart` | — |
| **Offline-first outbox** — the report is saved to the device **first** (own key `twc_feedback_v1`, never the synced player blob) and sent after, so the button promises *saved*, not delivered — testers hit bugs exactly when the network is misbehaving. There is no `failed` status: an undelivered report stays `pending`, carries the reason in its history row, and is retried on app launch and on opening the screen. Newest 30 kept as the player's receipt | `state/feedback_providers.dart` (`FeedbackController`, `pendingFeedbackCountProvider`), `features/shell/root_scaffold.dart` (launch flush) | — |
| **Diagnostics disclosed in full** — an expandable "What gets attached" panel lists all **11** values before you send (app version, platform, OS, health level, lifetime Pebbles, steps today, streak, pass level, VIP, health sync, backend), snapshotted at submit so walking on can't rewrite an old report; never journal/prayer text, the account code, the username, or a contact you didn't type (design invariant #3, [`GAME_MECHANICS.md`](GAME_MECHANICS.md)) | `state/feedback_providers.dart` (`currentDiagnostics`), `core/app_info.dart` (`kAppVersion`, pinned to `pubspec.yaml` by a test) | — |
| **Settings entry point** — "Report a bug or suggest a feature" under a **Feedback** header, with a **badge** and "*n* waiting to send" whenever anything is queued | `features/settings/settings_screen.dart` | — |

Sending is the one part that needs the deployed backend
([`../supabase/feedback.sql`](../supabase/feedback.sql), documented in
[`BACKEND.md`](BACKEND.md)); with no Supabase configured the reports just stay
queued. Every report carries a client-generated id the server dedupes on, so a
retry after a timeout that actually landed can't file it twice.


## Crash reporting (beta)

| What | Where | Doc |
|---|---|---|
| Global Dart error capture — `FlutterError.onError` + `PlatformDispatcher.onError`, installed in `main()` | `core/crash_reporter.dart`, `main.dart` | — |
| Fingerprint + repeat collapsing, message/stack trimming | `core/crash.dart` | — |
| Offline outbox, opt-out toggle, dedupe by bug | `state/crash_providers.dart` | — |
| Settings → Diagnostics toggle, queued count, dev test trigger | `features/settings/settings_screen.dart` | — |

Both handlers are **additive**: they record, then pass the error to whatever
would have handled it, so the red screen and the console output are unchanged —
a reporter that hides errors from the developer is a net loss. Repeats of one
bug collapse into a single report with an occurrence count, which is what keeps
a per-frame layout error from flooding disk and server alike.

Scope: **Dart** errors only (exceptions, bad state, null derefs, layout,
unhandled async). A native crash kills the process before Dart runs — that needs
a native SDK, and none is bundled. Sending needs the backend
([`supabase/crash.sql`](../supabase/crash.sql), [`BACKEND.md`](BACKEND.md) §11);
without it reports queue on the device. Off by a switch in
**Settings → Diagnostics**, and declared on the Play Data Safety form either
way ([`PLAY_LISTING.md`](PLAY_LISTING.md) §2).
## Anti-double-count note (important)
Quest rewards add **bonus** Steps to `lifetimeSteps`; they never re-credit walked
steps and don't touch `todaySteps`, so claiming can't inflate quest progress or
break the "1 real step = 1 Step" promise (doc §2.4 double-count rule).

---

## Navigation map

- **Bottom nav:** Home · Quests · **Pass** · Shop · Profile — the Pass tab carries
  a badge with the number of unclaimed pass rewards (`passClaimableCount`)
- **Profile tabs:** Avatar (character customiser) · Home (room decor)
- **Home app bar:** 🔲 Collection · 🏆 Trophy Room · ⚙️ Settings · 🔄 Sync
- **Home cards:** avatar · today/lifetime/spendable · daily-goal+streak · pet · wallet

---

## Not yet built (roadmap, doc §11)

- **Phase 1:** server-authoritative currency, auth (Firebase/Supabase), anti-cheat v1 — see [`BACKEND.md`](BACKEND.md) for the setup plan & provider choice
- **Phase 2 (remaining):** seasonal events, richer home/character catalogs, live pedometer tick
- **Phase 3:** friends, home visits, leaderboards, gifting
- **Phase 4:** **TURBO** — live GPS session (distance, route, pace), the only GPS release
- **Phase 5:** guilds/pooling, prestige tiers *(cosmetic pass + boosts: built)*

The Home screen shows a disabled **TURBO — coming in Phase 4** button as a
placeholder; no GPS/location code or permissions exist yet, by design.
