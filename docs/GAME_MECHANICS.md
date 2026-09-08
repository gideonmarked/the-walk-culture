# Game Mechanics — The Walk Culture

The canonical reference for how the game works. Numbers here are pulled from the
code (constants cited inline); if they drift, the code wins — update this doc.

---

## Core loop

**Walk → earn currency → grade your health → open rewards → dress up your
character → keep the streak.** Real steps drive everything; spending is cosmetic.

The guiding principle, enforced throughout: **money and ads never buy a health
outcome.** Purchased and ad-earned currency is spendable on cosmetics only —
your character's health level can be raised *only* by walking.

---

## 1. Steps → currency

- Steps read from Health Connect (Android) / a live pedometer are banked as
  **lifetime steps**. Currency is **derived**: `spendable = lifetime − spent`.
- **Currency ladder — 100× per tier** (`kTierMultiplier = 100`):

  | Tier | Pebbles | Tier | Pebbles |
  |---|---|---|---|
  | Pebbles | 1 | Titanium | 100,000,000 |
  | Copper | 100 | Platinum | 10¹⁰ |
  | Silver | 10,000 | Tanzanite | 10¹² |
  | Gold | 1,000,000 | Emerald | 10¹⁴ |
  | | | Ruby | 10¹⁶ |
  | | | Diamond | 10¹⁸ |

- The wallet shows per-tier balances (base-100 positional split of spendable).

## 2. Health ladder

Your character's wellbeing tracks yours. Graded **once per day** from that day's
steps (`kHoldSteps = 5000`, `kClimbSteps = 10000`):

- **< 5,000** → slip down one level
- **5,000–9,999** → hold your level
- **≥ 10,000** → climb one level

Seven levels, worst → best; new players start at **Steady** (`kStartHealthLevel = 3`).
The names run on a walking-pace theme, and the character's **posture** rises with
them — from laying on the floor, through crawling and hunching, up to walking
tall (the top pose animated later):

`Idle · Sluggish · Strolling · Steady · Brisk · Swift · Soaring`
`(laying → crawling → hunched → upright walking →→ striding)`

Never more than one level of movement per day, clamped at both ends. It is
**not** a user-set goal — the thresholds are fixed. (Planned: the character's
*posture* rises with this ladder — laying → crawling → hunched → walking upright,
top pose animated — see [`PIXEL_ART_GUIDE.md`](PIXEL_ART_GUIDE.md).)

## 3. Streaks

A day "counts" once it clears **5,000 steps**. Consecutive counting days build
the 🔥 streak; a gap resets the current streak but keeps your best.

## 4. Daily quests

Three fixed quests, reset daily, each paying **bonus Pebbles** on claim:

| Quest | Target | Reward |
|---|---|---|
| Walk 3,000 steps | 3,000 | +200 |
| Hold your health | 5,000 | +500 |
| Climb a health level | 10,000 | +1,000 |

## 5. Mystery Spheres

Step-gated loot boxes with **published odds** (shown in-app — required by Play
and honest). **Strictly sequential:** only the next unopened tier is offered;
opening it reveals the one after. Opened tiers move to an "Opened today" summary.
Resets daily.

| Sphere | Unlock (steps) | Base rarity |
|---|---|---|
| Bronze | 3,000 | Common |
| Silver | 5,000 | Uncommon |
| Gold | 10,000 | Rare |
| Platinum | 16,000 | Epic |
| Diamond | 21,000 | Legendary |
| Mythic | 50,000 | Legendary |
| Celestial | real-money | Celestial |

Opening rolls a rarity from the tier's odds, then grants a **random unowned shop
item** of that rarity — or, if you already own everything at that rarity, a
**currency fallback** (Common 500 → Uncommon 2,000 → Rare 10,000 → Epic 50,000 →
Legendary 200,000 → Celestial 1,000,000 Pebbles). Celestial is real-money only and
has **guaranteed** contents (never a paid random box — keeps clear of loot-box
law).

## 6. Trophies

**33 achievements**, four difficulty bands, each with a claimable **Pebble reward**
(claim once — permanent, never re-pays):

| Difficulty | Reward |
|---|---|
| Easy | +500 |
| Medium | +2,500 |
| Hard | +10,000 |
| Elite | +50,000 |

