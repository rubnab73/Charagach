-- Add phone number to listings for buyer contact.
alter table public.plant_listings
  add column if not exists phone_number text;

-- Update read policy so sold listings are still visible to everyone,
-- while archived listings remain private to owner.
drop policy if exists "active listings are publicly readable" on public.plant_listings;

create policy "active and sold listings are publicly readable"
on public.plant_listings
for select
using (
  status in ('active', 'sold')
  or auth.uid() = seller_id
);
