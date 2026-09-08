# Play Store submission pack

Everything Play Console asks for, pre-answered to match what the app **actually**
does. Copy/paste as you fill the forms.

> **Not legal advice.** These are accurate technical answers written by reading
> the code. A health app that takes payments and may attract minors is worth a
> real review before you publish.

---

## 1. Privacy policy URL — **required**

Hosted from this repo at no cost:

```
https://gideonmarked.github.io/the-walk-culture/privacy.html
```

Enable it once: **repo → Settings → Pages → Source: “Deploy from a branch” →
Branch `main`, folder `/docs` → Save.** Live in ~1 minute.

Source: [`privacy.html`](privacy.html). Keep it accurate — Play checks that the
policy matches the Data Safety form, and a mismatch is a rejection.

---

## 2. Data Safety form

**Does your app collect or share any of the required user data types? → Yes**

| Question | Answer |
|---|---|
| Is all data encrypted in transit? | **Yes** (HTTPS) |
| Can users request data deletion? | **Yes** (email; uninstall clears local) |

### Data types to declare

| Type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| **Health & fitness → Health info** (step count) | Yes | No | App functionality | Required* |
| **App activity → In-app actions** (progress, purchases) | Yes | No | App functionality | Required |
| **App info & performance → Crash logs** | **Yes** | No | Diagnostics (crash fixing) | **Yes** — Settings toggle |
| **App info & performance → Diagnostics** | **Yes** | No | Diagnostics | Yes — same toggle / not sending feedback |
| **Messages → Other in-app messages** (feedback body, prayer requests) | **Yes** | No | App functionality, customer support | Yes — only what the user types and sends |
| **Personal info → Email address** | **Yes, optional** | No | Customer support (replying to feedback) | **Yes** — blank by default |
| **Device or other IDs** (advertising ID) | **Only once AdMob ships** | Yes → Google | Advertising | Yes (optional) |
| **Personal info** (name) | **No** | No | — | — |
| **Location** | **No** | No | — | — |
| **Financial info** (card details) | **No** — Google Play handles payment | No | — | — |

