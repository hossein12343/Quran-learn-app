-- Applied 2026-09-27 as migration `learning_state`.
-- Per-account memorisation state (review schedule, exact held ayat, sealed
-- levels, hard words, today's plan) so it survives a new device or Safari
-- clearing a site's data after ~7 days unused. See
-- lib/shared/services/learning_sync.dart for the format and merge rules.
-- Owner-only. Deliberately not a column on `profiles`, which circle owners
-- can read.

create table public.learning_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint learning_state_size check (pg_column_size(data) < 524288)
);

alter table public.learning_state enable row level security;

create policy "own learning_state" on public.learning_state
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.learning_state to authenticated;
revoke all on public.learning_state from anon;
