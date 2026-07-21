-- FIX: infinite recursion in the group RLS policies (Postgres error 42P17).
-- Run this once in the Supabase SQL Editor if you already ran social.sql before
-- 2026-07-18. A fresh social.sql already includes this fix.
--
-- Cause: the group_member "see co-members" policy queried group_member itself,
-- and groupe/group_house policies queried it too, so RLS recursed forever.
-- Fix: check membership through a SECURITY DEFINER function that bypasses RLS.

create or replace function is_member_of(p_group uuid) returns boolean
language sql security definer stable as $$
  select exists (
    select 1 from group_member
    where group_id = p_group and user_id = auth.uid()
  );
$$;

drop policy if exists "see groups you're in" on groupe;
create policy "see groups you're in" on groupe for select using (is_member_of(id));

drop policy if exists "see co-members" on group_member;
create policy "see co-members" on group_member for select using (is_member_of(group_id));

drop policy if exists "see own group house" on group_house;
create policy "see own group house" on group_house for select using (is_member_of(group_id));

drop policy if exists "see house contributions" on group_house_contribution;
create policy "see house contributions" on group_house_contribution for select
  using (is_member_of(group_id));
