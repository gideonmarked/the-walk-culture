-- ===========================================================================
-- Player feedback — bug reports and feature ideas from inside the app.
--
-- Same shape as prayer_requests.sql: RLS is ON with NO permissive policies, so
-- a client cannot read or write these tables directly. Everything goes through
-- the SECURITY DEFINER function below, which owns the rules.
--
--   * Writes only. Nobody — not even the author — reads feedback back through
--     the API; you read it in the Supabase dashboard. A report can name other
--     players or quote a bug, so there is no reason to expose a read path.
--   * Idempotent per (author, client_id), so the app can safely retry a report
--     it queued offline without filing it twice.
--   * Capped at 10 a day per account. Generous on purpose — a beta tester
--     having a bad afternoon should not be rate-limited out of telling us.
--
-- Run this in the Supabase SQL editor after schema.sql. Anonymous sign-ins must
-- be enabled (Auth settings) — the app authenticates anonymously.
-- ===========================================================================

create table if not exists feedback (
  id          uuid primary key default gen_random_uuid(),
  author      uuid not null references auth.users(id) on delete cascade,

  -- Client-generated id, unique per author. The dedupe key for retries.
  client_id   text not null,

  kind        text not null check (kind in ('bug', 'idea', 'other')),
  body        text not null,

  -- Only ever what the player typed into the optional email field.
  contact     text,

  -- Build/progress context the app shows the player before sending. Never
  -- reflection content (see design invariant #3).
  diagnostics jsonb not null default '{}'::jsonb,
  app_version text,

  -- Triage state, for whoever works the queue.
  status      text not null default 'new'
                check (status in ('new', 'triaged', 'closed')),
  created_at  timestamptz not null default now(),

  unique (author, client_id)
);

create index if not exists feedback_triage_idx
  on feedback (status, created_at desc);
create index if not exists feedback_author_time_idx
  on feedback (author, created_at desc);

-- Locked: RLS on, no policies → no direct client access at all.
alter table feedback enable row level security;

-- ---------------------------------------------------------------------------
-- File a report. Returns how many the caller may still send today.
--
-- A repeat of the same client_id is accepted and ignored, so a retry after a
-- timeout that actually succeeded is a no-op rather than a duplicate — and it
-- deliberately does NOT consume allowance.
-- ---------------------------------------------------------------------------
create or replace function submit_feedback(
  p_client_id   text,
  p_kind        text,
  p_body        text,
  p_contact     text default null,
  p_diagnostics jsonb default '{}'::jsonb,
  p_app_version text default null
)
returns int
language plpgsql security definer as $$
declare
  v_user uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_used int;
  v_inserted int;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if coalesce(btrim(p_client_id), '') = '' then
    raise exception 'missing client id';
  end if;
  if length(v_body) = 0 then raise exception 'empty report'; end if;
  -- Mirror kFeedbackMaxChars in lib/core/feedback.dart.
  if length(v_body) > 1000 then raise exception 'report too long'; end if;
  if p_kind not in ('bug', 'idea', 'other') then
    raise exception 'unknown feedback kind';
  end if;
  -- Mirror kFeedbackContactMaxChars. The client caps this too, but the client
  -- is not what we trust.
  if length(coalesce(p_contact, '')) > 120 then
    raise exception 'contact too long';
  end if;

  select count(*) into v_used from feedback
    where author = v_user and created_at > now() - interval '1 day';
  if v_used >= 10 then
    raise exception 'Thanks — that is all the reports we can take today';
  end if;

  insert into feedback (author, client_id, kind, body, contact,
                        diagnostics, app_version)
  values (v_user, btrim(p_client_id), p_kind, v_body,
          nullif(btrim(coalesce(p_contact, '')), ''),
          coalesce(p_diagnostics, '{}'::jsonb), p_app_version)
  on conflict (author, client_id) do nothing;

  get diagnostics v_inserted = row_count;
  return greatest(0, 10 - (v_used + v_inserted));
end; $$;

revoke all on function submit_feedback(text, text, text, text, jsonb, text)
  from public;
grant execute on function submit_feedback(text, text, text, text, jsonb, text)
  to authenticated;
