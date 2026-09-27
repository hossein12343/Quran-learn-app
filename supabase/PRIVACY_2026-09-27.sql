-- Applied 2026-09-27 as migrations `privacy_member_profiles_and_account_deletion`
-- and `circle_owners_no_full_profiles`.

-- What a circle owner may see about each member: name, points and streak.
-- Replaces reading members' whole profile rows, which also carried their
-- saved location, timezone and reminder times.
create or replace function public.circle_member_profiles(p_circle_id uuid)
returns table (
  user_id uuid, joined_at timestamptz, display_name text, total_xp integer,
  current_streak integer, longest_streak integer, last_active_date text,
  is_pro boolean, weekly_xp_base integer, weekly_xp_week_start text
)
language sql stable security definer set search_path = ''
as $$
  select cm.user_id, cm.joined_at, p.display_name, p.total_xp,
         p.current_streak, p.longest_streak, p.last_active_date, p.is_pro,
         p.weekly_xp_base, p.weekly_xp_week_start
  from public.circle_members cm
  join public.circles c on c.id = cm.circle_id
  join public.profiles p on p.id = cm.user_id
  where cm.circle_id = p_circle_id
    and c.owner_id = (select auth.uid());
$$;
revoke execute on function public.circle_member_profiles(uuid) from public, anon;
grant execute on function public.circle_member_profiles(uuid) to authenticated;

-- Deletes the caller's own account; every table cascades from auth.users.
create or replace function public.delete_own_account()
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  delete from auth.users where id = (select auth.uid());
end;
$$;
revoke execute on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

-- A prayer-time reminder needs a town, not a doorstep: keep ~1 km.
update public.profiles
set reminder_lat = round(reminder_lat::numeric, 2),
    reminder_lon = round(reminder_lon::numeric, 2)
where reminder_lat is not null or reminder_lon is not null;

-- Second step, once the app reading members through the function above
-- was live: owners no longer read members' profile rows directly.
drop policy if exists "circle owners can view their members' profiles"
  on public.profiles;

-- Migration `internal_app_stats`: totals-only stats for the owner, in the
-- `internal` schema the API doesn't expose. See the migration itself for
-- the full function; run with `select internal.app_stats();`.
