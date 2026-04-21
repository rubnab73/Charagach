-- If older users exist without profile rows, profile save may attempt INSERT and hit RLS.
-- This backfills profiles for all existing auth users and keeps owner-only write rules.

insert into public.profiles (id, email, full_name)
select
  u.id,
  u.email,
  coalesce(u.raw_user_meta_data ->> 'full_name', '')
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;

-- Recreate owner-write policies explicitly (idempotent).
drop policy if exists "users can insert their own profile" on public.profiles;
drop policy if exists "users can update their own profile" on public.profiles;

create policy "users can insert their own profile"
on public.profiles
for insert
with check (auth.uid() = id);

create policy "users can update their own profile"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);
