# Supabase backend — quickstart

Full deployment walkthrough (and the cheapest-possible hosting path) lives in
[`../docs/DEPLOY.md`](../docs/DEPLOY.md). Short version:

1. <https://supabase.com> → **New project**.
2. **SQL Editor** → paste [`schema.sql`](schema.sql) → **Run**.
3. **Authentication → Providers → Anonymous sign-ins: ON**.
4. **Settings → API** → copy the Project URL + anon (publishable) key, then:

```bash
flutter run --release \
  --dart-define=SUPABASE_URL=https://YOURPROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Without those defines the app runs local-only. The cloud layer is additive —
nothing breaks when it's absent.

## What's here

| File | Purpose |
|---|---|
| `schema.sql` | Tables, row-level security, and the money functions |
| `seed_shop_items.sql` | **Generated** — run after `schema.sql` to fill `shop_item` |
| `functions/validate-purchase/` | Edge Function: verifies store receipts, grants entitlements |

Regenerate the seed whenever `lib/data/shop_catalog.dart` changes, or the
server-side `purchase_item()` prices against a stale shelf:

```bash
dart run tool/seed_shop_items.dart > supabase/seed_shop_items.sql
```

## The security model in one paragraph

The client is never trusted with money. RLS lets a user **read** only their own
rows, and there is deliberately **no insert/update policy** on `entitlement`,
`purchase_receipt`, or `ad_reward` — so an authenticated client cannot grant
itself VIP or currency by writing rows. Real-money grants happen only inside
`validate-purchase`, which verifies the purchase token with Google and then
calls `grant_purchase()` with the service-role key; `grant_purchase` is
`REVOKE`d from `anon`/`authenticated` so the client can't call it directly, and
it keys off a **unique `purchase_token`** so a replayed receipt can't pay twice.
Rewarded-ad daily caps are enforced in `claim_ad_reward()`, not on the client.

## Known gap (deliberate, documented)

**The wallet is not yet server-authoritative.** `profile.save_blob` is a
client-authored cloud *backup* for reinstall/new-device restore, not a ledger.
`credit_steps()` is already in the schema for when step crediting moves
server-side — that's the anti-cheat milestone.

Why it isn't a small patch: the server can only own the wallet total if it owns
*every* credit path. Today the client also applies a 2×/4× boost+VIP multiplier
the server doesn't know about, and grants bonuses for quests, trophies, and
sphere drops whose amounts live in Dart. Route only walking through
`credit_steps()` and the server's total silently omits all the rest — so
adopting it as truth would **erase** the player's bonus currency. Migrating
means moving the whole earning economy (multipliers, quest/trophy/sphere reward
tables) server-side, in one go. Half-done is worse than not started.

What IS already server-authoritative: **VIP entitlement** and the
**rewarded-ad daily cap** (`claim_ad_reward`), both self-contained enough to
move without the divergence problem.

**Never ship the `service_role` key in the app.** It bypasses RLS and belongs
only in Edge Function secrets.
