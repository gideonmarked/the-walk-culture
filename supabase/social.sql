-- StepQuest — social schema (friends, groups, group houses).
-- Run AFTER schema.sql. See ../docs/DEPLOY.md.
--
-- The social graph is inherently multi-user, so unlike the wallet it MUST be
-- server-owned from day one — a client can't be trusted to say "X is my friend"
-- or "I paid for this group". Group creation cost is charged here, in a
-- SECURITY DEFINER function, against the same wallet the rest of the game uses.

-- ---------------------------------------------------------------------------
-- Identity: username + shareable account code on the profile.
-- ---------------------------------------------------------------------------
alter table profile add column if not exists username text unique;
alter table profile add column if not exists account_code text unique;

-- 7-char code generator (matches lib/core/social.dart alphabet, ambiguous chars
-- removed). Loops until it lands a free code — collisions are astronomically
-- rare in a 31^7 space, but the unique index is the real guarantee.
create or replace function gen_account_code() returns text
language plpgsql as $$
declare
  alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
  i int;
begin
  loop
    code := '';
    for i in 1..7 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from profile where account_code = code);
  end loop;
  return code;
end; $$;

-- Give every profile a code the moment it's created.
create or replace function ensure_account_code() returns trigger
language plpgsql as $$
begin
  if new.account_code is null then
    new.account_code := gen_account_code();
  end if;
  return new;
end; $$;

drop trigger if exists profile_account_code on profile;
create trigger profile_account_code before insert on profile
  for each row execute function ensure_account_code();

-- ---------------------------------------------------------------------------
-- Friendships. One row per direction so "my friends" is a simple query; a
-- request is (accepted=false) until the other side accepts.
-- ---------------------------------------------------------------------------
create table if not exists friendship (
  user_id   uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  accepted  boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);
create index if not exists friendship_friend on friendship(friend_id);

