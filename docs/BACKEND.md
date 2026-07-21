# Backend Setup & Provider Choice (Phase 1)

How to take The Walk Culture from the current **local-only prototype**
(SharedPreferences) to a **server-authoritative** backend — which the design doc
says is mandatory or the currency is trivially cheated (§2.2, §4). This doc gives
a provider recommendation, the schema, the validated step-credit flow, and a
migration path.

> Nothing here is built yet. The app currently persists locally in
> `state/app_providers.dart`. This is the blueprint for Phase 1.

---

## 1. What MUST be server-authoritative

The client can be modified, so the server — not the app — is the source of truth
for anything that has value:

- **The wallet.** Per doc §8, store just two integers, `total_steps_lifetime`
  and `total_steps_spent`, and derive every tier balance. The client may *display*
  them but must never *set* them.
- **Step crediting.** The client reports a **delta** (steps since last sync) with
  metadata; the server validates it (plausibility caps, §4.1) and credits.
- **Purchases.** The server checks affordability and ownership, then deducts.
- **Quest/achievement rewards.** Granted server-side so they can't be forged.

Everything cosmetic and read-only (which hat is equipped, room layout) can live
client-side and just be mirrored up for cloud save.

---

## 2. Which provider? (recommendation)

| | **Supabase** (recommended) | **Firebase** | **Custom (Node/Go + Postgres)** |
|---|---|---|---|
| Data model | Postgres (relational — fits the §8 schema exactly) | Firestore (NoSQL documents) | anything |
| **Atomic currency updates** | ✅ SQL transactions / RPC — ideal for "validate delta → credit" | ⚠️ transactions exist but NoSQL makes the ledger awkward | ✅ full control |
| Server logic | Edge Functions (Deno/TypeScript) | Cloud Functions (needs paid Blaze plan) | your servers |
| Auth (Apple/Google) | ✅ built-in | ✅ built-in (best Flutter DX) | you build it |
| Access control | Row-Level Security (SQL policies) | Security Rules (custom DSL) | your code |
| Flutter SDK | `supabase_flutter` | `firebase_*` (FlutterFire) | REST/gRPC client |
| Free tier | generous (Postgres + auth + functions) | generous (Firestore + auth) | infra cost |
| Best when | you want SQL + transactional integrity for currency | you want the tightest Flutter/realtime DX | you have specific infra needs |

**Recommendation: Supabase.** A currency economy is fundamentally
transactional and relational — "read balance, validate, write new balance"
inside one ACID transaction is exactly what Postgres does well, and the doc's
§8 schema is already relational (Wallet, StepLedger, Inventory, ShopItem).
Row-Level Security lets you make the wallet **readable but not writable** by the
client, forcing all credits through a validated function.

**Choose Firebase instead if** you prefer the batteries-included FlutterFire DX,
want realtime listeners for social features, and are comfortable modelling the
ledger as documents. Both are fine; the rest of this doc uses Supabase and notes
the Firebase equivalent where it differs.

**Custom backend:** only if you outgrow the above (custom anti-cheat ML, complex
guild economies). Not worth it for Phase 1.

---

## 3. Recommended architecture (Supabase)

```
[ Flutter app ]
   │  Sign in with Apple / Google  → Supabase Auth (issues JWT)
   │
   │  reads (RLS-guarded):  wallet, inventory, shop_items
   │  ── never writes wallet directly ──
   │
   ▼  calls Edge Function with { deltaSteps, windowStart, windowEnd, source }
[ Edge Function: credit_steps ]
   │  validate JWT → plausibility caps (§4.1) → within a TX:
   │     insert step_ledger row, UPDATE wallet.total_steps_lifetime
   ▼
[ Postgres ]  ← RLS: users can SELECT own rows; only service role writes wallet
```

Purchases follow the same shape: a `purchase_item` function checks
`spendable = lifetime - spent >= price`, then increments `total_steps_spent` and
inserts inventory — all in one transaction.

---

## 4. Auth

Both stores effectively require **Sign in with Apple** (if you offer any social
login) plus **Google**. Supabase Auth and Firebase Auth both support these
out of the box.

- iOS: enable "Sign in with Apple" capability in Xcode.
- Android: configure Google OAuth client.
- Keep an **anonymous/guest** option so the current local prototype flow still
  works, then link to a real account later.

---

## 5. Schema (Supabase SQL) — maps to doc §8

```sql
-- Wallet: the whole ladder derives from two integers (doc §8).
create table wallet (
  user_id uuid primary key references auth.users(id) on delete cascade,
  total_steps_lifetime bigint not null default 0,
  total_steps_spent    bigint not null default 0,
  updated_at timestamptz not null default now()
);

-- Append-only audit trail of every credited sync (anti-cheat forensics).
create table step_ledger (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  synced_at timestamptz not null default now(),
  window_start timestamptz,
  window_end   timestamptz,
  source text,                       -- 'health_connect' | 'healthkit'
  delta_steps int not null,
  credited_steps int not null,       -- after caps; may be < delta_steps
  flagged boolean not null default false
);

create table inventory (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- Server-owned price list (never trust client prices).
create table shop_item (
  id text primary key,
  name text, slot text, rarity text,
  price_tier text, price_amount int,
  is_animated boolean default false, event_id text
);

-- Profile / cosmetic state (safe to let the client write its own row).
create table profile (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_config jsonb default '{}'::jsonb,
  home_config   jsonb default '{}'::jsonb,
  daily_goal int default 6000,
  streak_current int default 0,
  streak_best int default 0
);

-- Distance/route tables can exist empty from day one (doc §8) — populate in
-- Phase 4 (TURBO). No GPS columns are used before then.
```

