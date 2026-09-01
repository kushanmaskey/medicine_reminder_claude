-- ============================================================
-- Migration: Add pulse and readings_data columns to vitals
-- Fixes: pulse not being saved (columns were missing from schema)
-- Run this in: Supabase Dashboard → SQL Editor → Run
-- Safe to run multiple times — uses IF NOT EXISTS
-- ============================================================

ALTER TABLE vitals ADD COLUMN IF NOT EXISTS pulse         integer;
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS readings_data text;