-- ---------------------------------------------------------------------------
-- Groups + membership + the shared house.
-- ---------------------------------------------------------------------------
create table if not exists groupe (          -- "group" is a reserved word
  id uuid primary key default gen_random_uuid(),
  code text not null unique,                 -- 7-char join code
  name text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists group_member (
  group_id uuid not null references groupe(id) on delete cascade,
  user_id  uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member',       -- 'owner' | 'member'
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index if not exists group_member_user on group_member(user_id);

-- One shared house per group. `level` is expansion size; `furniture` is the
-- placed items. Members improve it with THEIR OWN currency (charged via
-- group_house_upgrade), so the spend column is per-contributor, not the group.
create table if not exists group_house (
  group_id uuid primary key references groupe(id) on delete cascade,
  level int not null default 1,
  furniture jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists group_house_contribution (
  group_id uuid not null references groupe(id) on delete cascade,
  user_id  uuid not null references auth.users(id) on delete cascade,
  steps_spent bigint not null default 0,
  primary key (group_id, user_id)
);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table friendship enable row level security;
alter table groupe enable row level security;
alter table group_member enable row level security;
alter table group_house enable row level security;
alter table group_house_contribution enable row level security;

-- Membership check that BYPASSES RLS (security definer). Policies below must
-- use this instead of querying group_member directly: a group_member policy
-- that selects from group_member recurses infinitely (Postgres error 42P17),
-- and the groupe/group_house policies query group_member too. Routing through a
-- definer function reads membership without re-triggering RLS.
create or replace function is_member_of(p_group uuid) returns boolean
language sql security definer stable as $$
  select exists (
    select 1 from group_member
    where group_id = p_group and user_id = auth.uid()
  );
$$;

-- Profiles need to be discoverable by username/code to friend someone, so allow
-- reading other profiles' PUBLIC columns. (Postgres RLS is row-level, not
-- column-level; keep only shareable fields on `profile` and put anything
-- private elsewhere. username/account_code/display bits are fine to expose.)
drop policy if exists "read profiles for discovery" on profile;
create policy "read profiles for discovery" on profile for select using (true);

drop policy if exists "see own friendships" on friendship;
create policy "see own friendships" on friendship for select
  using (auth.uid() = user_id or auth.uid() = friend_id);

-- Members can see a group; anyone can look up a group by code to join (the join
-- itself goes through join_group()).
drop policy if exists "see groups you're in" on groupe;
create policy "see groups you're in" on groupe for select using (is_member_of(id));

drop policy if exists "see co-members" on group_member;
create policy "see co-members" on group_member for select using (is_member_of(group_id));

drop policy if exists "see own group house" on group_house;
create policy "see own group house" on group_house for select using (is_member_of(group_id));

drop policy if exists "see house contributions" on group_house_contribution;
create policy "see house contributions" on group_house_contribution for select
  using (is_member_of(group_id));

-- No direct writes anywhere: every mutation goes through the functions below.

-- ---------------------------------------------------------------------------
-- Friend requests
-- ---------------------------------------------------------------------------
create or replace function send_friend_request(p_code text)
returns void language plpgsql security definer as $$
declare
  v_me uuid := auth.uid();
  v_them uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select user_id into v_them from profile where account_code = upper(p_code);
  if v_them is null then raise exception 'no such code'; end if;
  if v_them = v_me then raise exception 'cannot friend yourself'; end if;

  insert into friendship(user_id, friend_id, accepted)
    values (v_me, v_them, false) on conflict do nothing;
end; $$;

create or replace function accept_friend_request(p_from uuid)
returns void language plpgsql security definer as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  -- Mark their request accepted and mirror the edge so it's mutual.
  update friendship set accepted = true
    where user_id = p_from and friend_id = v_me;
  insert into friendship(user_id, friend_id, accepted)
    values (v_me, p_from, true)
    on conflict (user_id, friend_id) do update set accepted = true;
end; $$;

-- ---------------------------------------------------------------------------
-- Group creation — charges the escalating slot cost from the caller's wallet.
-- Mirrors lib/core/social.dart groupSlotCost(): 1st free, then 50k/200k/500k,
-- doubling beyond. Deliberately steep to nudge real-money currency purchases.
-- ---------------------------------------------------------------------------
create or replace function group_slot_cost(p_owned int) returns bigint
language sql immutable as $$
  select case
    when p_owned <= 0 then 0
    when p_owned = 1 then 50000
    when p_owned = 2 then 200000
    when p_owned = 3 then 500000
    else (500000::bigint * (1 << (p_owned - 3)))   -- doubles past the 4th
  end;
$$;

create or replace function create_group(p_name text)
returns groupe language plpgsql security definer as $$
declare
  v_me uuid := auth.uid();
  v_owned int;
  v_cost bigint;
  v_spendable bigint;
  v_group groupe;
  v_code text;
  v_alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  i int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if length(trim(coalesce(p_name,''))) = 0 then raise exception 'name required'; end if;

  select count(*) into v_owned from groupe where owner_id = v_me;
  v_cost := group_slot_cost(v_owned);

  if v_cost > 0 then
    select total_steps_lifetime - total_steps_spent into v_spendable
      from wallet where user_id = v_me for update;
    if coalesce(v_spendable,0) < v_cost then
      raise exception 'insufficient funds: need % steps', v_cost;
    end if;
    update wallet set total_steps_spent = total_steps_spent + v_cost,
                      updated_at = now()
      where user_id = v_me;
  end if;

  loop
    v_code := '';
    for i in 1..7 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random()*length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from groupe where code = v_code);
  end loop;

  insert into groupe(code, name, owner_id) values (v_code, trim(p_name), v_me)
    returning * into v_group;
  insert into group_member(group_id, user_id, role) values (v_group.id, v_me, 'owner');
  insert into group_house(group_id) values (v_group.id);
  return v_group;
end; $$;

create or replace function join_group(p_code text)
returns groupe language plpgsql security definer as $$
declare
  v_me uuid := auth.uid();
  v_group groupe;
  v_count int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_group from groupe where code = upper(p_code);
  if v_group.id is null then raise exception 'no such group'; end if;

  select count(*) into v_count from group_member where group_id = v_group.id;
  if v_count >= 20 then raise exception 'group is full'; end if;

  insert into group_member(group_id, user_id) values (v_group.id, v_me)
    on conflict do nothing;
  return v_group;
end; $$;

-- ---------------------------------------------------------------------------
-- Group house upgrades — each member pays with THEIR OWN wallet.
-- ---------------------------------------------------------------------------
create or replace function group_house_upgrade(p_group uuid, p_cost bigint, p_new_level int)
returns void language plpgsql security definer as $$
declare
  v_me uuid := auth.uid();
  v_spendable bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from group_member where group_id = p_group and user_id = v_me) then
    raise exception 'not a member'; end if;

  select total_steps_lifetime - total_steps_spent into v_spendable
    from wallet where user_id = v_me for update;
  if coalesce(v_spendable,0) < p_cost then raise exception 'insufficient funds'; end if;

  update wallet set total_steps_spent = total_steps_spent + p_cost, updated_at = now()
    where user_id = v_me;
  insert into group_house_contribution(group_id, user_id, steps_spent)
    values (p_group, v_me, p_cost)
    on conflict (group_id, user_id) do update
      set steps_spent = group_house_contribution.steps_spent + p_cost;
  update group_house set level = greatest(level, p_new_level), updated_at = now()
    where group_id = p_group;
end; $$;
