alter table public.plant_listings
  add column if not exists phone_number text,
  add column if not exists image_urls text[] not null default '{}';

update public.plant_listings
set image_urls = array[image_url]
where image_url is not null
  and image_url <> ''
  and coalesce(array_length(image_urls, 1), 0) = 0;
