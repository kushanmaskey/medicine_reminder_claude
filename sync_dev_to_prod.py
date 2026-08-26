#!/usr/bin/env python3
"""
One-time dev → prod Supabase sync for Medical Wallet.

DATA FLOW POLICY:
  - Direction is ALWAYS dev → prod. This script never touches dev as a write target.
  - Prod data is never copied back to dev/staging.
  - The source and target URLs are hard-coded; they cannot be swapped via flags.
  - A same-key guard and a manual confirmation prompt prevent accidental prod writes.

What this does:
  1. Fetches every auth user from dev (via admin API).
  2. Creates each user in prod with the same UUID + confirmed email.
  3. Upserts all app data tables dev → prod (safe to re-run).

Passwords do NOT transfer — Supabase does not expose password hashes.
After the sync, iOS users must tap "Forgot Password" in the app to
set a new password against the prod database.

Requirements:
  pip install requests

Usage:
  export DEV_SERVICE_ROLE_KEY="eyJ..."
  export PROD_SERVICE_ROLE_KEY="eyJ..."

  python3 sync_dev_to_prod.py              # dry-run preview (no writes)
  python3 sync_dev_to_prod.py --run        # actually migrate (prompts for confirmation)
  python3 sync_dev_to_prod.py --run --send-reset-emails  # + trigger reset emails
"""

import os
import sys
import json
import time
import argparse

try:
    import requests
except ImportError:
    print("ERROR: Install requests first:  pip install requests")
    sys.exit(1)

# ── Supabase endpoints ────────────────────────────────────────────────────────
# Direction is hard-coded: dev → prod only. These are never swapped.

DEV_URL  = "https://umunppclpmlmjpwpqosf.supabase.co"
PROD_URL = "https://bqkondmchcbqabjicdfo.supabase.co"

DEV_KEY  = os.environ.get("DEV_SERVICE_ROLE_KEY", "")
PROD_KEY = os.environ.get("PROD_SERVICE_ROLE_KEY", "")

def _assert_not_prod_write_to_dev():
    """Belt-and-suspenders guard: abort immediately if prod key is pointed at the dev URL."""
    if PROD_KEY and DEV_KEY and PROD_KEY == DEV_KEY:
        print("FATAL: DEV_SERVICE_ROLE_KEY and PROD_SERVICE_ROLE_KEY are identical.")
        print("       This script only writes to prod. Aborting.")
        sys.exit(1)

# Tables in insertion order — respects all foreign key dependencies:
#   doctors must precede prescriptions and vitals (doctor_id FK)
#   prescriptions must precede prescription_alerts (prescription_id FK)
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
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def rest_headers(key, prefer=None):
    h = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }
    if prefer:
        h["Prefer"] = prefer
    return h

def admin_headers(key):
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }

def fetch_all_rows(base_url, key, table):
    """Fetch every row from a table, paginating in chunks of 1 000."""
    rows = []
    limit = 1000
    offset = 0
    while True:
        r = requests.get(
            f"{base_url}/rest/v1/{table}",
            headers=rest_headers(key),
            params={"select": "*", "order": "created_at.asc", "limit": limit, "offset": offset},
        )
        r.raise_for_status()
        batch = r.json()
        rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit
    return rows

def upsert_rows(base_url, key, table, rows):
    """Upsert rows; rows that already exist in prod are ignored."""
    if not rows:
        return 0
    r = requests.post(
        f"{base_url}/rest/v1/{table}",
        headers=rest_headers(key, prefer="resolution=ignore-duplicates,return=minimal"),
        json=rows,
    )
    if not r.ok:
        print(f"     ! Upsert error on {table}: {r.status_code} {r.text[:200]}")
        r.raise_for_status()
    return len(rows)

def fetch_dev_users(dry_run):
    """Return all users from the dev auth admin API."""
    if dry_run:
        return []
    users, page = [], 1
    while True:
        r = requests.get(
            f"{DEV_URL}/auth/v1/admin/users",
            headers=admin_headers(DEV_KEY),
            params={"page": page, "per_page": 50},
        )
        r.raise_for_status()
        batch = r.json().get("users", [])
        users.extend(batch)
        if len(batch) < 50:
            break
        page += 1
    return users

