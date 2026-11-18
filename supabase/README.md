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
| `safety.sql` | Account deletion, blocking, reporting, leaving groups — run after `social.sql` and `prayer_requests.sql` |
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
Subscriptions are the exception: Google reuses one token across renewals, so
VIP is *set* to the expiry Google reports rather than stacked per token.
Rewarded-ad daily caps are enforced in `claim_ad_reward()`, not on the client.

`profile` rows are readable by every signed-in user (friend discovery), so
nothing private may live on `profile`. The cloud save is in `player_save`,
readable and writable only by its owner.

## Upgrading an existing project

Every file here is safe to re-run. After pulling backend changes, re-run, in
order, `schema.sql`, `social.sql`, `prayer_requests.sql` and `safety.sql` in the
SQL Editor, and redeploy the function
(`supabase functions deploy validate-purchase`). `schema.sql` migrates old
`profile.save_blob` data into `player_save` and drops that column.
Deploy the SQL and the function together: the function calls
`grant_purchase(…, p_vip_until)`, and the old signature is dropped.

## Moderation (Google Play UGC policy)

Players can report prayer requests, other players and groups, and block other
players. Prayer requests hide themselves after 3 reports. Player and group
reports land in `user_report` with `status = 'open'`: review them in
**Table editor → user_report**, act on them (for example delete an offensive
group, or the reported user's account in **Authentication → Users**), then set
`status` to `actioned` or `dismissed`. Check it regularly — Play expects
reports to be acted on.

Account deletion requests that arrive by email (see `docs/delete-account.html`):
find the account by its code with
`select user_id from profile where account_code = 'A7A43B7';`, then delete that
user in **Authentication → Users**. Every table cascades.

## Known gap (deliberate, documented)

**The wallet is not yet server-authoritative.** `player_save.save_blob` is a
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
