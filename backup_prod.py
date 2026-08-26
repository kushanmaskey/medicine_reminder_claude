#!/usr/bin/env python3
"""
Daily production backup for Medical Wallet.

Exports from the prod Supabase database:
  - Auth users (id, email, metadata — no password hashes)
  - All app data tables

Output: a dated folder  backups/YYYY-MM-DD/
  auth_users.json
  profiles.json
  doctors.json
  prescriptions.json
  medications.json
  appointments.json
  appointment_alerts.json
  vitals.json
  activities.json
  prescription_alerts.json
  user_consents.json
  manifest.json

This script is read-only against prod. It never writes to any database.

Requirements:
  pip install requests

Usage (local):
  export PROD_SERVICE_ROLE_KEY="eyJ..."
  python3 backup_prod.py

Usage (CI):
  python3 backup_prod.py --output-dir /path/to/output
"""

import os
import sys
import json
import argparse
from datetime import datetime, timezone

try:
    import requests
except ImportError:
    print("ERROR: Install requests first:  pip install requests")
    sys.exit(1)

# ── Config ────────────────────────────────────────────────────────────────────

PROD_URL = "https://bqkondmchcbqabjicdfo.supabase.co"
PROD_KEY = os.environ.get("PROD_SERVICE_ROLE_KEY", "")

TABLES = [
    "profiles",
    "doctors",
    "prescriptions",
    "medications",
    "appointments",
    "appointment_alerts",
    "vitals",
    "activities",
    "prescription_alerts",
    "user_consents",
    "allergies",
    "insurance",
]

# Fields exported per auth user — excludes any internal Supabase fields
AUTH_USER_FIELDS = [
    "id", "email", "phone", "role", "created_at",
    "last_sign_in_at", "user_metadata", "app_metadata",
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def rest_headers(key):
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }

def fetch_all_rows(table):
    rows = []
    limit = 1000
    offset = 0
    while True:
        r = requests.get(
            f"{PROD_URL}/rest/v1/{table}",
            headers=rest_headers(PROD_KEY),
            params={"select": "*", "order": "created_at.asc", "limit": limit, "offset": offset},
        )
        r.raise_for_status()
        batch = r.json()
        rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit
    return rows

def fetch_auth_users():
    users = []
    page = 1
    while True:
        r = requests.get(
            f"{PROD_URL}/auth/v1/admin/users",
            headers=rest_headers(PROD_KEY),
            params={"page": page, "per_page": 50},
        )
        r.raise_for_status()
        batch = r.json().get("users", [])
        # Strip down to the fields we care about
        for u in batch:
            users.append({k: u.get(k) for k in AUTH_USER_FIELDS})
        if len(batch) < 50:
            break
        page += 1
    return users

def write_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2, default=str)

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Export prod Supabase data to JSON backup files")
    parser.add_argument("--output-dir", default="backups", help="Root directory for output (default: ./backups)")
    args = parser.parse_args()

    if not PROD_KEY:
        print("ERROR: Set PROD_SERVICE_ROLE_KEY before running.")
        sys.exit(1)

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out_dir = os.path.join(args.output_dir, today)
    os.makedirs(out_dir, exist_ok=True)

    started_at = datetime.now(timezone.utc).isoformat()
    manifest = {"backup_date": today, "started_at": started_at, "tables": {}}

    print(f"Backing up prod → {out_dir}/")

    # Auth users
    print("  auth_users ...", end=" ", flush=True)
    users = fetch_auth_users()
    write_json(os.path.join(out_dir, "auth_users.json"), users)
    print(f"{len(users)} users")
    manifest["auth_users"] = len(users)

    # Data tables
    for table in TABLES:
        print(f"  {table} ...", end=" ", flush=True)
        rows = fetch_all_rows(table)
        write_json(os.path.join(out_dir, f"{table}.json"), rows)
        print(f"{len(rows)} rows")
        manifest["tables"][table] = len(rows)

    manifest["completed_at"] = datetime.now(timezone.utc).isoformat()
    write_json(os.path.join(out_dir, "manifest.json"), manifest)

    total_rows = sum(manifest["tables"].values())
    print(f"\nDone. {len(users)} auth users, {total_rows} data rows → {out_dir}/")

if __name__ == "__main__":
    main()
