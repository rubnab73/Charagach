create extension if not exists "pgcrypto";

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  full_name text,
  city text,
  avatar_url text,
  is_caregiver boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.caregivers (
  id uuid primary key references public.profiles(id) on delete cascade,
  bio text,
  price_per_day numeric(10,2) not null default 0 check (price_per_day >= 0),
  years_experience integer not null default 0 check (years_experience >= 0),
  location text,
  specialties text[] not null default '{}',
  is_available boolean not null default true,
  rating numeric(2,1) not null default 0 check (rating >= 0 and rating <= 5),
  review_count integer not null default 0 check (review_count >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.plant_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  species text not null,
  price numeric(10,2) not null check (price >= 0),
  category text not null check (category in ('Indoor', 'Outdoor', 'Succulents', 'Tropical', 'Herbs')),
  condition text not null check (condition in ('Excellent', 'Good', 'Fair')),
  description text,
  city text,
  phone_number text,
  image_url text,
  image_urls text[] not null default '{}',
  status text not null default 'active' check (status in ('active', 'sold', 'archived')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.plant_sitting_bookings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  caregiver_id uuid not null references public.caregivers(id) on delete restrict,
  plant_name text,
  notes text,
  start_date date not null,
  end_date date not null,
  total_price numeric(10,2) not null default 0 check (total_price >= 0),
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'completed', 'cancelled')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint booking_date_order check (end_date >= start_date)
);

create table if not exists public.plant_care_tips (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  summary text not null,
  content text not null,
  category text not null check (category in ('Watering', 'Sunlight', 'Fertilizing', 'Repotting', 'Pests', 'General')),
  difficulty text not null check (difficulty in ('Beginner', 'Intermediate', 'Advanced')),
  read_minutes integer not null default 1 check (read_minutes > 0),
  published boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_profiles_is_caregiver on public.profiles(is_caregiver);
create index if not exists idx_caregivers_available on public.caregivers(is_available);
create index if not exists idx_plant_listings_seller_id on public.plant_listings(seller_id);
create index if not exists idx_plant_listings_category on public.plant_listings(category);
create index if not exists idx_plant_listings_status on public.plant_listings(status);
create index if not exists idx_bookings_owner_id on public.plant_sitting_bookings(owner_id);
create index if not exists idx_bookings_caregiver_id on public.plant_sitting_bookings(caregiver_id);
create index if not exists idx_bookings_status on public.plant_sitting_bookings(status);
create index if not exists idx_tips_category on public.plant_care_tips(category);
create index if not exists idx_tips_published on public.plant_care_tips(published);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do update
    set email = excluded.email,
        full_name = case
          when excluded.full_name is null or excluded.full_name = '' then public.profiles.full_name
          else excluded.full_name
        end,
        updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

drop trigger if exists set_caregivers_updated_at on public.caregivers;
create trigger set_caregivers_updated_at
  before update on public.caregivers
  for each row execute procedure public.set_updated_at();

drop trigger if exists set_plant_listings_updated_at on public.plant_listings;
create trigger set_plant_listings_updated_at
  before update on public.plant_listings
  for each row execute procedure public.set_updated_at();

drop trigger if exists set_bookings_updated_at on public.plant_sitting_bookings;
create trigger set_bookings_updated_at
  before update on public.plant_sitting_bookings
  for each row execute procedure public.set_updated_at();

drop trigger if exists set_tips_updated_at on public.plant_care_tips;
create trigger set_tips_updated_at
  before update on public.plant_care_tips
  for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.caregivers enable row level security;
alter table public.plant_listings enable row level security;
alter table public.plant_sitting_bookings enable row level security;
alter table public.plant_care_tips enable row level security;

-- profiles
create policy "profiles are publicly readable"
on public.profiles
for select
using (true);

create policy "users can insert their own profile"
on public.profiles
for insert
with check (auth.uid() = id);

create policy "users can update their own profile"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- caregivers
create policy "caregivers are publicly readable"
on public.caregivers
for select
using (true);

create policy "users can create their own caregiver profile"
on public.caregivers
for insert
with check (auth.uid() = id);

create policy "users can update their own caregiver profile"
on public.caregivers
for update
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "users can delete their own caregiver profile"
on public.caregivers
for delete
using (auth.uid() = id);

-- plant listings
create policy "active listings are publicly readable"
on public.plant_listings
for select
using (status = 'active' or auth.uid() = seller_id);

create policy "users can create their own listings"
on public.plant_listings
for insert
with check (auth.uid() = seller_id);

create policy "users can update their own listings"
on public.plant_listings
for update
using (auth.uid() = seller_id)
with check (auth.uid() = seller_id);

create policy "users can delete their own listings"
on public.plant_listings
for delete
using (auth.uid() = seller_id);

-- bookings
create policy "owners and caregivers can read their bookings"
on public.plant_sitting_bookings
for select
using (
  auth.uid() = owner_id
  or auth.uid() = caregiver_id
);

create policy "owners can create their own bookings"
on public.plant_sitting_bookings
for insert
with check (auth.uid() = owner_id);

create policy "owners can update pending bookings"
on public.plant_sitting_bookings
for update
using (auth.uid() = owner_id and status = 'pending')
with check (auth.uid() = owner_id);

create policy "caregivers can manage booking status"
on public.plant_sitting_bookings
for update
using (auth.uid() = caregiver_id)
with check (auth.uid() = caregiver_id);

create policy "owners can delete pending bookings"
on public.plant_sitting_bookings
for delete
using (auth.uid() = owner_id and status = 'pending');

-- plant care tips
create policy "published tips are publicly readable"
on public.plant_care_tips
for select
using (published = true);

-- storage buckets
insert into storage.buckets (id, name, public)
values
  ('listing-images', 'listing-images', true),
  ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "listing images are publicly readable"
on storage.objects
for select
using (bucket_id = 'listing-images');

create policy "authenticated users can upload listing images to own folder"
on storage.objects
for insert
with check (
  bucket_id = 'listing-images'
  and auth.role() = 'authenticated'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "authenticated users can update own listing images"
on storage.objects
for update
using (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "authenticated users can delete own listing images"
on storage.objects
for delete
using (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "avatars are publicly readable"
on storage.objects
for select
using (bucket_id = 'avatars');

create policy "authenticated users can upload own avatar"
on storage.objects
for insert
with check (
  bucket_id = 'avatars'
  and auth.role() = 'authenticated'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "authenticated users can update own avatar"
on storage.objects
for update
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "authenticated users can delete own avatar"
on storage.objects
for delete
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

insert into public.plant_care_tips (title, summary, content, category, difficulty, read_minutes)
values
  (
    'The Finger Test',
    'Never guess soil moisture before watering.',
    'Push your finger about an inch into the soil. If it feels dry, water the plant. If it still feels moist, wait another day or two. Overwatering is one of the most common reasons houseplants decline.',
    'Watering',
    'Beginner',
    2
  ),
  (
    'Bright Indirect Light Explained',
    'Know the difference between direct and indirect light.',
    'Bright indirect light means a spot close to a bright window where harsh rays do not strike the leaves directly. Tropical plants such as Monstera, Pothos, and Philodendron typically prefer this condition. Succulents usually want several hours of direct sun.',
    'Sunlight',
    'Beginner',
    3
  ),
  (
    'Feed Only During Active Growth',
    'Fertilize in spring and summer, not year-round.',
    'Most indoor plants actively grow during spring and summer. Feed them with a balanced fertilizer every two to four weeks during that period, then reduce or stop feeding in winter. Too much fertilizer can burn roots and cause salt buildup.',
    'Fertilizing',
    'Intermediate',
    4
  ),
  (
    'When to Repot',
    'A slightly bigger pot is enough.',
    'Repot when roots come out of drainage holes, when the pot dries unusually quickly, or when growth has stalled despite good care. Move up only one to two inches in pot diameter to avoid excess wet soil around the roots.',
    'Repotting',
    'Intermediate',
    4
  ),
  (
    'Watch for Spider Mites',
    'Catch pests early before they spread.',
    'Inspect leaf undersides regularly for fine webbing, pale speckles, or tiny moving dots. Isolate infected plants right away. Wipe leaves, increase humidity, and use neem or insecticidal soap consistently over a few weeks.',
    'Pests',
    'Intermediate',
    4
  ),
  (
    'Clean Dusty Leaves',
    'Cleaner leaves photosynthesize better.',
    'Wipe broad leaves gently with a damp cloth every few weeks. Dust blocks light and can reduce photosynthesis. For smaller-leaf plants, a gentle lukewarm rinse often works better than wiping each leaf individually.',
    'General',
    'Beginner',
    2
  )
on conflict do nothing;
