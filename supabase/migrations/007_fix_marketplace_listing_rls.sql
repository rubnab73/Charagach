-- Ensure marketplace listing RLS policies exist and are correct.
-- Safe to run multiple times.

alter table public.plant_listings enable row level security;

-- Recreate read policy (active + sold public, owner can always read).
drop policy if exists "active listings are publicly readable" on public.plant_listings;
drop policy if exists "active and sold listings are publicly readable" on public.plant_listings;

create policy "active and sold listings are publicly readable"
on public.plant_listings
for select
using (
  status in ('active', 'sold')
  or auth.uid() = seller_id
);

-- Recreate write policies.
drop policy if exists "users can create their own listings" on public.plant_listings;
drop policy if exists "users can update their own listings" on public.plant_listings;
drop policy if exists "users can delete their own listings" on public.plant_listings;

create policy "users can create their own listings"
on public.plant_listings
for insert
to authenticated
with check (
  auth.uid() = seller_id
);

create policy "users can update their own listings"
on public.plant_listings
for update
to authenticated
using (auth.uid() = seller_id)
with check (auth.uid() = seller_id);

create policy "users can delete their own listings"
on public.plant_listings
for delete
to authenticated
using (auth.uid() = seller_id);