def create_prod_user(user):
    """
    Create a user in prod with the same UUID.
    Returns 'created', 'exists', or raises on error.
    """
    payload = {
        "id":             user["id"],
        "email":          user.get("email"),
        "email_confirm":  True,
        "phone":          user.get("phone") or None,
        "user_metadata":  user.get("user_metadata") or {},
        "app_metadata":   user.get("app_metadata") or {},
    }
    payload = {k: v for k, v in payload.items() if v is not None}

    r = requests.post(
        f"{PROD_URL}/auth/v1/admin/users",
        headers=admin_headers(PROD_KEY),
        json=payload,
    )
    if r.status_code in (422, 409):
        return "exists"
    r.raise_for_status()
    return "created"

def send_reset_email(email):
    """Trigger a password-reset email for a user in prod."""
    r = requests.post(
        f"{PROD_URL}/auth/v1/admin/generate_link",
        headers=admin_headers(PROD_KEY),
        json={"type": "recovery", "email": email},
    )
    return r.ok

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Sync dev Supabase → prod (one-time migration)")
    parser.add_argument("--run",               action="store_true", help="Actually perform the migration (default: dry-run preview)")
    parser.add_argument("--send-reset-emails", action="store_true", help="Trigger password-reset emails for every migrated user in prod")
    args = parser.parse_args()

    dry_run = not args.run

    _assert_not_prod_write_to_dev()

    if not dry_run and (not DEV_KEY or not PROD_KEY):
        print("ERROR: Set DEV_SERVICE_ROLE_KEY and PROD_SERVICE_ROLE_KEY before running.")
        sys.exit(1)

    print("=" * 60)
    print("  Medical Wallet — Dev → Prod Supabase Sync")
    print(f"  Source : {DEV_URL}  (dev)")
    print(f"  Target : {PROD_URL}  (prod)")
    print(f"  Mode   : {'DRY RUN (no writes)' if dry_run else 'LIVE — will write to prod'}")
    print("=" * 60)

    if not dry_run:
        print()
        print("  WARNING: This writes data to the PRODUCTION database.")
        print("           Prod data is never written back to dev.")
        answer = input("  Type 'migrate' to confirm: ").strip()
        if answer != "migrate":
            print("Aborted.")
            sys.exit(0)
        print()

    # ── Step 1: Count / migrate auth users ───────────────────────

    print("\n[1/2] Auth users")

    if dry_run:
        # In dry-run we still need keys to count rows — skip auth user count
        # but still show table row counts if keys are present.
        print("      (skipping auth user fetch in dry-run — pass --run to migrate)")
        users = []
    else:
        print("      Fetching users from dev...")
        users = fetch_dev_users(dry_run=False)
        print(f"      Found {len(users)} user(s) in dev\n")

        created_count  = 0
        existing_count = 0
        for u in users:
            email  = u.get("email", u["id"])
            result = create_prod_user(u)
            if result == "created":
                print(f"      + Created : {email}")
                created_count += 1
                time.sleep(0.1)   # be gentle with the admin API rate limit
            else:
                print(f"      ~ Exists  : {email}")
                existing_count += 1

        print(f"\n      Summary: {created_count} created, {existing_count} already existed")

    # ── Step 2: Sync data tables ──────────────────────────────────

    print("\n[2/2] Data tables")

    if dry_run and not DEV_KEY:
        print("      Set DEV_SERVICE_ROLE_KEY to preview row counts, or pass --run to migrate.\n")
    else:
        total_rows = 0
        for table in TABLES:
            rows = fetch_all_rows(DEV_URL, DEV_KEY, table)
            if dry_run:
                print(f"      {table:<25} {len(rows):>5} row(s) — would copy")
            else:
                count = upsert_rows(PROD_URL, PROD_KEY, table, rows)
                print(f"      {table:<25} {count:>5} row(s) synced")
            total_rows += len(rows)

        print(f"\n      Total rows: {total_rows}")

    # ── Step 3: Optional password reset emails ────────────────────

    if args.send_reset_emails and not dry_run and users:
        print("\n[3/3] Sending password-reset emails...")
        ok = fail = 0
        for u in users:
            email = u.get("email")
            if not email:
                continue
            if send_reset_email(email):
                print(f"      Sent reset to: {email}")
                ok += 1
            else:
                print(f"      ! Failed for : {email}")
                fail += 1
            time.sleep(0.2)
        print(f"      Sent: {ok}, Failed: {fail}")

    # ── Done ──────────────────────────────────────────────────────

    print()
    if dry_run:
        print("Dry-run complete. Run with --run to perform the migration.")
    else:
        print("Migration complete.")
        print()
        print("IMPORTANT: Passwords were NOT transferred.")
        print("Notify iOS users to use 'Forgot Password' to regain access.")
        if not args.send_reset_emails:
            print("Tip: re-run with --send-reset-emails to trigger reset emails automatically.")

if __name__ == "__main__":
    main()
