-- Temporary compatibility fix for marketplace photo uploads.
-- Allows any authenticated user to manage files in listing-images bucket.
-- Use this if folder-based policy still blocks uploads.

-- Keep public read for marketplace thumbnails.
drop policy if exists "listing images are publicly readable" on storage.objects;
create policy "listing images are publicly readable"
on storage.objects
for select
using (bucket_id = 'listing-images');

-- Replace strict folder policy with authenticated-only policy.
drop policy if exists "authenticated users can upload listing images to own folder" on storage.objects;
drop policy if exists "authenticated users can update own listing images" on storage.objects;
drop policy if exists "authenticated users can delete own listing images" on storage.objects;

create policy "authenticated users can upload listing images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'listing-images'
  and auth.uid() is not null
);

create policy "authenticated users can update listing images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'listing-images'
  and auth.uid() is not null
)
with check (
  bucket_id = 'listing-images'
  and auth.uid() is not null
);

create policy "authenticated users can delete listing images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'listing-images'
  and auth.uid() is not null
);
