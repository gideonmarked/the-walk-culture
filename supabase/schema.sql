-- StepQuest — Phase 1 backend schema (Supabase / Postgres).
-- Paste into the Supabase SQL Editor and run. See ../docs/DEPLOY.md.
--
-- Principles:
--   * The client is NEVER trusted with money. The wallet, VIP entitlement, and
--     ad rewards are written by SECURITY DEFINER functions or the service role
--     — never by a direct client INSERT/UPDATE.
--   * RLS lets a user read only their own rows.
--   * Real-money grants (VIP, currency packs) happen ONLY in the
--     validate-purchase Edge Function, after the store receipt is verified.

-- ---------------------------------------------------------------------------
-- Currency ladder — 100x per tier (MUST match lib/core/currency.dart).
--   Pebbles=1 Copper=100 Silver=10k Gold=1e6 Titanium=1e8 Platinum=1e10
--   Tanzanite=1e12 Emerald=1e14 Ruby=1e16 Diamond=1e18   (all fit in bigint)
-- ---------------------------------------------------------------------------
create or replace function tier_index(p_tier text) returns int
language sql immutable as $$
  select case p_tier
    when 'Pebbles' then 0 when 'Copper' then 1 when 'Silver' then 2
    when 'Gold' then 3 when 'Titanium' then 4 when 'Platinum' then 5
    when 'Tanzanite' then 6 when 'Emerald' then 7 when 'Ruby' then 8
    when 'Diamond' then 9 else null end;
$$;

