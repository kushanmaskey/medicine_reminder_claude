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


-----------------


 drop trigger if exists on_auth_user_created on auth.users;
  drop function if exists handle_new_user();


  ALTER TABLE prescriptions
    ADD COLUMN IF NOT EXISTS total_pills integer,
    ADD COLUMN IF NOT EXISTS pills_per_day integer,
    ADD COLUMN IF NOT EXISTS last_decrement_date date;

  ALTER TABLE prescriptions
    ALTER COLUMN refill_date DROP NOT NULL;


     ALTER TABLE prescriptions
    ADD COLUMN IF NOT EXISTS total_pills integer,
    ADD COLUMN IF NOT EXISTS pills_per_day integer,
    ADD COLUMN IF NOT EXISTS last_decrement_date date;

  ALTER TABLE prescriptions
    ALTER COLUMN refill_date DROP NOT NULL;

      ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS phone text;


    CREATE TABLE IF NOT EXISTS appointment_alerts (
    id text PRIMARY KEY,
    appointment_id text NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    scheduled_at timestamptz NOT NULL,
    acknowledged boolean NOT NULL DEFAULT false,
    created_at timestamptz DEFAULT now()
  );

  ALTER TABLE appointment_alerts ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "Users manage their own appointment alerts"
    ON appointment_alerts FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


  --   create table prescription_alerts (
  --   id text primary key,
  --   prescription_id text not null references prescriptions(id) on delete cascade,
  --   user_id uuid not null references auth.users(id) on delete cascade,
  --   scheduled_at timestamptz not null,
  --   acknowledged boolean not null default false,
  --   created_at timestamptz not null default now()
  -- );

  -- alter table prescription_alerts enable row level security;

  -- create policy "Users manage their own prescription alerts"
  --   on prescription_alerts for all
  --   using (auth.uid() = user_id)
  --   with check (auth.uid() = user_id);

  --    create table prescription_alerts (
  --   id text primary key,
  --   prescription_id text not null references prescriptions(id) on delete cascade,
  --   user_id uuid not null references auth.users(id) on delete cascade,
  --   scheduled_at timestamptz not null,
  --   acknowledged boolean not null default false,
  --   created_at timestamptz not null default now()
  -- );

  -- alter table prescription_alerts enable row level security;

  -- create policy "Users manage their own prescription alerts"
  --   on prescription_alerts for all
  --   using (auth.uid() = user_id)
  --   with check (auth.uid() = user_id);


create table prescription_alerts (
    id text primary key,
    prescription_id text not null references prescriptions(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    scheduled_at timestamptz not null,
    acknowledged boolean not null default false,
    created_at timestamptz not null default now()
  );

  alter table prescription_alerts enable row level security;

  create policy "Users manage their own prescription alerts"
    on prescription_alerts for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- Vitals: add category and event_name columns (run once)
ALTER TABLE vitals
  ADD COLUMN IF NOT EXISTS category   text NOT NULL DEFAULT 'daily',
  ADD COLUMN IF NOT EXISTS event_name text NOT NULL DEFAULT '';

-- Doctors
CREATE TABLE IF NOT EXISTS doctors (
  id          text PRIMARY KEY,
  user_id     uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  first_name  text NOT NULL DEFAULT '',
  last_name   text NOT NULL DEFAULT '',
  credential  text NOT NULL DEFAULT '',
  specialty   text NOT NULL DEFAULT '',
  phone       text NOT NULL DEFAULT '',
  address     text NOT NULL DEFAULT '',
  city        text NOT NULL DEFAULT '',
  state       text NOT NULL DEFAULT '',
  zip         text NOT NULL DEFAULT '',
  npi_number  text NOT NULL DEFAULT '',
  notes       text NOT NULL DEFAULT '',
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE doctors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "doctors_all" ON doctors FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

