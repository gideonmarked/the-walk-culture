# Deploying The Walk Culture on the cheapest possible footing

## What runs where (read this first)

The Walk Culture is a **mobile app**, not a website. There is no server to "host the
app on" — no VPS, no container, no domain. It compiles to a binary that runs
**on the phone**. You *distribute* that binary; you don't serve it.

So the entire deployment surface is two things:

```
   ┌─────────────────────────┐         ┌──────────────────────────┐
   │  The app (Flutter)      │  HTTPS  │  Supabase (§1)           │
   │  runs ON the phone      │ ──────▶ │  Postgres + Auth         │
   │                         │         │  + validate-purchase fn  │
   │  Android / iOS only     │ ◀────── │                          │
   └─────────────────────────┘         └──────────────────────────┘
        distributed as                        the only thing
        APK (§3) or Play (§4)                 actually "served"
                                              — free tier, $0
```

- **The app binary** → gets onto phones via a direct APK (§3) or the Play Store
  (§4). That *is* "deploying the app".
- **The backend** → Supabase (§1). The only hosted piece, and it's free.

Everything still works with the backend switched off (the app runs local-only);
Supabase adds cloud saves and the money paths.

**Flutter Web is not an option.** Only `android` and `ios` are enabled, and the
`health` / `pedometer` plugins are mobile-only — a browser cannot read Health
Connect or a step sensor, so the core premise can't run on the web. If you ever
want a *marketing* page, that's a separate static site (Cloudflare/GitHub Pages,
also free) — not this app.

---

Target: **$0/month running cost**, plus a **$25 one-time** Google fee you only
pay when you actually want in-app purchases. Everything below fits inside free
tiers at prototype/early-launch scale.

| Piece | Cheapest option | Cost |
|---|---|---|
| Backend (DB + auth + functions) | Supabase Free | **$0** |
| Rewarded ads | AdMob | **$0** (they pay you) |
| Distribute to testers | Direct APK / Play Internal Testing | **$0** |
| Public release + IAP | Google Play (one-time dev fee) | **$25 once** |
| Domain / hosting / CI | not needed yet | **$0** |

> IAP **requires** the Play Store — Google does not allow billing outside it for
> in-app digital goods. So the $25 is unavoidable *if and when* you monetize.
> Until then, everything runs at literal zero.

---

## 1. Backend — Supabase Free ($0)

Free tier gives you 500 MB database, 50,000 monthly active users, and 500k Edge
Function invocations. You will not outgrow this during early launch.

1. Create a project at <https://supabase.com> → **New project** (pick a region
   near your players). Save the DB password somewhere safe.
2. **SQL Editor** → paste all of [`../supabase/schema.sql`](../supabase/schema.sql)
   → **Run**. This creates the tables, row-level security, and the money
   functions (`credit_steps`, `purchase_item`, `claim_ad_reward`,
   `grant_purchase`).
3. **Authentication → Providers → Anonymous sign-ins: ON.** The app takes an
   anonymous session so progress syncs with zero sign-up friction. (You can add
   Google/Apple later and upgrade the same account without losing the row.)
4. **Settings → API** → copy the **Project URL** and the **anon / publishable key**.

Run the app against it:

