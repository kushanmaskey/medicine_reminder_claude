-- ============================================================
-- Migration: Add dedicated timestamp columns for each vital type
-- Fixes: BP and other vital readings losing their recorded time
-- Run this in: Supabase Dashboard → SQL Editor → Run
-- Safe to run multiple times — uses IF NOT EXISTS
-- ============================================================

ALTER TABLE vitals ADD COLUMN IF NOT EXISTS pulse_recorded_at        timestamptz;
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS bp_recorded_at           timestamptz;
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS weight_recorded_at       timestamptz;
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS sugar_recorded_at        timestamptz;
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS cholesterol_recorded_at  timestamptz;
