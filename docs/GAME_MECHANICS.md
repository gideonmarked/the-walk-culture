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

  | Tier | Steps | Tier | Steps |
  |---|---|---|---|
  | Steps | 1 | Titanium | 100,000,000 |
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
The names run on a walking-pace theme, and the character's body shifts obese→fit
across them:

`Idle · Sluggish · Strolling · Steady · Brisk · Swift · Soaring`

Never more than one level of movement per day, clamped at both ends. It is
**not** a user-set goal — the thresholds are fixed. (Planned: the character's
*body shape* shifts obese→fit with this ladder — see
[`PIXEL_ART_GUIDE.md`](PIXEL_ART_GUIDE.md).)

## 3. Streaks

A day "counts" once it clears **5,000 steps**. Consecutive counting days build
the 🔥 streak; a gap resets the current streak but keeps your best.

## 4. Daily quests

Three fixed quests, reset daily, each paying **bonus steps** on claim:

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
Legendary 200,000 → Celestial 1,000,000 steps). Celestial is real-money only and
has **guaranteed** contents (never a paid random box — keeps clear of loot-box
law).

## 6. Trophies

**33 achievements**, four difficulty bands, each with a claimable **step reward**
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

**575 items** across all character/pet/home slots. Rarity is colour-coded and
**gated by wallet tier** — you can only buy a rarity once you've *banked* its
currency tier (enforced server-side too, not just hidden in the UI):

| Rarity | Priced in | Reach to unlock |
|---|---|---|
| Common | Steps | — |
| Uncommon | Copper | 100 |
| Rare | Silver | 10,000 |
| Epic | Gold | 1,000,000 |
| Legendary | Titanium | 100,000,000 |

A **prestige line** sits above Gold (Titanium → Diamond) — aspirational flex
items. Most of the catalogue is generated as colour variants (a colour implies a
rarity: plainer = common, "Golden" = the epic of its set). Reward-only sphere
loot exists in the catalogue but is `in_shop = false` (never purchasable).

## 8. Earning boost

A **2× earning** boost for **1 hour**. Stacks *multiplicatively* with VIP's
always-on 2× → up to **4×** for a VIP who also pops a boost.

## 9. Character & home

Paper-doll customisation: equip one cosmetic per slot
(`base · bottom · top · shoes · face · hair · hat · accessory · pet`), composited
back→front. Home decor is placed in a room (room scene still a placeholder). Art
spec + the health body-morph system: [`PIXEL_ART_GUIDE.md`](PIXEL_ART_GUIDE.md).

## 10. Spiritual disciplines

Four optional daily practices, each once per day, each granting a **quiet**
cosmetic reward (the practice is the point — rewards never gate the best gear):

| Practice | Time / effort | Reward |
|---|---|---|
| **Bible verse** | 60-second read timer | random shop item (Common 68% → Legendary 0.5%) |
| **Pray for someone** | 2-minute timer | random item, slightly kinder odds |
| **Prayer walk** | 1,000 steps (prompt every 200) | random item, kinder odds |
| **Gratitude journal** | name 3 thankful-fors | **always a Common item** |

**Privacy:** gratitude entries and prayer names are personal religious
reflection (a GDPR *special category*), so they are stored **on-device only** and
never uploaded — a test asserts they can't leak into the synced save. Bible
verses are bundled public-domain **KJV**; live ESV would require a licensed API
proxied through the backend (never bundled — ESV is copyrighted).

## 11. Monetization

- **VIP subscription** (weekly / monthly / annual): always-on **2×** earning,
  **+5,000 daily stipend** (`kVipDailyStipend`), **+1 daily ad**, profile badge.
  Server-authoritative — the app can't grant itself VIP.
- **Currency packs** (consumable IAP): Pouch 10k, Sack 60k, Chest 150k, Vault
  400k steps. Prices display in the **user's local currency** (Google Play
  localises `ProductDetails.price` by region).
- **Rewarded ads** (Google AdMob): **+20,000 steps** (2 Silver) per watch, cap
  **5/day** (6 for VIP), **enforced server-side** (`claim_ad_reward`). Real ads
  are gated behind **GDPR consent** (UMP) and a `REAL_ADS` build flag; dev builds
  serve test ads. Purchases validated **server-side** (receipt → Edge Function →
  grant); release never uses the simulator.

## 12. Social

- **Account code** — a stable 7-char code (e.g. `A7A43B7`, ambiguous chars
  excluded) minted once per account. Add friends by **code or username**.
- **Groups** — your **1st group is free**; the 2nd/3rd/4th cost **50k / 200k /
  500k** steps, doubling beyond (a deliberate nudge toward real-money currency).
  Charged server-side.
- **Group house** — a shared room each member improves with **their own**
  currency (placeholder screen; schema in place).

Multiplayer requires the deployed Supabase backend; the account code and cost
previews work offline.

## 13. Daily reset — what resets vs. what's permanent

At the first state change after midnight (the "day roll"):

- **Resets:** today's steps, daily quest claims, opened spheres + their summary,
  and each devotion's daily availability. The health level is **graded** from the
  finishing day's steps *before* today's count is cleared.
- **Permanent (never reset):** lifetime steps, spent steps, wallet, inventory,
  best streak, **claimed trophies**, account code, VIP entitlement.

## 14. Design invariants (don't break these)

1. **Money/ads buy cosmetics, never health.** Purchased/ad steps go to spendable
   currency only, never to `todaySteps` or the health ladder.
2. **The server owns the money.** VIP, ad caps, group costs, and purchase grants
   are validated server-side; the client can't grant itself currency or
   entitlements. (Wallet-from-steps is not yet server-authoritative — the open
   anti-cheat milestone.)
3. **Reflections stay on the device.** Never sync gratitude/prayer content
   without separate explicit consent.
4. **Published odds.** Any randomised reward shows its drop rates.
5. **No paid random boxes.** Real-money spheres have guaranteed contents.
6. **Devotion rewards stay gentle.** Spiritual practices never become the fastest
   or only path to the best gear.
