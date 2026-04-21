-- Fix avatar upload RLS failures.
-- This allows any authenticated user to manage files in the avatars bucket.
-- (Still blocks anonymous users.)

drop policy if exists "authenticated users can upload own avatar" on storage.objects;
drop policy if exists "authenticated users can update own avatar" on storage.objects;
drop policy if exists "authenticated users can delete own avatar" on storage.objects;

create policy "authenticated users can upload avatars"
on storage.objects
for insert
with check (
  bucket_id = 'avatars'
  and auth.uid() is not null
);

create policy "authenticated users can update avatars"
on storage.objects
for update
using (
  bucket_id = 'avatars'
  and auth.uid() is not null
)
with check (
  bucket_id = 'avatars'
  and auth.uid() is not null
);

create policy "authenticated users can delete avatars"
on storage.objects
for delete
using (
  bucket_id = 'avatars'
  and auth.uid() is not null
);
