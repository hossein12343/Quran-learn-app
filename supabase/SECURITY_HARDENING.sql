-- Production RLS hardening for Quran Learn.
-- Run in the connected Supabase project's SQL editor, then verify using
-- Database > Linter. This script is idempotent but assumes the documented
-- user_id ownership columns exist.

begin;

alter table public.profiles enable row level security;
alter table public.surah_progress enable row level security;
alter table public.bookmarks enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.logs enable row level security;

-- Remove broad/stale policies before establishing owner-only policies.
drop policy if exists "Users can view their own profile" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can view their own profile" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "Users can update their own profile" on public.profiles
  for update to authenticated using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "Users manage own surah progress" on public.surah_progress;
create policy "Users manage own surah progress" on public.surah_progress
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users manage own bookmarks" on public.bookmarks;
create policy "Users manage own bookmarks" on public.bookmarks
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users manage own push subscriptions" on public.push_subscriptions;
create policy "Users manage own push subscriptions" on public.push_subscriptions
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Do not expose operational stack traces through the public API. Replace
-- client-side error logging with a rate-limited Edge Function before adding
-- any INSERT policy for this table.
drop policy if exists "Anyone can create logs" on public.logs;
drop policy if exists "Authenticated users can create logs" on public.logs;
revoke all on table public.logs from anon, authenticated;

commit;
