# Testing Guide

**Android is the primary test platform for now.** iOS testing waits until we
build on a Mac (see [`IOS.md`](IOS.md)). This guide covers automated tests and a
manual device test plan for the passive-steps loop.

---

## 1. Automated tests

Run from the project root (Flutter is in the WSL "Ubuntu" distro):

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
flutter analyze          # static analysis — must be clean before committing
flutter test             # unit + widget tests
flutter test --coverage  # writes coverage/lcov.info
```

### Test layers

| Layer | Location | What it covers |
|---|---|---|
| **Unit** | `test/*_test.dart` | pure logic: currency ladder, wallet math, streak rules, purchase affordability |
| **Widget** | `test/widget/*_test.dart` | screens render + react to state (buy disables when unaffordable, equip updates avatar) |
| **Integration** | `integration_test/` | full loop on a real device/emulator (steps → buy → equip → persist) |

### Key unit tests to keep green
- `test/currency_test.dart` — `toWallet()` base-1000 split, `priceInSteps()`.
- `test/streak_test.dart` — streak increments on consecutive goal days, resets on a gap, updates best.
- Purchase logic — cannot buy when `spendableSteps < cost`; cannot re-buy owned.
- `test/travel_pass_test.dart` — pass XP is **raw walked steps** (VIP/boost and
  bought/ad steps must never move the track), the VIP column locks and
  retro-unlocks, a reward pays once, seasons roll over, and no pass cosmetic
  can reach `kRollableCatalog`. `test/travel_pass_screen_test.dart` covers the
  screen + the nav badge.
- `test/feedback_test.dart` / `test/crash_test.dart` — the two outboxes: a
  report is stored before it's sent, an **unsent** one is never evicted to make
  room, writes wait on the disk load, and a crash that fires every frame
  collapses into ONE report with a count.

### Integration test (on a device)
```bash
flutter test integration_test -d <device-id>
```

---

## 2. Manual device test plan (Android)

Do these on a **physical Android phone** (sensors don't exist on emulators). Use
the **+500 steps (simulate)** button where noted so you don't have to walk.

### A. Onboarding & permissions (doc §3.6)
1. Fresh install → onboarding screen explains the value **before** any OS prompt.
2. Tap connect → Activity Recognition prompt → Health Connect steps prompt.
3. **Deny** everything → app still opens; simulate button still earns. ✅ no crash.
4. Re-open Health Connect, grant steps → **Sync** on Home credits real steps.
5. Health Connect not installed → app deep-links / prompts to install it.

### B. Earning (passive, doc §2.4 Layer 1)
6. Walk ~100 steps with the phone → reopen app → tap **Sync** → lifetime +≈100.
7. Only the **delta** is credited (syncing twice with no new steps adds nothing).
8. Simulate +500 five times → 2,500 steps → wallet shows **2 Copper, 500 Steps**.
9. Force-close and reopen → balance persisted (SharedPreferences).

### C. Daily goal & streak
10. Set a low daily goal in Settings (e.g. 300). Earn past it → streak = 1.
11. (Advance device date +1 day, meet goal) → streak = 2; skip a day → resets to 1.
12. Streak-best never decreases.

### D. Shop / wardrobe / home
13. Buy an affordable item → currency deducts; item leaves the "Buy" state.
14. Unaffordable item → **Buy is disabled**.
15. Cannot buy an owned item twice.
16. Equip a hat/shoes → **avatar updates** on Home & Character.
17. Unequip → avatar reverts.
18. Buy home decor → **place** it in the House room; remove it → disappears.

### E. Persistence & edge cases
19. Kill + relaunch after each of B/C/D → all state persists.
20. Airplane mode → passive steps still read from Health Connect (no network needed).
21. Change device date backward → app doesn't grant negative/huge deltas
    (delta clamped at ≥ 0; server-side plausibility caps come in Phase 1).

### F. Travel Pass (doc §12)
Fastest route: dev build, simulate 8,000 steps per level.
22. Simulate 8,000 → **Pass** tab badges **1**; header reads Level 1 and the
    season's countdown.
23. Claim the level 1 free reward → currency/item lands, cell shows claimed,
    badge clears. Tap it again → nothing (a reward pays once).
24. Simulate to level 3+ **without VIP** → the VIP column stays locked at every
    rung; tapping a locked cell explains what's behind it and offers the Store.
25. Buy VIP in the Store → return to Pass → **every VIP reward already earned is
    claimable** (retro-unlock), the upsell strip is gone, "Claim all" appears.
26. **Claim all** → one sweep pays every open cell on both columns; a VIP
    cosmetic appears in Collection and equips on the avatar.
27. Let VIP lapse (or clear it in the dev tools) → already-claimed VIP rewards
    stay owned; unclaimed ones re-lock.
28. Watch a rewarded ad / buy a Pebble pack → currency rises, **pass XP does
    not move** (money must not buy the climb).
29. Open Mystery Spheres and every daily practice repeatedly → a pass-exclusive
    cosmetic never drops (they are excluded from the roll pool).
30. Change the device date forward past the season end → next state change rolls
    the season: level back to 0, claims cleared, "A new Travel Pass season" in
    the inbox — and items/currency already granted are **still there**.

### G. Feedback outbox (beta, [`FEATURES.md`](FEATURES.md))
Steps 31–34 work local-only; step 35 needs a build with the Supabase defines
([`DEPLOY.md`](DEPLOY.md)) so a report can actually land.
31. Settings → **Report a bug or suggest a feature** → expand **What gets
    attached** *before* sending. It lists the 11 build/progress values (App
    version, Platform, OS, Health level, Lifetime Pebbles, Steps today, Streak,
    Travel Pass, VIP, Health sync, Backend) and **nothing else** — no gratitude
    entry, no prayer text, no account code, no username, and no email unless
    you typed one. App version must match `pubspec.yaml`.
32. **Airplane mode ON** → type a bug → **Send**. The confirmation says
    **saved** ("It'll send when you're back online"), *not* sent, and the report
    appears under **Your reports** with the clock marker and "Waiting for a
    connection".
33. Force-close and relaunch, still offline → the report is **still listed and
    still waiting**. It lives in its own `twc_feedback_v1` key, so a cloud
    restore of the player save neither carries nor clears it.
34. Back in Settings → the **Feedback** row shows a badge with the pending count
    and "*n* waiting to send". File a second report → the badge reads **2**.
35. Airplane mode **off** → relaunch (or just reopen the feedback screen, both
    retry) → both rows flip to the sent tick and the Settings badge clears.
    Check the Supabase `feedback` table: **one row per report** — retries dedupe
    on the client id, so a resend after a timeout must never double-file.

### H. Crash reporting (beta)
Needs a dev build (`--dart-define=DEV_TOOLS=true`) for the test trigger.
36. **Settings → Diagnostics** shows **Send crash reports**, on by default.
37. Tap **Record a test error (dev)** → the subtitle above ticks to
    "1 waiting to send". Force-close, reopen → still counted (it's on disk).
38. Tap it **twenty times** → the count stays at **1**. Repeats of one bug
    collapse into a single report with an occurrence count; this is what stops
    a per-frame layout error flooding the queue.
39. With the backend configured, relaunch → the count clears and **one** row
    appears in `crash_report` with `occurrences` matching your taps.
40. Turn the toggle **off**, trigger again → nothing is recorded and nothing is
    queued.
41. Cause a *real* error (a dev build with a deliberate throw in a `build`
    method): confirm the red error screen **still appears** and the console
    still logs it. The handlers must only add recording, never swallow.

---

## 3. Injecting step data for testing

- **Easiest:** the in-app **+500 steps (simulate)** button (no permission needed).
- **Real Health Connect data:** walk with the phone, or use another fitness app
  that writes to Health Connect, then **Sync**.
- **Manual entries are filtered** as anti-cheat (doc §3.5) — note that on Android
  the manual/unknown distinction is leaky, so don't rely on manual entry to test
  the "credited" path; use real motion or the simulator.

---

## 4. Anti-cheat checks (design-level, doc §4.1)

Client-side today: only OS-recorded steps, delta clamped ≥ 0. **Server-side
plausibility caps (per-hour/per-day) and the ~10.5 km/h speed cap arrive with the
Phase 1 backend and Phase 4 TURBO** — track those as separate test suites when built.

---

## 5. CI (later)

When a backend/CI is added, wire `flutter analyze` + `flutter test` into the
pipeline and block merges on failure. Keep health/GPS code paths behind the
`null`-fallback so tests run headless without sensors.
