# Privacy Policy — My Medical Wallet

**Effective date: June 1, 2026**
**Last updated: June 1, 2026**

---

## 1. Introduction

My Medical Wallet ("the App", "we", "our") is a personal health management application designed to help individuals track medications, medical appointments, health vitals, physical activities, and healthcare providers. This Privacy Policy explains what personal information we collect, how we use and protect it, and the rights you have over your data.

By using the App, you agree to the practices described in this policy.

---

## 2. Information We Collect

We collect only the information you voluntarily enter into the App.

### Account Information
- Email address (used for login and account recovery)
- Password (stored as a cryptographic hash — we never store your plain-text password)

### Personal Profile
- First name (for personalised greetings)
- Biological sex / gender (used to show relevant health fields, e.g. menstrual and mammogram tracking for female users)
- Profile avatar (stored locally or as an encoded image in your account)

### Health Data
| Category | Data Collected |
|---|---|
| Daily Vitals | Blood pressure (systolic/diastolic), blood sugar, body weight, cholesterol |
| Misc Vitals | Last period date, last mammogram date, last colonoscopy date |
| Events / Procedures | Event name, event date, associated doctor |
| Medications | Medication name, dosage, frequency, refill date, pill count, medication type (prescription or over-the-counter), associated doctor |
| Appointments | Doctor name, appointment date and time, location, notes |
| Activities | Activity type (walk, run, exercise, yoga, meditation), distance, duration, date |
| Healthcare Providers | Doctor name, specialty, phone number, address, NPI number, notes |
| Notes | Free-text notes attached to any health record |

---

## 3. How We Use Your Information

We use your information **solely to provide the App's features**:

- Displaying your health records and history
- Sending local medication and appointment reminders (processed entirely on your device)
- Showing personalised health summaries and relevant health fields
- Looking up doctor information from the public NPI Registry (read-only; no personal data is transmitted to NPI)

We do **not**:
- Sell your data to any third party
- Use your data for advertising or marketing
- Share your data with insurers, employers, or government agencies
- Use your health data to train AI or machine learning models

---

## 4. How We Store and Protect Your Data

All data is stored in **Supabase** (supabase.com), a cloud database platform with the following protections:

- **Encryption in transit:** All data is transmitted over HTTPS/TLS
- **Encryption at rest:** Data is encrypted on Supabase's servers
- **Row Level Security (RLS):** Database-level policies ensure only you can read or write your own data — even we cannot access individual user records without your credentials
- **Authentication:** Powered by Supabase Auth with industry-standard JWT tokens

---

## 5. Sensitive Health Data

This App collects and stores sensitive personal health information, including menstrual cycle data, medication records, and clinical measurements. We treat all health data with the highest level of care:

- Health data is **never shared** with third parties
- Health data is **never used** for any purpose other than displaying it back to you within the App
- You can **delete any record** at any time from within the App

> **Important:** This App is a personal health tracker and is **not** a covered entity under HIPAA, nor is it intended to be used as a medical device or clinical record system. It is a personal organisational tool only.

---

## 6. Health Information Disclaimer

The health reference information, guidelines, and recommendations shown in this App (including blood pressure ranges, blood sugar classifications, and screening schedules) are **for general informational purposes only**. They are **not** a substitute for professional medical advice, diagnosis, or treatment.

Always consult a qualified healthcare provider before making any medical decisions. In an emergency, call 911 or your local emergency number immediately.

Reference links open content from **MedlinePlus** (medlineplus.gov), a service of the U.S. National Library of Medicine. MedlinePlus content is in the public domain.

---

## 7. Third-Party Services

| Service | Purpose | Data Shared |
|---|---|---|
| **Supabase** (supabase.com) | Database and user authentication | Account credentials and all app data you enter |
| **NPI Registry** (npiregistry.cms.hhs.gov) | Public doctor lookup by name or NPI number | Search terms only (no personal data) |
| **MedlinePlus** (medlineplus.gov) | External health information links | None — links open in your browser |

We do not use analytics SDKs, advertising SDKs, or any other third-party tracking services.

---

## 8. Local Notifications

With your permission, the App sends local push notifications for medication reminders and upcoming appointments. These notifications are:

- Scheduled and processed **entirely on your device**
- Never routed through any external server
- Removable at any time through your device's notification settings

---

## 9. Data Retention

Your data remains in the App until you delete it. The App automatically removes:

- Activity records older than 7 days (from the Activities tab)

All other records (vitals, medications, appointments, doctors) are retained indefinitely until you manually delete them or request account deletion.

---

## 10. Your Rights

Depending on your location, you may have the following rights:

| Right | How to Exercise |
|---|---|
| **Access** | View all your data directly within the App at any time |
| **Correction** | Edit any record by tapping it within the App |
| **Deletion** | Delete individual records within the App, or request full account deletion by contacting us |
| **Portability** | Contact us to request an export of your data |
| **Opt-out of notifications** | Disable notifications in your device settings at any time |

**To request account and data deletion**, contact us at the email below. We will permanently delete all your data from Supabase within **30 days** of your request.

---

## 11. California Residents (CCPA)

If you are a California resident, you have the right to:
- Know what personal information we collect and how it is used
- Request deletion of your personal information
- Not be discriminated against for exercising your privacy rights

We do not sell personal information. To exercise your rights, contact us at the email below.

---

## 12. Children's Privacy

This App is not directed to children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided us with personal information, please contact us and we will delete it promptly.

---

## 13. Changes to This Policy

We may update this Privacy Policy from time to time. When we do, we will update the "Last updated" date at the top of this page. Continued use of the App after a policy change constitutes your acceptance of the updated policy. We encourage you to review this policy periodically.

---

## 14. Contact Us

For privacy questions, data requests, or account deletion:

**Email:** kushan.maskey@gmail.com

We aim to respond to all privacy-related requests within **14 business days**.

---

*My Medical Wallet is an independent application and is not affiliated with, endorsed by, or connected to any government agency, healthcare provider, insurance company, or medical institution.*
