-- ===========================================================================
-- Anonymous shared prayer requests.
--
-- The one place the app deliberately shares faith content between users. It is
-- kept safe by construction:
--   * Requests carry an author only for rate-limiting — it is NEVER returned to
--     anyone reading the wall (random_prayer_request omits it).
--   * All access goes through SECURITY DEFINER functions; RLS on the tables has
--     no permissive policies, so a client cannot read/insert rows directly.
--   * Sending is capped at 2 per rolling 7 days, server-side.
--   * Reports auto-hide a request once enough distinct people flag it.
--
-- Run this in the Supabase SQL editor after schema.sql. Anonymous sign-ins must
-- be enabled (Auth settings) — the app authenticates anonymously.
-- ===========================================================================

create table if not exists prayer_request (
  id           uuid primary key default gen_random_uuid(),
  author       uuid not null references auth.users(id) on delete cascade,
  body         text not null,
  pray_count   int  not null default 0,
  report_count int  not null default 0,
  status       text not null default 'visible' check (status in ('visible', 'hidden')),
  created_at   timestamptz not null default now()
);

-- One row per (request, prayer) so a pray can't be double-counted, and so we can
-- avoid re-showing someone a request they already prayed for.
create table if not exists prayer_request_pray (
  request_id uuid not null references prayer_request(id) on delete cascade,
  pray_by    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (request_id, pray_by)
);

-- One row per (request, reporter) so reports dedupe.
create table if not exists prayer_request_report (
  request_id uuid not null references prayer_request(id) on delete cascade,
  reporter   uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (request_id, reporter)
);

create index if not exists prayer_request_author_time_idx
  on prayer_request (author, created_at desc);
create index if not exists prayer_request_visible_idx
  on prayer_request (status) where status = 'visible';

-- Lock the tables: RLS on, and no policies at all → no direct client access.
-- Everything flows through the definer functions below.
alter table prayer_request        enable row level security;
alter table prayer_request_pray   enable row level security;
alter table prayer_request_report enable row level security;

-- ---------------------------------------------------------------------------
-- How many requests the caller may still send this rolling week.
-- ---------------------------------------------------------------------------
create or replace function prayer_request_allowance()
returns int
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_used int;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  select count(*) into v_used from prayer_request
    where author = v_user and created_at > now() - interval '7 days';
  return greatest(0, 2 - v_used);   -- keep in step with kMaxPrayerRequestsPerWeek
end; $$;

-- ---------------------------------------------------------------------------
-- Send a request. Enforces the length cap and the 2-per-7-days limit. Returns
-- the caller's remaining allowance after the insert.
-- ---------------------------------------------------------------------------
create or replace function submit_prayer_request(p_body text)
returns int
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_used int;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if length(v_body) = 0 then raise exception 'empty request'; end if;
  -- Mirror kPrayerRequestMaxChars in lib/core/prayer_requests.dart.
  if length(v_body) > 280 then raise exception 'request too long'; end if;

  select count(*) into v_used from prayer_request
    where author = v_user and created_at > now() - interval '7 days';
  if v_used >= 2 then
    raise exception 'You have used your 2 requests for this week';
  end if;

  insert into prayer_request(author, body) values (v_user, v_body);
  return greatest(0, 2 - (v_used + 1));
end; $$;

-- ---------------------------------------------------------------------------
-- One random visible request that isn't the caller's and that they haven't
-- prayed for yet. Author is intentionally NOT selected — the wall is anonymous.
-- ---------------------------------------------------------------------------
create or replace function random_prayer_request()
returns table (id uuid, body text, pray_count int, created_at timestamptz)
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  return query
    select pr.id, pr.body, pr.pray_count, pr.created_at
    from prayer_request pr
    where pr.status = 'visible'
      and pr.author <> v_user
      and not exists (
        select 1 from prayer_request_pray p
        where p.request_id = pr.id and p.pray_by = v_user)
    order by random()
    limit 1;
end; $$;

-- ---------------------------------------------------------------------------
-- Record that the caller prayed for a request (idempotent). Returns the new
-- pray count. Praying for your own request is rejected.
-- ---------------------------------------------------------------------------
create or replace function pray_for_request(p_request_id uuid)
returns int
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_author uuid;
  v_inserted int;
  v_count int;
begin
  if v_user is null then raise exception 'not authenticated'; end if;

  select author, pray_count into v_author, v_count
    from prayer_request where id = p_request_id and status = 'visible';
  if v_author is null then raise exception 'request not found'; end if;
  if v_author = v_user then raise exception 'cannot pray for your own request'; end if;

  insert into prayer_request_pray(request_id, pray_by)
    values (p_request_id, v_user)
    on conflict (request_id, pray_by) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then return v_count; end if;   -- already prayed: no double count

  update prayer_request set pray_count = pray_count + 1
    where id = p_request_id
    returning pray_count into v_count;
  return v_count;
end; $$;

-- ---------------------------------------------------------------------------
-- Total prayers across the caller's own requests — powers the app's
-- "someone prayed for you" notification (it watches this for growth).
-- ---------------------------------------------------------------------------
create or replace function my_requests_pray_total()
returns int
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_total int;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  select coalesce(sum(pray_count), 0) into v_total
    from prayer_request where author = v_user;
  return v_total;
end; $$;

-- ---------------------------------------------------------------------------
-- Flag a request (idempotent per reporter). Auto-hides once enough distinct
-- people report it. Mirror the threshold in lib/core/prayer_requests.dart.
-- ---------------------------------------------------------------------------
create or replace function report_prayer_request(p_request_id uuid)
returns void
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_inserted int;
  v_reports int;
begin
  if v_user is null then raise exception 'not authenticated'; end if;

  insert into prayer_request_report(request_id, reporter)
    values (p_request_id, v_user)
    on conflict (request_id, reporter) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then return; end if;   -- already reported

  update prayer_request set report_count = report_count + 1
    where id = p_request_id
    returning report_count into v_reports;

  if v_reports >= 3 then                    -- kPrayerRequestReportThreshold
    update prayer_request set status = 'hidden' where id = p_request_id;
  end if;
end; $$;
