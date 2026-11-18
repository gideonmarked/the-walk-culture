-- ===========================================================================
-- Account deletion, blocking and reporting (Google Play policy requirements).
--
--   * delete_my_account()        User Data policy: in-app account deletion that
--                                removes the account AND its data.
--   * block_user / unblock_user / block_prayer_author
--                                UGC policy: users can block other users.
--   * report_user / report_group UGC policy: users can report users and content.
--   * leave_group()              a way out of a group you no longer want.
--
-- Run AFTER schema.sql, social.sql and prayer_requests.sql. Safe to re-run.
-- The user_block table lives in social.sql and spent_purchase_token in
-- schema.sql, next to the functions that read them.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Blocking
-- ---------------------------------------------------------------------------
create or replace function block_user(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_user is null or p_user = v_me then raise exception 'cannot block yourself'; end if;
  insert into user_block(blocker, blocked) values (v_me, p_user) on conflict do nothing;
  delete from friendship
    where (user_id = v_me and friend_id = p_user)
       or (user_id = p_user and friend_id = v_me);
end; $$;

create or replace function unblock_user(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  delete from user_block where blocker = v_me and blocked = p_user;
end; $$;

-- Block the anonymous author of a prayer request without revealing who they
-- are: the author id is looked up and stored server-side only.
create or replace function block_prayer_author(p_request_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_author uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select author into v_author from prayer_request where id = p_request_id;
  if v_author is null then raise exception 'request not found'; end if;
  if v_author = v_me then raise exception 'cannot block yourself'; end if;
  insert into user_block(blocker, blocked) values (v_me, v_author) on conflict do nothing;
end; $$;

-- ---------------------------------------------------------------------------
-- Reports on users and groups. Review them in the Supabase dashboard
-- (Table editor → user_report) and set status to 'actioned' or 'dismissed'.
-- ---------------------------------------------------------------------------
create table if not exists user_report (
  id            uuid primary key default gen_random_uuid(),
  reporter      uuid not null references auth.users(id) on delete cascade,
  reported_user uuid references auth.users(id) on delete cascade,
  group_id      uuid references groupe(id) on delete cascade,
  reason        text not null,
  status        text not null default 'open'
                check (status in ('open', 'actioned', 'dismissed')),
  created_at    timestamptz not null default now(),
  check (reported_user is not null or group_id is not null)
);
create index if not exists user_report_open on user_report(status) where status = 'open';

-- No policies: clients can't read or write reports directly.
alter table user_report enable row level security;

create or replace function report_user(p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_user is null or p_user = v_me then raise exception 'invalid report'; end if;
  if exists (select 1 from user_report where reporter = v_me
             and reported_user = p_user and status = 'open') then
    return;                                   -- one open report is enough
  end if;
  insert into user_report(reporter, reported_user, reason)
    values (v_me, p_user, left(btrim(coalesce(p_reason, 'unspecified')), 200));
end; $$;

create or replace function report_group(p_group uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from groupe where id = p_group) then
    raise exception 'no such group';
  end if;
  if exists (select 1 from user_report where reporter = v_me
             and group_id = p_group and status = 'open') then
    return;
  end if;
  insert into user_report(reporter, group_id, reason)
    values (v_me, p_group, left(btrim(coalesce(p_reason, 'unspecified')), 200));
end; $$;

-- ---------------------------------------------------------------------------
-- Leave a group. When the owner leaves, the group and its house are deleted,
-- because nobody else can manage it.
-- ---------------------------------------------------------------------------
create or replace function leave_group(p_group uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from groupe where id = p_group and owner_id = v_me) then
    delete from groupe where id = p_group;      -- cascades to members + house
  else
    delete from group_member where group_id = p_group and user_id = v_me;
  end if;
end; $$;

-- ---------------------------------------------------------------------------
-- Account deletion.
--
-- Deleting the auth user cascades to every table keyed on it: wallet, ledger,
-- inventory, profile, cloud save, entitlement, receipts, ad rewards, friends,
-- groups the user owns, group memberships, prayer requests, prays, blocks,
-- reports, feedback and crash reports.
--
-- Kept, with no link to any person: the purchase tokens of consumable packs
-- already paid out (spent_purchase_token), so a recreated account can't replay
-- an old receipt. Subscription tokens are not kept, so a Google subscription
-- that is still active can be restored on a new account.
-- ---------------------------------------------------------------------------
create or replace function delete_my_account()
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  insert into public.spent_purchase_token(purchase_token, product_id)
    select purchase_token, product_id from public.purchase_receipt
    where user_id = v_me and granted_steps > 0
    on conflict (purchase_token) do nothing;

  delete from auth.users where id = v_me;
end; $$;

revoke all on function delete_my_account() from public, anon;
grant execute on function delete_my_account() to authenticated;
