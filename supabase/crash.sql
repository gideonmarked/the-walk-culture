-- ===========================================================================
-- Crash / uncaught-error reports from the app.
--
-- Same posture as feedback.sql: RLS on with NO permissive policies, one
-- SECURITY DEFINER function, write-only. You read the queue in the dashboard.
--
-- The one interesting difference is the UPSERT. A crash that fires every frame
-- is ONE bug, so the client collapses repeats into a single report with an
-- occurrence count and re-sends it as that count grows. So a repeat submission
-- of the same fingerprint UPDATES the row (highest count, widest time window)
-- instead of inserting — otherwise a single layout bug would bury the table.
--
-- Run after schema.sql. Anonymous sign-ins must be enabled.
-- ===========================================================================

create table if not exists crash_report (
  id           uuid primary key default gen_random_uuid(),
  author       uuid not null references auth.users(id) on delete cascade,

  -- Client-generated id for this report row; makes a retry idempotent.
  client_id    text not null,

  -- Stable key for "this same bug" — normalized message + top frames.
  fingerprint  text not null,

  kind         text not null check (kind in ('flutter', 'async', 'manual')),
  message      text not null,
  stack        text,

  -- Flutter's own label for the source, e.g. 'widgets library'.
  library      text,

  occurrences  int  not null default 1 check (occurrences > 0),
  first_seen   timestamptz not null default now(),
  last_seen    timestamptz not null default now(),

  diagnostics  jsonb not null default '{}'::jsonb,
  app_version  text,

  status       text not null default 'new'
                 check (status in ('new', 'triaged', 'closed')),
  created_at   timestamptz not null default now(),

  unique (author, client_id)
);

-- Triage by "what's biting the most people the hardest".
create index if not exists crash_report_fingerprint_idx
  on crash_report (fingerprint, last_seen desc);
create index if not exists crash_report_triage_idx
  on crash_report (status, last_seen desc);

alter table crash_report enable row level security;

-- ---------------------------------------------------------------------------
-- File (or update) a crash report.
--
-- Deliberately NOT rate-limited by count the way feedback is: the client
-- already collapses repeats into one row per bug, so the natural ceiling is
-- "distinct bugs this player hit", which is exactly what we want to see. The
-- length caps below are the real defence against a runaway payload.
-- ---------------------------------------------------------------------------
create or replace function submit_crash(
  p_client_id   text,
  p_fingerprint text,
  p_kind        text,
  p_message     text,
  p_stack       text default null,
  p_library     text default null,
  p_occurrences int default 1,
  p_first_seen  timestamptz default now(),
  p_last_seen   timestamptz default now(),
  p_diagnostics jsonb default '{}'::jsonb,
  p_app_version text default null
)
returns void
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_message text := btrim(coalesce(p_message, ''));
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if coalesce(btrim(p_client_id), '') = '' then
    raise exception 'missing client id';
  end if;
  if coalesce(btrim(p_fingerprint), '') = '' then
    raise exception 'missing fingerprint';
  end if;
  if length(v_message) = 0 then raise exception 'empty crash message'; end if;
  if p_kind not in ('flutter', 'async', 'manual') then
    raise exception 'unknown crash kind';
  end if;

  insert into crash_report (
    author, client_id, fingerprint, kind, message, stack, library,
    occurrences, first_seen, last_seen, diagnostics, app_version
  ) values (
    v_user,
    btrim(p_client_id),
    left(btrim(p_fingerprint), 300),          -- mirrors crashFingerprint()
    p_kind,
    left(v_message, 500),                     -- mirrors kCrashMessageMaxChars
    left(coalesce(p_stack, ''), 4000),        -- mirrors kCrashStackMaxChars
    p_library,
    greatest(1, coalesce(p_occurrences, 1)),
    coalesce(p_first_seen, now()),
    coalesce(p_last_seen, now()),
    coalesce(p_diagnostics, '{}'::jsonb),
    p_app_version
  )
  on conflict (author, client_id) do update set
    -- A re-send is the same bug seen more times. Never let the count go
    -- backwards if reports arrive out of order.
    occurrences = greatest(crash_report.occurrences, excluded.occurrences),
    last_seen   = greatest(crash_report.last_seen, excluded.last_seen),
    first_seen  = least(crash_report.first_seen, excluded.first_seen),
    diagnostics = excluded.diagnostics,
    app_version = excluded.app_version;
end; $$;

revoke all on function submit_crash(text, text, text, text, text, text, int,
  timestamptz, timestamptz, jsonb, text) from public;
grant execute on function submit_crash(text, text, text, text, text, text, int,
  timestamptz, timestamptz, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Triage helper: the loudest open bugs. Run it in the dashboard.
--
--   select fingerprint, sum(occurrences) as hits, count(distinct author) as users,
--          max(last_seen) as latest, min(app_version) as since
--     from crash_report where status = 'new'
--    group by fingerprint order by users desc, hits desc;
-- ---------------------------------------------------------------------------