\* Health data is "required" for the core loop, but the user can decline the
permission and the app still runs (it just can't count steps).

> **Anonymous account ID:** a random UUID, not linked to a person. It is not
> "Personal info" under Play's definitions, but declare it as an **identifier**
> if you later link accounts to email/Google sign-in.

> **Update this the day AdMob goes live.** Ads add the advertising ID, and
> shipping ads without declaring it is a policy violation.

> **What the last four rows actually cover.** Crash reports (`supabase/crash.sql`)
> carry an error message, a trimmed stack, and the same build/progress context
> the feedback form lists on screen — user-visible and switchable off under
> **Settings → Diagnostics → Send crash reports**. A feedback report
> (`supabase/feedback.sql`) carries what the player typed plus that same
> context, and an email **only** if they filled the optional field. Neither
> ever carries gratitude or prayer text (design invariant #3).
>
> **The prayer-request wall was already sending user-authored text** before
> either of these landed and is not declared in the table above — that gap
> predates this change, so the "Other in-app messages" row now covers it too.
> Confirm the exact category names in the console as you fill the form; Play's
> taxonomy shifts, and "Other in-app messages" is the closest bucket for
> text a user writes and sends to the developer rather than to another user.

---

## 3. Health Connect declaration — **required, and strict**

Google reviews every Health Connect app by hand. You must justify each data type.

**Data types requested: `READ_STEPS` only.**

> Justification: The Walk Culture converts the user's daily step count into an in-game
> currency. The step total is the app's core mechanic — it determines the
> currency earned, the character's health level, daily quest progress, and
> streaks. No other health data type is read. Steps are read only for the
> current day, in the foreground, while the app is open.

**Deliberately NOT requested** (they'd be rejected as unjustified):
`READ_DISTANCE`, `READ_ACTIVE_CALORIES_BURNED`, `READ_FLOORS_CLIMBED`,
`READ_HEALTH_DATA_HISTORY`, `READ_HEALTH_DATA_IN_BACKGROUND`.

Add one back **only** when the code genuinely reads it (e.g. distance for the
Phase 4 TURBO release) — and update the privacy policy in the same change.

You must also have (already in the manifest ✅):
- the `ACTION_SHOW_PERMISSIONS_RATIONALE` intent filter
- a privacy policy link reachable from that rationale screen

---

## 4. Content rating questionnaire

Answer honestly; the rating is auto-generated.

| Question | Answer |
|---|---|
| Violence / sexual content / language / drugs | **No** to all |
| **Does the app contain in-app purchases?** | **Yes** |
| **Does it contain ads?** | **Yes**, once AdMob ships |
| **Gambling / simulated gambling** | **See below — answer carefully** |
| User-generated content / social features | **No** |

### The gambling question — read before answering

Mystery Spheres are a randomised reward mechanic. This is **not** gambling under
Play's definition, because:

- spheres are earned by **walking**, never bought with money;
- there is **no paid random box** — the Celestial (real-money) tier has
  **guaranteed** contents;
- rewards have **no real-world value** and cannot be cashed out or traded.

Several jurisdictions regulate *paid* loot boxes. Your design already avoids
this. **Keep it that way** — the moment you sell a randomised box, you inherit
loot-box law in the EU/UK/BE/NL and Play's paid-random-item disclosure rules.

**Play does require disclosing odds** for randomised elements. Your sphere cards
already show a "Drop rates" breakdown in-app ✅.

---

## 5. Store listing copy

**App name** (30 chars max):
```
The Walk Culture
```
(“The Walk Culture: Walk & Collect” is 32 chars — over the limit. Keep the name
alone; the tagline goes in the short description below.)

**Short description** (80 chars):
```
Turn every step into treasure. Walk, earn, and dress up your character.
```

**Full description** (4000 chars):
```
Your steps are worth something.

The Walk Culture turns the walking you already do into a currency you can actually
spend. Every step you take is counted, banked, and converted into Steps —
climbing a ladder of tiers from Copper to Silver, Gold, and beyond.

WALK TO EARN
Steps are counted automatically from your phone's health data. No check-ins, no
manual logging. Just walk.

KEEP YOUR CHARACTER HEALTHY
Your character's wellbeing follows yours. Walk 5,000 steps to hold your level,
10,000 to climb one. Fall short and they slip. Work your way from Idle up to
Soaring — and keep them there.

OPEN MYSTERY SPHERES
Hit a step goal to make a sphere glow, then crack it open. Each one you open
reveals the next tier. Drop rates are always shown up front — no mystery about
the odds.

DRESS UP AND DECORATE
Hundreds of cosmetics: outfits, hair, pets and home decor, from Common to a
prestige line worth more than Gold. Rarer gear takes a richer wallet to unlock.

BUILD A STREAK
Hit your daily step goal to build a streak, complete daily quests, and chase 33
trophies from Easy to Elite.

NO PAY-TO-WIN
Money buys cosmetics — never health, never your step count. Your character's
health level can only be earned by walking. That part is never for sale.

Privacy: your step data is used to run the game and nothing else. It is never
sold and never shared with advertisers.
```

**Graphics needed** (not written here — you'll need art):
- App icon 512×512
- Feature graphic 1024×500
- 2–8 phone screenshots

**Category:** Health & Fitness, or Games → Casual.
*Games gets more traffic; Health & Fitness better matches the Health Connect
review. Health & Fitness is the safer call.*

---

## 6. Remaining blockers

- [x] ~~Rename the app~~ **display name → "The Walk Culture"** (app bar,
      launcher label, onboarding, About, docs). **Still open:** the
      applicationId is `com.perfeos.step_quest` — internal and invisible to
      users, but **permanent once published**. Change it (e.g.
      `com.perfeos.thewalkculture`) before the first upload if you want it to
      match the name; it also renames the IAP product IDs.
- [ ] **Real upload keystore** — release currently signs with the *debug* key
      and Play will reject it. See [`DEPLOY.md`](DEPLOY.md) §4.
- [ ] **App icon** — still the Flutter default.
- [ ] **Support email** — required on the listing.
- [ ] **Account deletion** — Play requires a way to request deletion; the policy
      offers email. A URL-based flow is required *if* you add real accounts.
