-- RUVYGO: schema inicial para pruebas. Ejecutar en un proyecto Supabase propio.
-- El frontend público NO debe usar claves service_role.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 60),
  created_at timestamptz not null default now()
);
create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id),
  origin_label text not null check (char_length(origin_label) between 2 and 180),
  destination_label text not null check (char_length(destination_label) between 2 and 180),
  depart_at timestamptz not null,
  seats_total int not null check (seats_total between 2 and 4),
  status text not null default 'looking' check (status in ('looking','matched','taxi_pending','confirmed','completed','cancelled')),
  created_at timestamptz not null default now()
);
create table if not exists public.trip_members (
  trip_id uuid not null references public.trips(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'requested' check (status in ('requested','accepted','declined','cancelled','completed')),
  joined_at timestamptz not null default now(),
  primary key (trip_id,user_id)
);
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id),
  reviewer_id uuid not null references public.profiles(id),
  reviewed_id uuid not null references public.profiles(id),
  rating int not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  unique(trip_id,reviewer_id,reviewed_id),
  check(reviewer_id <> reviewed_id)
);
create index if not exists trips_depart_idx on public.trips(depart_at) where status='looking';
create index if not exists trip_members_user_idx on public.trip_members(user_id);
alter table public.profiles enable row level security;
alter table public.trips enable row level security;
alter table public.trip_members enable row level security;
alter table public.reviews enable row level security;
create policy "own profile read" on public.profiles for select to authenticated using (id=auth.uid());
create policy "own profile create" on public.profiles for insert to authenticated with check(id=auth.uid());
create policy "own profile edit" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "trips browse" on public.trips for select to authenticated using(true);
create policy "trips create" on public.trips for insert to authenticated with check(creator_id=auth.uid() and depart_at>now() and status='looking');
create policy "creator cancel only" on public.trips for update to authenticated using(creator_id=auth.uid() and status='looking') with check(creator_id=auth.uid() and status in ('looking','cancelled'));
create policy "members see own" on public.trip_members for select to authenticated using(user_id=auth.uid() or exists(select 1 from public.trips t where t.id=trip_id and t.creator_id=auth.uid()));
-- Membership acceptance, seat counts, verified completion and reviews must be implemented
-- in SECURITY DEFINER server functions with explicit checks before opening writes.
create policy "reviews own read" on public.reviews for select to authenticated using(reviewer_id=auth.uid() or reviewed_id=auth.uid());
-- No direct insert policies for reviews or trip_members: prevent forged participation.