The full list (locked + unlocked) lives under **Quests**; the **Trophy Room**
shows only what you've earned — a display case.

## 7. Shop & rarity gating

**592 items** across all character/pet/home slots. Rarity is colour-coded and
**gated by wallet tier** — you can only buy a rarity once you've *banked* its
currency tier (enforced server-side too, not just hidden in the UI):

| Rarity | Priced in | Reach to unlock |
|---|---|---|
| Common | Pebbles | — |
| Uncommon | Copper | 100 |
| Rare | Silver | 10,000 |
| Epic | Gold | 1,000,000 |
| Legendary | Titanium | 100,000,000 |

A **prestige line** sits above Gold (Titanium → Diamond) — aspirational flex
items. Most of the catalogue is generated as colour variants (a colour implies a
rarity: plainer = common, "Golden" = the epic of its set). Reward-only sphere
loot exists in the catalogue but is `in_shop = false` (never purchasable), and so
do the 17 Travel Pass exclusives (§12).

## 8. Earning boost

A **2× earning** boost for **1 hour**. Stacks *multiplicatively* with VIP's
always-on 2× → up to **4×** for a VIP who also pops a boost.

## 9. Character & home

Paper-doll customisation: equip one cosmetic per slot
(`base · bottom · top · shoes · face · hair · hat · accessory · pet`), composited
back→front. Home decor is placed in a room (room scene still a placeholder). Art
spec + the health posture system: [`PIXEL_ART_GUIDE.md`](PIXEL_ART_GUIDE.md).

## 10. Spiritual disciplines

Four optional daily practices, each once per day, each granting a **quiet**
cosmetic reward (the practice is the point — rewards never gate the best gear):

| Practice | Time / effort | Reward |
|---|---|---|
| **Bible verse** | 60-second read timer | random shop item (Common 68% → Legendary 0.5%) |
| **Pray for someone** | 2-minute timer | random item, slightly kinder odds |
| **Prayer walk** | 1,000 steps (prompt every 200) | random item, kinder odds |
| **Gratitude journal** | name 3 thankful-fors | **always a Common item** |
| **Prayer requests** | pray for a stranger / send your own | reward **every** prayer, capped 5/day |

**Privacy:** gratitude entries and the private prayer names are personal
religious reflection (a GDPR *special category*), so they are stored
**on-device only** and never uploaded — a test asserts they can't leak into the
synced save. Bible verses are bundled public-domain **KJV**; live ESV would
require a licensed API proxied through the backend (never bundled — ESV is
copyrighted).

### Prayer requests — the one shared faith feature

A separate, deliberately-consented, **anonymous** wall (needs the backend live):

- **Pray for a request** — a *second* button runs a **server-side randomiser**
  *only when tapped*, handing you one visible request that isn't yours and that
  you haven't prayed for. Tapping **I prayed** counts server-side (idempotent)
  and grants a quiet reward **every time**, capped at
  `kRewardedRequestPrayersPerDay = 5` a day so it can't be farmed.
- **Send a request** — shared anonymously after an explicit consent notice,
  **max `kMaxPrayerRequestsPerWeek = 2` per rolling 7 days** (server-enforced),
  `≤ 280` chars.
- **Safety:** the request body is free text, so every card has a **Report**
  button; a request auto-hides once `kPrayerRequestReportThreshold = 3` distinct
  people flag it. The author is stored only for rate-limiting and is **never**
  returned to readers — RLS locks the tables and all access goes through
  `SECURITY DEFINER` functions (see [`../supabase/prayer_requests.sql`](../supabase/prayer_requests.sql)).
- This is the explicit-consent exception invariant #3 allows; it never touches
  the private on-device journal.

## 11. Monetization

- **VIP subscription** (weekly / monthly / annual): always-on **2×** earning,
  **+5,000 daily stipend** (`kVipDailyStipend`), **+1 daily ad**, profile badge.
  Server-authoritative — the app can't grant itself VIP.
- **Currency packs** (consumable IAP): Pouch 10k, Sack 60k, Chest 150k, Vault
  400k Pebbles. Prices display in the **user's local currency** (Google Play
  localises `ProductDetails.price` by region).
