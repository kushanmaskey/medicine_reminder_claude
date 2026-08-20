-- ============================================================
-- Medical Wallet – Production Schema
-- Run this in: Supabase Dashboard (medical_wallet_prod)
--              → SQL Editor → New query → Paste → Run
-- ============================================================

-- ── Tables ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS profiles (
  id            uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  name          text NOT NULL DEFAULT '',
  sex           text NOT NULL DEFAULT 'Male',
  phone         text NOT NULL DEFAULT '',
  avatar_type   text,
  avatar_index  integer,
  avatar_image  text,
  created_at    timestamptz DEFAULT now()
);

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

CREATE TABLE IF NOT EXISTS prescriptions (
  id                  text PRIMARY KEY,
  user_id             uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  name                text NOT NULL,
  refill_date         timestamptz,
  instructions        text NOT NULL DEFAULT '',
  notification_hour   integer,
  notification_minute integer,
  total_pills         integer,
  pills_per_day       integer,
  last_decrement_date date,
  type                text NOT NULL DEFAULT 'prescribed',
  doctor_id           text REFERENCES doctors(id) ON DELETE SET NULL,
  created_at          timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS medications (
  id                  text PRIMARY KEY,
  user_id             uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  doctor_name         text NOT NULL DEFAULT '',
  prescription_name   text NOT NULL,
  instructions        text NOT NULL DEFAULT '',
  notification_hour   integer,
  notification_minute integer,
  created_at          timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS appointments (
  id                    text PRIMARY KEY,
  user_id               uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  title                 text NOT NULL,
  doctor_name           text NOT NULL DEFAULT '',
  location              text NOT NULL DEFAULT '',
  notes                 text NOT NULL DEFAULT '',
  appointment_date_time timestamptz NOT NULL,
  created_at            timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS appointment_alerts (
  id             text PRIMARY KEY,
  appointment_id text NOT NULL,
  user_id        uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  scheduled_at   timestamptz NOT NULL,
  acknowledged   boolean NOT NULL DEFAULT false,
  created_at     timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vitals (
  id               text PRIMARY KEY,
  user_id          uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  recorded_at      timestamptz NOT NULL,
  bp_systolic      integer,
  bp_diastolic     integer,
  weight           double precision,
  weight_unit      text DEFAULT 'kg',
  sugar_level      double precision,
  sugar_unit       text DEFAULT 'mg/dL',
  cholesterol      double precision,
  cholesterol_unit text DEFAULT 'mg/dL',
  colonoscopy_date     text,
  colonoscopy_location text NOT NULL DEFAULT '',
  colonoscopy_notes    text NOT NULL DEFAULT '',
  period_date          text,
  period_notes         text NOT NULL DEFAULT '',
  mammogram_date       text,
  mammogram_location   text NOT NULL DEFAULT '',
  mammogram_notes      text NOT NULL DEFAULT '',
  dental_date          text,
  dental_location      text NOT NULL DEFAULT '',
  dental_notes         text NOT NULL DEFAULT '',
  eye_exam_date        text,
  eye_exam_location    text NOT NULL DEFAULT '',
  eye_exam_notes       text NOT NULL DEFAULT '',
  event_dates          text,
  location             text NOT NULL DEFAULT '',
  risk_level           text NOT NULL DEFAULT 'Low',
  notes                text NOT NULL DEFAULT '',
  category             text NOT NULL DEFAULT 'daily',
  event_name           text NOT NULL DEFAULT '',
  doctor_id            text REFERENCES doctors(id) ON DELETE SET NULL,
  created_at           timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS activities (
  id          text PRIMARY KEY,
  user_id     uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  type        text NOT NULL,
  walk_type   text NOT NULL DEFAULT 'Regular',
  distance    double precision,
  duration    double precision,
  recorded_at timestamptz NOT NULL,
  notes       text NOT NULL DEFAULT '',
  created_at  timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS prescription_alerts (
  id              text PRIMARY KEY,
  prescription_id text NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
  user_id         uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  scheduled_at    timestamptz NOT NULL,
  acknowledged    boolean NOT NULL DEFAULT false,
  created_at      timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_consents (
  id            text PRIMARY KEY,
  user_id       uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  email         text NOT NULL,
  agreed_at     timestamptz NOT NULL,
  terms_version text NOT NULL DEFAULT '1.0',
  agreed        boolean NOT NULL DEFAULT true,
  created_at    timestamptz DEFAULT now()
);

-- ── Row Level Security ─────────────────────────────────────────

ALTER TABLE profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctors            ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE medications        ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE vitals              ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities          ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescription_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_consents       ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);

-- All other tables: users can only access their own rows
CREATE POLICY "doctors_all"             ON doctors             FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "prescriptions_all"       ON prescriptions       FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "medications_all"         ON medications         FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "appointments_all"        ON appointments        FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "appointment_alerts_all"  ON appointment_alerts  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "vitals_all"              ON vitals              FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "activities_all"          ON activities          FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "prescription_alerts_all" ON prescription_alerts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_consents_all"       ON user_consents       FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── Auto-create profile on signup ─────────────────────────────

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO profiles (id, name, sex)
  VALUES (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'sex', 'Male')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();