```bash
flutter run --release \
  --dart-define=SUPABASE_URL=https://YOURPROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Without those two defines the app runs **local-only** — fully playable, no
network. That's the current default.

> The anon key is *public by design*; it identifies the project, it doesn't
> authorise anything. Your wallet and VIP are protected by the row-level
> security in the schema, not by hiding the key. Never ship the **service_role**
> key in the app — it bypasses RLS and belongs only in Edge Function secrets.

### Free-tier gotcha
Supabase **pauses free projects after ~7 days of inactivity**. One request wakes
it (slow first hit). For a live app with daily users this never triggers.

---

## 2. Rewarded ads — AdMob ($0, earns money)

1. Create an account at <https://admob.google.com> → add your app.
2. Create a **Rewarded** ad unit → copy its ad unit ID.
3. Add `google_mobile_ads` to `pubspec.yaml`, put your **AdMob App ID** in
   `android/app/src/main/AndroidManifest.xml`:

   ```xml
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="ca-app-pub-XXXXXXXX~XXXXXXXX"/>
   ```

4. Implement `RewardedAdService` (see
   [`../lib/services/rewarded_ad_service.dart`](../lib/services/rewarded_ad_service.dart))
   against the SDK and override `rewardedAdServiceProvider`. The reward economy,
   daily caps, and crediting are already built behind that interface.

While developing, use Google's official **test IDs** (no account needed, and
tapping real ads with your own account is a ban risk):

- App ID: `ca-app-pub-3940256099942544~3347511713`
- Rewarded unit: `ca-app-pub-3940256099942544/5224354917`

> Payouts require an AdMob payment threshold ($100) and tax details.

---

## 3. Distributing to testers — $0

**Option A — hand out the APK (free, zero setup).** Fastest for a few testers.
```bash
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
# build/app/outputs/flutter-apk/app-release.apk
```
No auto-updates, and testers must allow "install unknown apps". **IAP does not
work this way** — Play Billing requires install from Play.

**Option B — Play Internal Testing (free after the $25).** Up to 100 testers,
auto-updates, and **billing works** — this is the only way to test real
purchases.

---

## 4. Public release + IAP — $25 one-time

1. Pay the one-time **$25** Google Play developer registration.
2. **Sign the app for real.** Right now `android/app/build.gradle.kts` signs
   release with the *debug* key — Play will reject that.
   ```bash
   keytool -genkey -v -keystore ~/stepquest-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Add `android/key.properties` (**git-ignore it**) and point `signingConfigs`
   at it.
3. Build an **App Bundle** (Play requires `.aab`, not `.apk`):
   ```bash
   flutter build appbundle --release \
     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```
4. Play Console → **Monetize → Products**:
   - **In-app products** (consumables) for the step packs
   - **Subscriptions** for VIP (add a 7-day free trial on monthly)

   The product IDs must match `lib/core/premium.dart` and the `PRODUCTS` map in
   the Edge Function exactly.
5. Deploy the validator and give it Google credentials:
   ```bash
   supabase functions deploy validate-purchase
   supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"
   ```
   The service account comes from Google Cloud → grant it access in Play Console
   → **Setup → API access**, with the *View financial data* permission.
6. Replace `SimulatedPurchaseService` with a real `in_app_purchase`
   implementation that sends `{productId, purchaseToken}` to the Edge Function
   and only grants when the server says `ok: true`.

**Google's cut:** 30% standard, but **15%** under the Play *Small Business
Program* (under $1M/year — apply, it's free), and 15% on subscriptions after a
subscriber's first year. Budget 15%.

---

## 5. Ship blockers — do these before any public release

- [x] ~~Replace `SimulatedPurchaseService`~~ — **done**. Release builds now use
      `StorePurchaseService` (real Play billing + server validation); the
      simulator is `kDebugMode`-only, so a release build physically cannot grant
      an entitlement without Play *and* the server both agreeing.
- [x] ~~Seed the `shop_item` table~~ — **done**. Regenerate any time the
      catalogue changes:
      ```bash
      dart run tool/seed_shop_items.dart > supabase/seed_shop_items.sql
      ```
      then run that file in the SQL Editor. It upserts, so re-seeding is safe.
- [ ] **Sign with a real upload key** (currently the debug key).
- [ ] **Rename the app** from `step_quest` and set a real icon.
- [ ] **Privacy policy URL** — mandatory, because the app reads health data.
- [ ] **Play Data Safety form** — declare the health/steps usage honestly.
- [ ] **Age rating** — a walking game attracts minors; if under-13s are in
      scope you're into COPPA/family-policy territory, which restricts ads and
      loot mechanics.

Developer tools (simulate steps, walking-count toggle, reset today's steps,
reset all data) are gated behind `kDevToolsEnabled` — present in debug and in
test builds compiled with `--dart-define=DEV_TOOLS=true`, and compiled OUT of a
public release that omits the flag. So build the **public** bundle plainly:

```bash
flutter build appbundle --release   # no DEV_TOOLS — tools excluded
```

and a **tester** build with the flag when you want the tools on-device:

```bash
flutter build apk --release --dart-define=DEV_TOOLS=true
```

---

## Cost summary

**Today (prototype/testing): $0.** Supabase free + local APK to testers.

**At launch with IAP: $25 once**, then $0/month until you exceed Supabase's free
tier (50k MAU) — at which point Supabase Pro is $25/month and you'd be earning
enough to cover it many times over.
