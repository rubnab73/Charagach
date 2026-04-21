-- Align plant_listings schema with app payload expectations.
-- Safe to run multiple times.

alter table public.plant_listings
  add column if not exists image_urls text[] not null default '{}';

update public.plant_listings
set image_urls = array[image_url]
where image_url is not null
  and image_url <> ''
  and coalesce(array_length(image_urls, 1), 0) = 0;

-- Keep the existing trigger if already present; create only if missing.
do $$
begin
  if not exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where t.tgname = 'set_plant_listings_updated_at'
      and n.nspname = 'public'
      and c.relname = 'plant_listings'
  ) then
    create trigger set_plant_listings_updated_at
      before update on public.plant_listings
      for each row execute function public.set_updated_at();
  end if;
end $$;
