-- ============================================================
-- Medical Wallet – Supabase Schema
-- Run this in: Supabase Dashboard → SQL Editor → Run
-- ============================================================

-- Profiles (one row per auth user)
create table if not exists profiles (
  id            uuid references auth.users on delete cascade primary key,
  name          text not null default '',
  sex           text not null default 'Male',
  avatar_type   text,
  avatar_index  integer,
  avatar_image  text,
  created_at    timestamptz default now()
);

-- Prescriptions
create table if not exists prescriptions (
  id                  text primary key,
  user_id             uuid references auth.users on delete cascade not null,
  name                text not null,
  refill_date         timestamptz not null,
  instructions        text not null default '',
  notification_hour   integer,
  notification_minute integer,
  created_at          timestamptz default now()
);

-- Medications
create table if not exists medications (
  id                  text primary key,
  user_id             uuid references auth.users on delete cascade not null,
  doctor_name         text not null default '',
  prescription_name   text not null,
  instructions        text not null default '',
  notification_hour   integer,
  notification_minute integer,
  created_at          timestamptz default now()
);

-- Appointments
create table if not exists appointments (
  id                    text primary key,
  user_id               uuid references auth.users on delete cascade not null,
  title                 text not null,
  doctor_name           text not null default '',
  location              text not null default '',
  notes                 text not null default '',
  appointment_date_time timestamptz not null,
  created_at            timestamptz default now()
);

-- Vitals
create table if not exists vitals (
  id                text primary key,
  user_id           uuid references auth.users on delete cascade not null,
  recorded_at       timestamptz not null,
  bp_systolic       integer,
  bp_diastolic      integer,
  weight            double precision,
  weight_unit       text default 'kg',
  sugar_level       double precision,
  sugar_unit        text default 'mg/dL',
  cholesterol       double precision,
  cholesterol_unit  text default 'mg/dL',
  colonoscopy_date  text,
  period_date       text,
  mammogram_date    text,
  risk_level        text not null default 'Low',
  notes             text not null default '',
  created_at        timestamptz default now()
);

-- Activities
create table if not exists activities (
  id          text primary key,
  user_id     uuid references auth.users on delete cascade not null,
  type        text not null,
  walk_type   text not null default 'Regular',
  distance    double precision,
  duration    double precision,
  recorded_at timestamptz not null,
  notes       text not null default '',
  created_at  timestamptz default now()
);

-- ── Row Level Security ──────────────────────────────────────

alter table profiles     enable row level security;
alter table prescriptions enable row level security;
alter table medications   enable row level security;
alter table appointments  enable row level security;
alter table vitals        enable row level security;
alter table activities    enable row level security;

-- Profiles policies
create policy "profiles_select" on profiles for select using (auth.uid() = id);
create policy "profiles_insert" on profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on profiles for update using (auth.uid() = id);

-- All other tables: full CRUD for own rows only
create policy "prescriptions_all" on prescriptions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "medications_all"   on medications   for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "appointments_all"  on appointments  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "vitals_all"        on vitals        for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "activities_all"    on activities    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Auto-create profile row on signup ──────────────────────

create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, name, sex)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'sex', 'Male')
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();
