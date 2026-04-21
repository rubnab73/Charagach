-- Ensure caregiver rating/review_count updates immediately after review writes.
-- Safe to run multiple times.

create or replace function public.refresh_caregiver_review_stats(p_caregiver_id uuid)
returns void
language plpgsql
as $$
begin
  update public.caregivers c
  set
    rating = coalesce(src.avg_rating, 0),
    review_count = coalesce(src.review_count, 0),
    updated_at = timezone('utc', now())
  from (
    select
      round(avg(r.rating)::numeric, 1) as avg_rating,
      count(*)::int as review_count
    from public.caregiver_reviews r
    where r.caregiver_id = p_caregiver_id
  ) src
  where c.id = p_caregiver_id;

  -- Handle caregivers that now have zero reviews.
  if not exists (
    select 1 from public.caregiver_reviews r where r.caregiver_id = p_caregiver_id
  ) then
    update public.caregivers
    set
      rating = 0,
      review_count = 0,
      updated_at = timezone('utc', now())
    where id = p_caregiver_id;
  end if;
end;
$$;

create or replace function public.handle_caregiver_review_change()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_caregiver_review_stats(old.caregiver_id);
    return old;
  end if;

  perform public.refresh_caregiver_review_stats(new.caregiver_id);

  if tg_op = 'UPDATE' and old.caregiver_id <> new.caregiver_id then
    perform public.refresh_caregiver_review_stats(old.caregiver_id);
  end if;

  return new;
end;
$$;

drop trigger if exists refresh_caregiver_review_stats_trigger on public.caregiver_reviews;
create trigger refresh_caregiver_review_stats_trigger
  after insert or update or delete on public.caregiver_reviews
  for each row execute procedure public.handle_caregiver_review_change();

-- Backfill current caregiver stats from existing reviews.
update public.caregivers c
set
  rating = coalesce(src.avg_rating, 0),
  review_count = coalesce(src.review_count, 0),
  updated_at = timezone('utc', now())
from (
  select caregiver_id,
         round(avg(rating)::numeric, 1) as avg_rating,
         count(*)::int as review_count
  from public.caregiver_reviews
  group by caregiver_id
) src
where c.id = src.caregiver_id;

update public.caregivers c
set
  rating = 0,
  review_count = 0,
  updated_at = timezone('utc', now())
where not exists (
  select 1
  from public.caregiver_reviews r
  where r.caregiver_id = c.id
);