- **Rewarded ads** (Google AdMob): **+20,000 Pebbles** (2 Silver) per watch, cap
  **5/day** (6 for VIP), **enforced server-side** (`claim_ad_reward`). Real ads
  are gated behind **GDPR consent** (UMP) and a `REAL_ADS` build flag; dev builds
  serve test ads. Purchases validated **server-side** (receipt → Edge Function →
  grant); release never uses the simulator.

## 12. Travel Pass

A **seasonal reward track** — 30 levels, two columns. Everyone climbs the same
ladder by walking; VIP unlocks the second column of rewards on it. Season maths,
level maths and the reward table live in `core/travel_pass.dart`.

**Seasons** — `kSeasonDays = 60`, **derived** from a fixed UTC epoch
(`kSeasonEpoch`, 2026-01-05) instead of stored, so every device — and later the
server — agrees on which season it is with no round trip; UTC so crossing a
timezone can't bounce you between seasons. Ids are `s<index>`, and each season
takes its name from a cycling theme list (`kSeasonThemes` → "Season 3 — Highland
Trail") so seasons keep coming without a content drop.

**Levels** — `kPassLevelCount = 30` at a **flat** `kPassLevelXp = 8,000` XP
each: **240,000 XP** a season, ≈ **4,000 steps/day**. That sits *under* the
5,000 that holds your health level (§2), so anyone keeping their ladder steady
finishes the pass. Flat, not a curve — a rising cost makes the last levels a
grind, and the promise worth making is "walk this much a day and you finish". XP
stops banking at level 30 (the header reads *Track complete*).

**XP is raw walked steps.** VIP's always-on 2× and the §8 boost multiply
**currency**, never pass XP — `syncSteps` credits the multiplied total but hands
`_addPassXp` the unmultiplied step delta — and bought or ad-watched currency
earns no XP whatsoever. Otherwise money would buy progress on the ladder and
"1 real step = 1 step" would stop being true: **VIP buys a better reward column,
never a faster climb.** Small top-ups let the rest of the loop feed the pass, so
a rest day still inches forward:

| Source | XP |
|---|---|
| a walked step | **1** |
| daily quest claimed | +100 (`kPassXpPerQuest`) |
| devotion reward taken (§10) — Bible, prayer, prayer walk, gratitude, or a rewarded prayer-request prayer | +100 (`kPassXpPerDevotion`) |
| Mystery Sphere opened | +50 (`kPassXpPerSphere`) |

Deliberately tiny beside 8,000 a level — walking stays the way you climb, and
devotions never become the fast lane (invariant #6).

**The two columns** (`kPassTrack` — 30 rungs, every cell named up front):

| Column | What's on it |
|---|---|
| **Free** | 19 Pebble rungs (**55,000** Pebbles a season) + **5** pass-exclusive cosmetics, at levels 5 · 12 · 20 · 25 · 30. Six rungs (4, 8, 14, 17, 22, 27) are VIP-only and sit empty on the free side. |
| **VIP** | **Never empty** — it's the thing being paid for: **12** pass-exclusive cosmetics (rarity climbing to two Celestials at 29/30), 5 boost grants (**18h** total), 13 fatter Pebble bags (**98,000** Pebbles). |

Claiming:

- A VIP cell needs the level reached **and** VIP active at claim time. VIP is
  server-owned (`fetchVipUntil`), so exclusivity keys off a server-authoritative
  entitlement, not a client flag (invariant #2).
- **Retro-claimable:** subscribe at level 22 and the whole VIP column you already
  walked past unlocks at once ("Claim all *n* rewards"). Subscribing late costs
  you nothing you earned — which is why a locked VIP cell offers the store
  instead of being a dead tap.
- Rewards already claimed are yours for good; when VIP lapses the column simply
  stops opening.
- One claim per cell per season (`claimedPassFree` / `claimedPassVip` hold level
  numbers as strings), and the claim is stamped **before** the reward is paid, so
  a double-tap can't pay twice.
- A boost reward **extends** a running boost rather than overwriting it (unlike
  §8's own button) — a reward you walked for shouldn't be thrown away.

**Exclusivity** — the 17 pass cosmetics (`data/pass_catalog.dart`) are
`inShop: false`, priced **0**, and `passExclusive: true`. That last flag is what
drops them from `kRollableCatalog`, the pool spheres and devotion rolls draw
from; without it a lucky sphere could hand out a VIP-track item for free and
"exclusive" would be a lie. They still sit in `kShopCatalog`, so Collection,
equip and the compositor find them by id — and they count toward Collection
completion.

**Against the invariants (§16):** every rung is named and guaranteed, so there is
no random box anywhere on the track, paid or free (#5) — nothing here needs an
odds table. Pass Pebbles credit spendable currency only, never `todaySteps` and
never the health ladder (#1), exactly like an IAP or ad grant.

## 13. Social

- **Account code** — a stable 7-char code (e.g. `A7A43B7`, ambiguous chars
  excluded) minted once per account. Add friends by **code or username**.
- **Groups** — your **1st group is free**; the 2nd/3rd/4th cost **50k / 200k /
  500k** Pebbles, doubling beyond (a deliberate nudge toward real-money currency).
  Charged server-side.
- **Group house** — a shared room each member improves with **their own**
  currency (placeholder screen; schema in place).

Multiplayer requires the deployed Supabase backend; the account code and cost
previews work offline.

## 14. Resets — what resets vs. what's permanent

**Day roll** — at the first state change after midnight:

- **Resets:** today's steps, daily quest claims, opened spheres + their summary,
  and each devotion's daily availability. The health level is **graded** from the
  finishing day's steps *before* today's count is cleared.

**Season roll** — at the first state change after a 60-day season ends
(`_rollSeasonIfNeeded` compares the derived season id against the stored
`passSeasonId`, the same shape as the day roll):

- **Resets:** pass XP (back to level 0) and both claim sets — the next track is
  walked from scratch. **Unclaimed rewards are lost**, so claim before the clock
  runs out; the season header carries the days left. A save with no season
  stamped yet (pre-pass, or brand new) is stamped silently rather than announcing
  a rollover that never happened.
- **Kept:** everything already claimed — cosmetics, Pebbles, boost hours — since
  those land in the normal inventory and wallet, not in pass state.

**Permanent (never reset):** lifetime steps, spent steps, wallet, inventory, best
streak, **claimed trophies**, claimed pass rewards, account code, VIP
entitlement.

## 15. Notifications

An in-app **inbox** (bell + unread badge on Home) mirrored to the phone's
**notification tray** (`flutter_local_notifications`; Android 13 asks for
POST_NOTIFICATIONS on first launch). Entries persist locally in their own key
(`twc_notifications_v1`), never synced, capped at the newest 50. Each event has a
**stable id** so re-checking the same milestone can't notify twice.

Sources today:

| Kind | Fires when |
|---|---|
| Reward | you bank into a new currency tier |
| Reward | you reach a new **Travel Pass** level — or finish the track (§12) |
| Reward | a new pass season begins, i.e. the old track has just rolled over |
| Health | yesterday's steps climb or slip your level (once/day) |
| Devotion | a new day's practices are ready (once/day) |
| Social | someone prays for one of **your** shared requests |

The social one is server-backed: on open the app reads the total prayers across
your own requests (`my_requests_pray_total`) and notifies on any increase since
last seen (first sight baselines silently). It's a no-op offline and lights up
once Supabase is live. Remote push while the app is fully closed (FCM) is a
later phase. A dev-only "send test notification" action lives in the inbox when
`kDevToolsEnabled`.

## 16. Design invariants (don't break these)

1. **Money/ads buy cosmetics, never health.** Purchased, ad-earned and Travel
   Pass currency goes to spendable currency only, never to `todaySteps` or the
   health ladder. Pass XP is raw walked steps, so no multiplier buys the climb.
2. **The server owns the money.** VIP, ad caps, group costs, and purchase grants
   are validated server-side; the client can't grant itself currency or
   entitlements. (Wallet-from-steps is not yet server-authoritative — the open
   anti-cheat milestone.)
3. **Reflections stay on the device.** Never sync gratitude/prayer content
   without separate explicit consent. The **one** consented exception is the
   anonymous prayer-request wall (§10): opt-in per request, no author ever
   exposed, never drawn from the private journal.
4. **Published odds.** Any randomised reward shows its drop rates.
5. **No paid random boxes.** Real-money spheres have guaranteed contents, and
   the Travel Pass is named end to end — no boxes on either column (§12).
6. **Devotion rewards stay gentle.** Spiritual practices never become the fastest
   or only path to the best gear.
