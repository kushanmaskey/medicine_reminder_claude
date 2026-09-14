-- Migration: add pharmacies table
-- Run on both dev and prod Supabase instances

CREATE TABLE IF NOT EXISTS pharmacies (
  id          text PRIMARY KEY,
  user_id     uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  name        text NOT NULL DEFAULT '',
  npi_number  text NOT NULL DEFAULT '',
  phone       text NOT NULL DEFAULT '',
  fax         text NOT NULL DEFAULT '',
  address     text NOT NULL DEFAULT '',
  city        text NOT NULL DEFAULT '',
  state       text NOT NULL DEFAULT '',
  zip         text NOT NULL DEFAULT '',
  notes       text NOT NULL DEFAULT '',
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE pharmacies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pharmacies_all" ON pharmacies FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