### Row-Level Security (the crucial part)
```sql
alter table wallet enable row level security;
create policy "read own wallet" on wallet
  for select using (auth.uid() = user_id);
-- NO insert/update policy → the client cannot write the wallet at all.
-- Only the service role (used by Edge Functions) can modify it.

alter table inventory enable row level security;
create policy "read own inventory" on inventory
  for select using (auth.uid() = user_id);

alter table profile enable row level security;
create policy "rw own profile" on profile
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

---

## 6. The validated credit function (anti-cheat, doc §4.1)

A Postgres function run with elevated rights, called from an Edge Function after
JWT verification. Caps implausible deltas instead of trusting the client.

```sql
create or replace function credit_steps(
  p_delta int, p_window_start timestamptz, p_window_end timestamptz, p_source text
) returns bigint
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_hours numeric := greatest(extract(epoch from (p_window_end - p_window_start)) / 3600.0, 0.001);
  v_cap int := ceil(v_hours * 12000);      -- ~12k steps/hour ceiling (§4.1)
  v_credit int := least(greatest(p_delta, 0), v_cap);
  v_flagged boolean := p_delta > v_cap;
  v_new bigint;
begin
  insert into step_ledger(user_id, window_start, window_end, source, delta_steps, credited_steps, flagged)
    values (v_user, p_window_start, p_window_end, p_source, p_delta, v_credit, v_flagged);
  update wallet set total_steps_lifetime = total_steps_lifetime + v_credit, updated_at = now()
    where user_id = v_user
    returning total_steps_lifetime into v_new;
  return v_new;
end; $$;
```

**Purchases** get an analogous `purchase_item(p_item_id)` function that reads the
price from `shop_item`, checks `lifetime - spent >= price`, then bumps
`total_steps_spent` and inserts inventory — all atomic, so double-spends are
impossible.

Additional anti-cheat to layer in (doc §4.1): per-day caps, velocity checks vs
history, `RecordingMethod.manual/unknown` filtering client-side, and — for the
Phase 4 TURBO distance track — the **~10.5 km/h speed cap** applied to session
segments server-side.

---

## 7. Flutter client integration

```yaml
# pubspec.yaml — swap the local-only stack for:
dependencies:
  supabase_flutter: ^2.5.0
  # (remove reliance on shared_preferences for the wallet; keep it only for
  #  device-local UI prefs if you like)
```

```dart
await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
final supabase = Supabase.instance.client;

// Credit a passive-sync delta (never write the wallet directly):
final newLifetime = await supabase.rpc('credit_steps', params: {
  'p_delta': delta,
  'p_window_start': windowStart.toIso8601String(),
  'p_window_end': windowEnd.toIso8601String(),
  'p_source': source,
});
```

### How it slots into the current code
The app is already structured for this — `PlayerController` is the single
mutation point. Phase 1 = replace its `_save()` / `_load()` internals:

- `services/health_service.dart` stays exactly as-is (still reads steps locally).
- Add a `BackendService` (Supabase calls) alongside it.
- `PlayerController.syncSteps()` → compute delta locally, call `credit_steps`,
  set `lifetimeSteps` from the server's return value.
- `buy()` → call `purchase_item`; on success update local state from the server.
- Keep the wallet **derivation** (`toWallet`, two-integer model) unchanged — it's
  already the §8 design, so nothing about the currency UI changes.

**Firebase equivalent:** `credit_steps`/`purchase_item` become **Cloud
Functions** (callable), the tables become Firestore collections, and RLS becomes
**Security Rules** that deny client writes to `wallet` while allowing reads.

---

## 8. Cost & ops

- **Supabase free tier**: a Postgres project, auth, and Edge Functions —
  enough for development and early users. Paid tier when you scale.
- **Firebase**: Firestore + Auth free (Spark); Cloud Functions require the
  pay-as-you-go **Blaze** plan (still ~free at low volume).
- Turn on **daily DB backups** before launch.
- **Never** put health data into analytics/ad SDKs (doc §9). Keep the privacy
  policy current — both stores require it for health apps.

---

## 9. Phase 1 rollout order

> **Ready-to-run:** the SQL in §5–§6 is saved as
> [`../supabase/schema.sql`](../supabase/schema.sql) with a quickstart in
> [`../supabase/README.md`](../supabase/README.md) — paste it into the Supabase
> SQL Editor and it creates everything below.

1. Create the Supabase project; add the schema + RLS above.
2. Wire Supabase Auth (guest + Apple + Google) into onboarding.
3. Add `BackendService`; move wallet/inventory reads to Supabase.
4. Implement `credit_steps` + `purchase_item` functions; route
   `PlayerController` through them.
5. Seed `shop_item` from `data/shop_catalog.dart` (server becomes the price
   source of truth).
6. Add per-day plausibility caps + a simple admin view of `flagged` ledger rows.
7. Keep local SharedPreferences only as an offline cache / guest fallback.

> Distance/route tables and the TURBO speed-cap validation stay empty until
> Phase 4 — define them now (§8) so nothing needs migrating later.
