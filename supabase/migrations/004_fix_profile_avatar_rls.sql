-- Ensure profile save + avatar upload works under RLS.

-- Profiles table policies (owner-only write).
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

-- Avatars storage policies.
drop policy if exists "avatars are publicly readable" on storage.objects;
drop policy if exists "authenticated users can upload own avatar" on storage.objects;
drop policy if exists "authenticated users can update own avatar" on storage.objects;
drop policy if exists "authenticated users can delete own avatar" on storage.objects;

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
