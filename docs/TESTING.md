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
