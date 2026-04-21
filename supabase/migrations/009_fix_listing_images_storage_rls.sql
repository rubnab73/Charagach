-- Fix photo upload for marketplace listings.
-- Safe to run multiple times.

-- Ensure bucket exists.
insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true)
on conflict (id) do update
set public = excluded.public;

-- Reset listing-images policies only.
drop policy if exists "listing images are publicly readable" on storage.objects;
drop policy if exists "authenticated users can upload listing images to own folder" on storage.objects;
drop policy if exists "authenticated users can update own listing images" on storage.objects;
drop policy if exists "authenticated users can delete own listing images" on storage.objects;

create policy "listing images are publicly readable"
on storage.objects
for select
using (bucket_id = 'listing-images');

create policy "authenticated users can upload listing images to own folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'listing-images'
  and auth.uid() is not null
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "authenticated users can update own listing images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'listing-images'
  and auth.uid() is not null
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'listing-images'
  and auth.uid() is not null
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "authenticated users can delete own listing images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'listing-images'
  and auth.uid() is not null
  and (storage.foldername(name))[1] = auth.uid()::text
);
