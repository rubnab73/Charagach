create table if not exists public.caregiver_reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.plant_sitting_bookings(id) on delete cascade,
  caregiver_id uuid not null references public.caregivers(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  rating numeric(2,1) not null check (rating >= 1 and rating <= 5),
  comment text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_caregiver_reviews_caregiver_id
  on public.caregiver_reviews(caregiver_id);

create index if not exists idx_caregiver_reviews_reviewer_id
  on public.caregiver_reviews(reviewer_id);

alter table public.caregiver_reviews enable row level security;

create or replace function public.refresh_caregiver_review_stats(p_caregiver_id uuid)
returns void
language plpgsql
as $$
begin
  update public.caregivers
  set
    rating = coalesce(
      (
        select round(avg(r.rating)::numeric, 1)
        from public.caregiver_reviews r
        where r.caregiver_id = p_caregiver_id
      ),
      0
    ),
    review_count = coalesce(
      (
        select count(*)
        from public.caregiver_reviews r
        where r.caregiver_id = p_caregiver_id
      ),
      0
    ),
    updated_at = timezone('utc', now())
  where id = p_caregiver_id;
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

drop trigger if exists set_caregiver_reviews_updated_at on public.caregiver_reviews;
create trigger set_caregiver_reviews_updated_at
  before update on public.caregiver_reviews
  for each row execute procedure public.set_updated_at();

drop trigger if exists refresh_caregiver_review_stats_trigger on public.caregiver_reviews;
create trigger refresh_caregiver_review_stats_trigger
  after insert or update or delete on public.caregiver_reviews
  for each row execute procedure public.handle_caregiver_review_change();

create policy "owners and caregivers can read caregiver reviews"
on public.caregiver_reviews
for select
using (
  auth.uid() = reviewer_id
  or auth.uid() = caregiver_id
);

create policy "owners can create reviews for completed bookings"
on public.caregiver_reviews
for insert
with check (
  auth.uid() = reviewer_id
  and exists (
    select 1
    from public.plant_sitting_bookings b
    where b.id = booking_id
      and b.owner_id = auth.uid()
      and b.caregiver_id = caregiver_id
      and b.status = 'completed'
  )
);

create policy "reviewers can update their own reviews"
on public.caregiver_reviews
for update
using (auth.uid() = reviewer_id)
with check (auth.uid() = reviewer_id);

create policy "reviewers can delete their own reviews"
on public.caregiver_reviews
for delete
using (auth.uid() = reviewer_id);