create or replace function steps_per_unit(p_tier text) returns bigint
language sql immutable as $$
  select (100::numeric ^ tier_index(p_tier))::bigint;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists wallet (
  user_id uuid primary key references auth.users(id) on delete cascade,
  total_steps_lifetime bigint not null default 0,
  total_steps_spent    bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists step_ledger (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  synced_at timestamptz not null default now(),
  window_start timestamptz,
  window_end   timestamptz,
  source text,                         -- 'health_connect' | 'healthkit'
  delta_steps int not null,
  credited_steps int not null,         -- after caps; may be < delta_steps
  flagged boolean not null default false
);

create table if not exists inventory (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create table if not exists shop_item (
  id text primary key,
  name text, slot text, rarity text,
  price_tier text, price_amount int,
  -- Reward-only items (sphere loot) live in the catalogue but are NOT for sale.
  -- Without this, purchase_item() would happily sell e.g. the Celestial Halo
  -- for its price_amount of 0.
  in_shop boolean not null default true,
  is_animated boolean default false, event_id text
);
alter table shop_item add column if not exists in_shop boolean not null default true;

create table if not exists profile (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_config jsonb default '{}'::jsonb,
  home_config   jsonb default '{}'::jsonb,
  health_level int not null default 3,   -- index into kHealthLevels (Steady)
  streak_current int default 0,
  streak_best int default 0,
  updated_at timestamptz not null default now()
);

-- Whole-PlayerState cloud save, so progress survives reinstall / new device.
-- Its own table, readable only by its owner: `profile` rows are readable by
-- everyone for friend discovery (social.sql), and RLS cannot hide one column.
-- NOTE: client-authored, therefore NOT anti-cheat. It's a backup, not a
-- ledger. When the wallet migrates to being server-authoritative, credits
-- move to credit_steps() and this blob drops back to cosmetic prefs only.
create table if not exists player_save (
  user_id uuid primary key references auth.users(id) on delete cascade,
  save_blob jsonb not null,
  updated_at timestamptz not null default now()
);

-- Migration: the save used to be profile.save_blob, which exposed every
-- player's full save to anyone with the anon key. Move it, then drop it.
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'profile'
               and column_name = 'save_blob') then
    insert into player_save(user_id, save_blob, updated_at)
      select user_id, save_blob, updated_at from profile
      where save_blob is not null
      on conflict (user_id) do nothing;
    alter table profile drop column save_blob;
  end if;
end $$;

-- ---- Monetization -----------------------------------------------------------

-- The single source of truth for VIP. Written ONLY by the Edge Function
-- (service role) after a store receipt validates.
create table if not exists entitlement (
  user_id uuid primary key references auth.users(id) on delete cascade,
  vip_until timestamptz,
  updated_at timestamptz not null default now()
);

-- Every validated store purchase. purchase_token is UNIQUE, which is what makes
-- granting idempotent: a replayed receipt cannot pay out twice.
create table if not exists purchase_receipt (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null,                -- 'google_play' | 'app_store'
  product_id text not null,
  purchase_token text not null unique,   -- the anti-replay key
  granted_steps bigint not null default 0,
  granted_vip_days int not null default 0,
  validated_at timestamptz not null default now()
);

-- Rewarded-ad payouts. The per-day cap is enforced HERE, server-side — the
-- client-side cap is a UX nicety and trivially bypassable.
create table if not exists ad_reward (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  reward_steps int not null,
  awarded_at timestamptz not null default now(),
  reward_day date not null default (now() at time zone 'utc')::date
);
create index if not exists ad_reward_user_day on ad_reward(user_id, reward_day);

-- Distance/route tables (empty until Phase 4 / TURBO).
create table if not exists turbo_session (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  type text, started_at timestamptz, ended_at timestamptz,
  distance_m double precision, energy_kcal double precision,
  avg_pace double precision, source text, has_route boolean default false,
  flagged boolean default false
);

-- ---------------------------------------------------------------------------
-- Row-Level Security: read your own rows; never write money.
-- ---------------------------------------------------------------------------
-- EVERY table in the public schema must be listed here. With the project's
-- "Automatically expose new tables" setting on, a table without RLS is exposed
-- to the Data API with no protection at all.
alter table wallet      enable row level security;
alter table inventory   enable row level security;
alter table profile     enable row level security;
alter table player_save enable row level security;
alter table step_ledger enable row level security;
alter table entitlement enable row level security;
alter table purchase_receipt enable row level security;
alter table ad_reward   enable row level security;
alter table shop_item   enable row level security;
alter table turbo_session enable row level security;

drop policy if exists "read own wallet" on wallet;
create policy "read own wallet" on wallet for select using (auth.uid() = user_id);

drop policy if exists "read own inventory" on inventory;
create policy "read own inventory" on inventory for select using (auth.uid() = user_id);

drop policy if exists "read own ledger" on step_ledger;
create policy "read own ledger" on step_ledger for select using (auth.uid() = user_id);

drop policy if exists "rw own profile" on profile;
create policy "rw own profile" on profile for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "rw own save" on player_save;
create policy "rw own save" on player_save for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Entitlements + receipts + ad rewards are READ-ONLY to the client. No insert
-- or update policy exists, so even an authenticated client cannot grant itself
-- VIP or currency by writing rows directly.
drop policy if exists "read own entitlement" on entitlement;
create policy "read own entitlement" on entitlement for select using (auth.uid() = user_id);

drop policy if exists "read own receipts" on purchase_receipt;
create policy "read own receipts" on purchase_receipt for select using (auth.uid() = user_id);

drop policy if exists "read own ad rewards" on ad_reward;
create policy "read own ad rewards" on ad_reward for select using (auth.uid() = user_id);

drop policy if exists "read shop" on shop_item;
create policy "read shop" on shop_item for select using (true);

-- Empty until Phase 4 (TURBO), but locked down now so it can never be exposed
-- unprotected. Read-only to its owner; writes will go through a validated
-- function when GPS sessions land.
drop policy if exists "read own turbo" on turbo_session;
create policy "read own turbo" on turbo_session for select using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Validated step crediting (anti-cheat, doc §4.1). Caps implausible deltas.
--
-- The cap scales with the window, so the window itself cannot be taken on the
-- client's word: a window "starting ten years ago" would lift the cap to ~1e9.
-- It is clamped to real time instead — it can't end in the future, can't start
-- more than a day back, and can't reach back over time an earlier call
-- already credited. Replaying or overlapping windows therefore credit nothing.
-- ---------------------------------------------------------------------------
create or replace function credit_steps(
  p_delta int, p_window_start timestamptz, p_window_end timestamptz, p_source text
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_last_end timestamptz;
  v_start timestamptz;
  v_end timestamptz := least(p_window_end, now());
  v_hours numeric;
  v_cap int;
  v_credit int;
  v_flagged boolean;
  v_new bigint;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  insert into wallet(user_id) values (v_user) on conflict (user_id) do nothing;
  -- Serialise this user's credits so two concurrent calls can't both claim
  -- the same stretch of time.
  perform 1 from wallet where user_id = v_user for update;

  select max(window_end) into v_last_end from step_ledger where user_id = v_user;
  v_start := greatest(p_window_start, now() - interval '1 day',
                      coalesce(v_last_end, '-infinity'::timestamptz));
  v_hours := greatest(extract(epoch from (v_end - v_start)) / 3600.0, 0);
  v_cap := floor(v_hours * 12000);          -- ~12k steps/hour ceiling
  v_credit := least(greatest(p_delta, 0), v_cap);
  v_flagged := p_delta > v_cap;

  insert into step_ledger(user_id, window_start, window_end, source, delta_steps, credited_steps, flagged)
    values (v_user, v_start, greatest(v_end, v_start), p_source, p_delta, v_credit, v_flagged);
  update wallet set total_steps_lifetime = total_steps_lifetime + v_credit, updated_at = now()
    where user_id = v_user
    returning total_steps_lifetime into v_new;
  return v_new;
end; $$;

-- ---------------------------------------------------------------------------
-- Atomic cosmetic purchase. Reads the price server-side and enforces BOTH rules
-- the client shows: you must have banked the item's wallet tier, and you must
-- be able to afford it.
-- NOTE: requires shop_item to be seeded — see ../docs/DEPLOY.md.
-- ---------------------------------------------------------------------------
create or replace function purchase_item(p_item_id text)
returns void
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_price bigint;
  v_tier text;
  v_in_shop boolean;
  v_spendable bigint;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  -- Checked before the debit: a retry or double tap on an owned item must not
  -- charge again for nothing.
  if exists (select 1 from inventory where user_id = v_user and item_id = p_item_id) then
    raise exception 'already owned';
  end if;

  select price_tier, in_shop, (price_amount)::bigint * steps_per_unit(price_tier)
    into v_tier, v_in_shop, v_price
    from shop_item where id = p_item_id;
  if v_price is null then raise exception 'unknown item'; end if;
  -- Reward-only loot is in the catalogue but never for sale.
  if not coalesce(v_in_shop, false) then raise exception 'not purchasable'; end if;

  select total_steps_lifetime - total_steps_spent into v_spendable
    from wallet where user_id = v_user for update;
  if v_spendable is null then raise exception 'no wallet'; end if;

  -- Tier gate: spendable must reach the tier the item is priced in.
  if v_spendable < steps_per_unit(v_tier) then
    raise exception 'tier locked: needs %', v_tier;
  end if;
  if v_spendable < v_price then raise exception 'insufficient funds'; end if;

  update wallet set total_steps_spent = total_steps_spent + v_price,
                    updated_at = now()
    where user_id = v_user;
  insert into inventory(user_id, item_id) values (v_user, p_item_id)
    on conflict do nothing;
end; $$;

-- ---------------------------------------------------------------------------
-- Rewarded ads: the daily cap lives here, not on the client.
-- ---------------------------------------------------------------------------
create or replace function claim_ad_reward(p_reward_steps int default 20000)
returns bigint
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_count int;
  v_limit int := 5;
  v_is_vip boolean;
  v_new bigint;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  -- Cap must match kAdRewardSteps in lib/core/premium.dart (2 Silver = 20,000).
  if p_reward_steps < 0 or p_reward_steps > 20000 then
    raise exception 'invalid reward';                 -- client can't inflate it
  end if;

  select coalesce(vip_until > now(), false) into v_is_vip
    from entitlement where user_id = v_user;
  if coalesce(v_is_vip, false) then v_limit := v_limit + 1; end if;

  select count(*) into v_count from ad_reward
    where user_id = v_user and reward_day = v_today;
  if v_count >= v_limit then raise exception 'daily ad limit reached'; end if;

  insert into ad_reward(user_id, reward_steps) values (v_user, p_reward_steps);
  insert into wallet(user_id) values (v_user) on conflict (user_id) do nothing;
  update wallet set total_steps_lifetime = total_steps_lifetime + p_reward_steps,
                    updated_at = now()
    where user_id = v_user
    returning total_steps_lifetime into v_new;
  return v_new;
end; $$;

-- ---------------------------------------------------------------------------
-- Real-money grant. Called ONLY by the validate-purchase Edge Function using
-- the service-role key, never by the client — hence the REVOKE below.
--
-- Currency packs: idempotent on the unique purchase_token, so a replayed
-- receipt is a no-op.
-- VIP: Google keeps ONE purchase token across every auto-renewal, so a token
-- can't mean "already granted" for a subscription. Instead the Edge Function
-- passes the expiry Google reports (p_vip_until) and VIP is SET to it, never
-- stacked. Re-validating the same token is then harmless, and a renewal moves
-- the expiry forward.
-- Either way a token stays bound to the account that first redeemed it.
-- ---------------------------------------------------------------------------
drop function if exists grant_purchase(uuid, text, text, text, bigint, int);
create or replace function grant_purchase(
  p_user uuid, p_platform text, p_product_id text, p_purchase_token text,
  p_steps bigint default 0, p_vip_until timestamptz default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
  v_inserted int;
begin
  select user_id into v_owner from purchase_receipt
    where purchase_token = p_purchase_token;
  if v_owner is not null and v_owner <> p_user then
    raise exception 'purchase token belongs to another account';
  end if;

  insert into purchase_receipt(user_id, platform, product_id, purchase_token,
                               granted_steps, granted_vip_days)
    values (p_user, p_platform, p_product_id, p_purchase_token, p_steps, 0)
    on conflict (purchase_token) do nothing;
  get diagnostics v_inserted = row_count;

  if p_steps > 0 and v_inserted > 0 then   -- a replayed pack pays nothing
    insert into wallet(user_id) values (p_user) on conflict (user_id) do nothing;
    update wallet set total_steps_lifetime = total_steps_lifetime + p_steps,
                      updated_at = now()
      where user_id = p_user;
  end if;

  if p_vip_until is not null then
    insert into entitlement(user_id, vip_until)
      values (p_user, p_vip_until)
      on conflict (user_id) do update set
        -- Another, longer subscription on the same account keeps its window.
        vip_until = greatest(coalesce(entitlement.vip_until, p_vip_until), p_vip_until),
        updated_at = now();
  end if;
end; $$;

-- The client must never be able to mint money.
revoke all on function grant_purchase(uuid, text, text, text, bigint, timestamptz)
  from public, anon, authenticated;
