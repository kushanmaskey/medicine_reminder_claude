# My Medical Wallet — Developer Documentation

**App Name:** My Medical Wallet  
**Package:** com.mymedicalwallet.app  
**Version:** 1.0.1+2013  
**Platform:** Flutter (iOS + Android)  
**Backend:** Supabase (PostgreSQL + Auth)  
**Target Audience:** Adults 50+ managing medications, doctors, vitals, and appointments

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Dependencies](#2-dependencies)
3. [Configuration](#3-configuration)
4. [Data Models](#4-data-models)
5. [Services](#5-services)
6. [Screens](#6-screens)
7. [Tabs](#7-tabs)
8. [Onboarding](#8-onboarding)
9. [Supabase Database Schema](#9-supabase-database-schema)
10. [Key App Flows](#10-key-app-flows)
11. [Platform Permissions](#11-platform-permissions)
12. [Security & Privacy](#12-security--privacy)
13. [Color Scheme](#13-color-scheme)

---

## 1. Project Structure

```
lib/
├── main.dart                        # Entry point, routing, splash logic
├── config/
│   └── supabase_config.dart         # Supabase URL and anon key
├── models/
│   ├── activity.dart
│   ├── allergy.dart
│   ├── appointment.dart
│   ├── appointment_alert.dart
│   ├── doctor.dart
│   ├── insurance.dart
│   ├── medication.dart
│   ├── prescription.dart
│   ├── prescription_alert.dart
│   ├── vital.dart
│   └── vital_reading.dart
├── services/
│   ├── auth_service.dart
│   ├── biometric_service.dart
│   ├── notification_service.dart
│   ├── ringtone_service.dart
│   └── storage_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── biometric_lock_screen.dart
│   ├── profile_screen.dart
│   ├── settings_screen.dart
│   ├── add_prescription_screen.dart
│   ├── add_appointment_screen.dart
│   ├── add_vital_screen.dart
│   ├── add_activity_screen.dart
│   ├── add_doctor_screen.dart
│   ├── add_allergy_screen.dart
│   ├── add_insurance_screen.dart
│   ├── activity_detail_screen.dart
│   ├── privacy_policy_screen.dart
│   └── terms_screen.dart
├── tabs/
│   ├── summary_tab.dart
│   ├── prescriptions_tab.dart
│   ├── appointments_tab.dart
│   ├── vitals_tab.dart
│   ├── activities_tab.dart
│   ├── doctors_tab.dart
│   ├── insurance_tab.dart
│   └── allergies_tab.dart
└── onboarding/
    ├── onboarding_screen.dart
    └── onboarding_content.dart
```

---

## 2. Dependencies

**File:** `pubspec.yaml`

| Package | Version | Purpose |
|---|---|---|
| `flutter_local_notifications` | ^18.0.0 | Schedule local push notifications |
| `flutter_timezone` | ^5.0.2 | Detect device timezone |
| `timezone` | ^0.9.4 | Timezone-aware scheduling |
| `supabase_flutter` | ^2.0.0 | Supabase client (auth + database) |
| `local_auth` | ^3.0.1 | Face ID / Touch ID / fingerprint |
| `image_picker` | ^1.1.2 | Pick avatar photo from gallery/camera |
| `shared_preferences` | ^2.3.3 | Local key-value storage |
| `permission_handler` | ^11.3.1 | Runtime OS permission requests |
| `crypto` | ^3.0.7 | Hashing strings for notification IDs |
| `http` | ^1.2.0 | HTTP client for NPI API lookup |
| `url_launcher` | ^6.3.0 | Open URLs in browser |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

---

## 3. Configuration

### Supabase
**File:** `lib/config/supabase_config.dart`

```
URL:      https://umunppclpmlmjpwpqosf.supabase.co
Anon Key: (JWT token — safe to expose, RLS enforces security)
```

Initialized in `lib/main.dart` with a 10-second timeout on startup.

### App Entry Point
**File:** `lib/main.dart`

- **`MedicalWalletApp`** — Root widget. Sets Material 3 theme with seed color `#FF6B6B`.
- **`_SplashRouter`** — Determines which screen to show on launch.
- **`_resolve()`** — Startup logic:
  1. Check `onboarding_done` in SharedPreferences → show `OnboardingScreen` if false
  2. Check `AuthService.isLoggedIn()` → go to `LoginScreen` if false
  3. Check `BiometricService.isEnabled()` → show `BiometricLockScreen` if true
  4. Otherwise → show `HomeScreen`

---

## 4. Data Models

### `Appointment`
**File:** `lib/models/appointment.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID primary key |
| title | String | Appointment title |
| doctorName | String | Doctor's name |
| location | String | Clinic/hospital address |
| notes | String | Additional notes |
| appointmentDateTime | DateTime | Date and time of appointment |
| alerts | List\<AppointmentAlert\> | Reminder alerts |

**Getters:**
- `activeAlerts` — Returns only unacknowledged alerts

---

### `AppointmentAlert`
**File:** `lib/models/appointment_alert.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| appointmentId | String | Parent appointment ID |
| scheduledAt | DateTime | When alert fires |
| acknowledged | bool | Whether user has seen it |

---

### `Prescription`
**File:** `lib/models/prescription.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| name | String | Medication name |
| type | String | `'prescribed'` or `'otc'` |
| doctorId | String? | Linked doctor ID |
| refillDate | DateTime? | Next refill date |
| instructions | String | Dosage instructions |
| notificationHour | int? | Hour for daily reminder |
| notificationMinute | int? | Minute for daily reminder |
| totalPills | int? | Remaining pill count |
| pillsPerDay | int? | Pills consumed per day |
| lastDecrementDate | DateTime? | Last date pills were decremented |
| alerts | List\<PrescriptionAlert\> | Refill reminder alerts |

**Getters:**
- `isOtc` — True if type is 'otc'
- `hasLowSupply` — True if pills remaining <= 7 days worth
- `notificationTime` — Returns `TimeOfDay` or null

---

### `PrescriptionAlert`
**File:** `lib/models/prescription_alert.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| prescriptionId | String | Parent prescription ID |
| scheduledAt | DateTime | When alert fires |
| acknowledged | bool | Whether user has seen it |

---

### `Medication`
**File:** `lib/models/medication.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| doctorName | String | Prescribing doctor name |
| prescriptionName | String | Medication name |
| instructions | String | Dosage instructions |
| notificationHour | int? | Hour for daily reminder |
| notificationMinute | int? | Minute for daily reminder |

**Getters:**
- `notificationTime` — Returns `TimeOfDay` or null

---

### `Doctor`
**File:** `lib/models/doctor.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| firstName | String | First name |
| lastName | String | Last name |
| credential | String | e.g., MD, DO, NP |
| specialty | String | Medical specialty |
| phone | String | Contact number |
| address | String | Street address |
| city | String | City |
| state | String | US state abbreviation |
| zip | String | ZIP code |
| npiNumber | String | National Provider Identifier |
| notes | String | Additional notes |

**Getters:**
- `fullName` — Name with credential (e.g., "John Smith, MD")
- `displayName` — Name only
- `fullAddress` — Formatted full address string

---

### `Vital`
**File:** `lib/models/vital.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| category | String | `'daily'`, `'monthly'`, or `'open'` |
| recordedAt | DateTime | Date of entry |
| bpReadings | List\<BpReading\> | Blood pressure readings |
| pulseReadings | List\<VitalReading\> | Pulse/heart rate readings (bpm) |
| sugarReadings | List\<VitalReading\> | Blood sugar readings |
| cholesterolReadings | List\<VitalReading\> | Cholesterol readings |
| weightReadings | List\<VitalReading\> | Weight readings |
| weightUnit | String | `'lbs'` or `'kg'` |
| sugarUnit | String | `'mg/dL'` or `'mmol/L'` |
| cholesterolUnit | String | `'mg/dL'` or `'mmol/L'` |
| colonoscopyDate | DateTime? | Colonoscopy date |
| periodDate | DateTime? | Menstrual period date (female) |
| mammogramDate | DateTime? | Mammogram date (female) |
| dentalDate | DateTime? | Dental checkup date |
| eyeExamDate | DateTime? | Eye exam date |
| notes | String? | General notes |
| doctorId | String? | Linked doctor |
| riskLevel | String? | Color-coded risk level |

**Getters:**
- `hasPulse`, `hasBp`, `hasSugar`, `hasCholesterol`, `hasWeight`
- `pulseDisplay` — e.g., "72 bpm" or "—"
- `bpDisplay` — e.g., "120/80" or "—"
- `weightDisplay`, `sugarDisplay`, `cholesterolDisplay`

**Schema migration:** Reads from `readings_data` JSON column first, falls back to legacy individual columns.

---

### `BpReading`
**File:** `lib/models/vital.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| systolic | double | Top number (mmHg) |
| diastolic | double | Bottom number (mmHg) |
| time | DateTime | Time of reading |
| notes | String? | Notes |

---

### `VitalReading`
**File:** `lib/models/vital_reading.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| value | double | Numeric reading value |
| time | DateTime | Time of reading |
| notes | String? | Notes |

---

### `Activity`
**File:** `lib/models/activity.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| type | String | `'Walk'`, `'Run'`, `'Exercise'`, `'Yoga'`, `'Meditation'` |
| walkType | String? | `'Brisk'` or `'Regular'` (Walk only) |
| distance | double? | Distance in miles (Walk/Run) |
| duration | int? | Duration in minutes |
| recordedAt | DateTime | Date/time of activity |
| notes | String? | Notes |

**Getters:**
- `isDistanceBased` — True for Walk and Run
- `displayValue` — Formatted value with units

---

### `Allergy`
**File:** `lib/models/allergy.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| name | String | Allergy name |
| reason | String? | `'Medicinal'`, `'Environmental'`, `'Nutritional'` |
| notes | String? | Additional notes |

---

### `Insurance`
**File:** `lib/models/insurance.dart`

| Field | Type | Description |
|---|---|---|
| id | String | UUID |
| type | String | `'Health'`, `'Dental'`, `'Vision'` |
| providerName | String | Insurance company |
| planName | String | Plan name |
| memberId | String | Member ID |
| groupNumber | String | Group number |
| effectiveDate | DateTime? | Coverage start date |
| expirationDate | DateTime? | Coverage end date |
| phone | String? | Provider phone |
| website | String? | Provider website |
| copay | String? | Copay amount |
| deductible | String? | Deductible amount |
| notes | String? | Additional notes |
| createdAt | DateTime | Record creation date |

**Getters:**
- `isExpired` — True if expiration date is in the past
- `isExpiringSoon` — True if expires within 30 days

---

## 5. Services

### `AuthService`
**File:** `lib/services/auth_service.dart`

Handles authentication and user profile management via Supabase Auth.

**Supabase Table:** `profiles`

| Method | Returns | Description |
|---|---|---|
| `register(email, password, name, sex, phone)` | `String?` | Creates auth user, signs in, upserts profile row |
| `login(email, password)` | `bool` | Authenticates via Supabase Auth |
| `logout()` | `void` | Signs out current user |
| `isLoggedIn()` | `bool` | Checks if a valid session exists |
| `currentUserId` | `String?` | Returns the current auth user's UUID |
| `getName()` | `String?` | Fetches name from `profiles` table |
| `getPhone()` | `String?` | Fetches phone from `profiles` table |
| `getSex()` | `String?` | Fetches sex from `profiles` table |
| `updateName(name)` | `void` | Updates name in `profiles` |
| `updateSex(sex)` | `void` | Updates sex in `profiles` |
| `setDefaultAvatar(index)` | `void` | Stores avatar type='default' and index |
| `setCustomAvatar(base64Image)` | `void` | Stores avatar type='custom' and base64 image |
| `getAvatarData()` | `Map` | Returns `{type, index, image}` |

---

### `BiometricService`
**File:** `lib/services/biometric_service.dart`

Handles Face ID / Touch ID / fingerprint authentication via `local_auth`.

| Method | Returns | Description |
|---|---|---|
| `isAvailable()` | `bool` | Checks if biometric hardware exists on device |
| `isEnabled()` | `bool` | Reads enabled flag from SharedPreferences |
| `setEnabled(bool)` | `void` | Persists biometric preference to SharedPreferences |
| `authenticate(reason)` | `bool` | Prompts biometric and returns success/failure |
| `authenticateWithError(reason)` | `(bool, String?)` | Returns success status and optional error message |

**Error Types Handled:** `notAvailable`, `notEnrolled`, `lockedOut`, `permanentlyLockedOut`

---

### `NotificationService`
**File:** `lib/services/notification_service.dart`

Schedules local push notifications using `flutter_local_notifications`.

| Method | Returns | Description |
|---|---|---|
| `initialize()` | `void` | Sets up timezone, Android/iOS notification channels |
| `requestPermission()` | `bool` | Requests OS notification permission (Android 13+, iOS) |
| `scheduleDailyNotification(id, title, body, time)` | `void` | Schedules a recurring daily notification |
| `scheduleOnceNotification(id, title, body, dateTime)` | `void` | Schedules a one-time notification |
| `cancelNotification(id)` | `void` | Cancels a scheduled notification by ID |
| `idFromString(id)` | `int` | Hashes a string UUID to a valid integer notification ID |

**Android Notification Channels:**
- `med_reminder_v2` or `med_v2_{soundHash}` — Medication reminders
- `appointment_v2` — Appointment reminders

**Notes:**
- Uses `TZDateTime` for timezone-aware scheduling
- Falls back to inexact scheduling if exact alarm permission is not granted

---

### `StorageService`
**File:** `lib/services/storage_service.dart`

All CRUD operations for health data via Supabase PostgREST.

#### Prescriptions

| Method | Returns | Description |
|---|---|---|
| `getPrescriptions()` | `List<Prescription>` | Fetches all prescriptions with their alerts |
| `savePrescription(p)` | `void` | Inserts a new prescription |
| `updatePrescription(p)` | `void` | Updates an existing prescription |
| `deletePrescription(id)` | `void` | Deletes prescription and cancels its notifications |
| `decrementPillsIfNeeded()` | `void` | Auto-reduces pill count daily based on pills_per_day |
| `savePrescriptionAlert(alert)` | `void` | Inserts a prescription refill alert |
| `acknowledgePrescriptionAlert(id)` | `void` | Marks alert as acknowledged |
| `deletePrescriptionAlert(id)` | `void` | Deletes a prescription alert |

#### Medications (Legacy)

| Method | Returns | Description |
|---|---|---|
| `getMedications()` | `List<Medication>` | Fetches all medications |
| `saveMedication(m)` | `void` | Inserts a medication |
| `updateMedication(m)` | `void` | Updates a medication |
| `deleteMedication(id)` | `void` | Deletes a medication |

#### Appointments

| Method | Returns | Description |
|---|---|---|
| `getAppointments()` | `List<Appointment>` | Fetches all appointments with alerts |
| `saveAppointment(a)` | `void` | Inserts a new appointment |
| `updateAppointment(a)` | `void` | Updates an existing appointment |
| `deleteAppointment(id)` | `void` | Deletes appointment and cancels notifications |
| `saveAppointmentAlert(alert)` | `void` | Inserts an appointment alert |
| `acknowledgeAppointmentAlert(id)` | `void` | Marks alert as acknowledged |
| `deleteAppointmentAlert(id)` | `void` | Deletes an appointment alert |

#### Vitals

| Method | Returns | Description |
|---|---|---|
| `getVitals()` | `List<Vital>` | Fetches all vital records |
| `saveVital(v)` | `void` | Inserts a vital record (with schema fallback) |
| `updateVital(v)` | `void` | Updates a vital record |
| `deleteVital(id)` | `void` | Deletes a vital record |

> **Schema fallback:** If Supabase returns error `PGRST204` (unknown column), storage service retries:
> 1. First retry: removes `readings_data` from the insert
> 2. Second retry: also removes `pulse` column
> This ensures backwards compatibility with older database schemas.

#### Activities

| Method | Returns | Description |
|---|---|---|
| `getActivities()` | `List<Activity>` | Fetches all activities |
| `saveActivity(a)` | `void` | Inserts an activity |
| `updateActivity(a)` | `void` | Updates an activity |
| `deleteActivity(id)` | `void` | Deletes an activity |

#### Doctors

| Method | Returns | Description |
|---|---|---|
| `getDoctors()` | `List<Doctor>` | Fetches all doctors |
| `saveDoctor(d)` | `void` | Inserts a doctor |
| `updateDoctor(d)` | `void` | Updates a doctor |
| `deleteDoctor(id)` | `void` | Deletes a doctor |

#### Allergies

| Method | Returns | Description |
|---|---|---|
| `getAllergies()` | `List<Allergy>` | Fetches allergies (Supabase with SharedPreferences fallback) |
| `saveAllergy(a)` | `void` | Inserts an allergy |
| `updateAllergy(a)` | `void` | Updates an allergy |
| `deleteAllergy(id)` | `void` | Deletes an allergy |

> **Caching:** Allergies are cached in SharedPreferences as fallback. On first load, legacy local-only allergies are migrated to Supabase via `_migrateLocalAllergies()`.

#### Insurance

| Method | Returns | Description |
|---|---|---|
| `getInsurance()` | `List<Insurance>` | Fetches insurance (Supabase with SharedPreferences cache) |
| `saveInsurance(i)` | `void` | Inserts insurance record |
| `updateInsurance(i)` | `void` | Updates insurance record |
| `deleteInsurance(id)` | `void` | Deletes insurance record |

> **Caching:** Insurance records are cached locally in SharedPreferences for performance.

#### User Consents

| Method | Returns | Description |
|---|---|---|
| `saveUserConsent(email)` | `void` | Records that user agreed to terms |

---

### `RingtoneService`
**File:** `lib/services/ringtone_service.dart`

Manages custom notification sound selection.

**MethodChannel:** `com.medreminder/ringtone` (calls native Android/iOS code)

| Method | Returns | Description |
|---|---|---|
| `pickRingtone()` | `Map<String, String?>` | Opens OS ringtone picker, returns `{uri, name}` |
| `getSoundUri()` | `String?` | Retrieves stored ringtone URI from SharedPreferences |
| `getSoundName()` | `String?` | Retrieves stored ringtone display name |
| `saveSound(uri, name)` | `void` | Persists selected ringtone to SharedPreferences |
| `clearSound()` | `void` | Resets to system default ringtone |

---

## 6. Screens

### `HomeScreen`
**File:** `lib/screens/home_screen.dart`

Main tabbed interface after login.

- 8 tabs: Summary, Doctors, Insurance, Prescriptions, Appointments, Vitals, Activities, Allergies
- Displays user avatar (default icon or custom image) in the app bar
- Session timeout: auto-logs out after **1 hour** of inactivity
- FAB for context-sensitive quick-add actions
- Uses `GlobalKey` on each tab to call `reload()` across tabs when data changes

---

### `LoginScreen`
**File:** `lib/screens/login_screen.dart`

Email and password authentication.

- Calls `AuthService.login()` on submit
- Saves `session_login_time` to SharedPreferences on success
- Shows "Invalid email or password" on failure
- Navigates to `HomeScreen` on success

---

### `RegisterScreen`
**File:** `lib/screens/register_screen.dart`

New account creation.

- Fields: name, email, phone, password, confirm password, sex (Male/Female), terms agreement
- Password minimum 8 characters with real-time strength indicator
- All fields required; terms checkbox mandatory
- Calls `AuthService.register()` on submit
- `_sanitizeAuthError()` converts Supabase errors to user-friendly messages
- Links to `TermsScreen` and `PrivacyPolicyScreen`

---

### `BiometricLockScreen`
**File:** `lib/screens/biometric_lock_screen.dart`

Biometric gate before accessing the app.

- Auto-triggers biometric prompt on init
- `replaceWithHome: true` → navigates to `HomeScreen` on success
- `replaceWithHome: false` → pops with `true` on success
- "Use Password" button signs out and goes to `LoginScreen`

---

### `ProfileScreen`
**File:** `lib/screens/profile_screen.dart`

User profile management.

- Fields: Name, sex, phone (read-only), avatar
- 12 default avatar options (Material icons with colored backgrounds)
- Custom avatar via `image_picker` (stored as base64 in Supabase `profiles` table)
- Calls `AuthService.updateName()`, `AuthService.updateSex()`, `AuthService.setDefaultAvatar()`, `AuthService.setCustomAvatar()`

---

### `SettingsScreen`
**File:** `lib/screens/settings_screen.dart`

App settings and preferences.

- Toggle biometric login (requires current biometric verification to enable)
- Pick custom notification ringtone via `RingtoneService`
- Reschedules all notifications when sound changes
- Links to Privacy Policy and Terms of Use
- Manages runtime permissions

---

### `AddPrescriptionScreen`
**File:** `lib/screens/add_prescription_screen.dart`

Create or edit a prescription.

- Fields: name, instructions, type (Prescribed/OTC), doctor (picker modal), notification time, total pills, pills per day, refill alerts
- Doctor picker loads from `StorageService.getDoctors()` 
- Multiple alert times supported
- On save: calls `StorageService.savePrescription()` / `updatePrescription()`, schedules notifications

---

### `AddAppointmentScreen`
**File:** `lib/screens/add_appointment_screen.dart`

Create or edit an appointment.

- Fields: title, doctor name (with picker), location, date/time, notes, multiple reminder alerts
- On save: calls `StorageService.saveAppointment()`, saves alerts separately

---

### `AddVitalScreen`
**File:** `lib/screens/add_vital_screen.dart`

Log vital signs or miscellaneous health events.

**Daily Category:**
- BP readings (systolic/diastolic pairs)
- Pulse readings (bpm)
- Weight with unit (lbs/kg)
- Blood sugar with unit (mg/dL / mmol/L)
- Cholesterol with unit (mg/dL / mmol/L)
- Multiple readings per type supported

**Misc (Open) Category:**
- Colonoscopy, mammogram (female), dental, eye exam, period (female) dates with notes and locations

Gender-specific fields shown based on sex from `AuthService.getSex()`.

On save: stores readings in `readings_data` JSON column + legacy individual columns via `StorageService.saveVital()`.

---

### `AddActivityScreen`
**File:** `lib/screens/add_activity_screen.dart`

Log a physical activity.

- Types: Walk, Run, Exercise, Yoga, Meditation
- Walk only: Walk type (Regular/Brisk)
- Walk/Run: Distance in miles
- Exercise/Yoga/Meditation: Duration in minutes
- Fields: date/time, notes

---

### `AddDoctorScreen`
**File:** `lib/screens/add_doctor_screen.dart`

Create or edit a doctor contact.

- Fields: first/last name, credential, specialty, phone, address, city, state, ZIP, NPI number, notes
- **NPI Lookup:** Calls external NPI Registry API (`https://npiregistry.cms.hhs.gov/api/`) to auto-fill doctor information
- Full US states dropdown

---

### `AddAllergyScreen`
**File:** `lib/screens/add_allergy_screen.dart`

Log an allergy.

- Fields: allergy name, reason (Medicinal/Environmental/Nutritional), notes
- Delete with confirmation dialog

---

### `AddInsuranceScreen`
**File:** `lib/screens/add_insurance_screen.dart`

Add insurance coverage details.

- Type: Health, Dental, Vision
- Provider: Pre-populated list (BCBS, UnitedHealthcare, Aetna, Cigna, Humana, etc.)
- Fields: plan name, member ID, group number, effective/expiration dates, phone, website, copay, deductible, notes
- Auto-fills provider phone/website when a known provider is selected

---

### `ActivityDetailScreen`
**File:** `lib/screens/activity_detail_screen.dart`

View all activities of a type on a specific day.

- Lists activities grouped by type and date
- Edit and delete actions per entry
- Add new entry button

---

### `PrivacyPolicyScreen`
**File:** `lib/screens/privacy_policy_screen.dart`

Scrollable privacy policy document covering data collection, encryption, RLS security, HIPAA scope, and no third-party sharing.

---

### `TermsScreen`
**File:** `lib/screens/terms_screen.dart`

**Version:** 1.1 — Effective July 19, 2026

Scrollable Terms & Conditions document with 16 sections:

| # | Section | Key Content |
|---|---|---|
| 1 | Acceptance of Terms | Consent recorded with email, timestamp |
| 2 | About the App | Personal organiser only — NOT a medical device |
| 3 | Personal Information We Collect | Email, name, sex, phone, health data, insurance data, allergies |
| 4 | Non-HIPAA Personal Health Data | App is NOT a HIPAA-covered entity; user data not transmitted to providers |
| 5 | **Data Security & Breach Disclaimer** | No guarantee of absolute security; NOT liable for hacking, breaches, or unauthorized access beyond reasonable control |
| 6 | No Medical Advice | App provides no diagnosis, treatment, or medical recommendations |
| 7 | No Sale of User Data | Data never sold, shared with advertisers, or used for AI training |
| 8 | User Responsibilities | Password security, no account sharing, lawful use only |
| 9 | Account Termination | 30-day data deletion on request |
| 10 | Disclaimer of Warranties | App provided "as is" — no guarantee of uptime, accuracy, or data security |
| 11 | **Limitation of Liability** | Developer NOT liable for breaches, hacking, data loss, third-party outages; liability capped at $0 for free app |
| 12 | **Indemnification** | User indemnifies developer against claims arising from misuse, violations, or credential failure |
| 13 | **Governing Law & Dispute Resolution** | Florida law; binding arbitration (AAA); class action waiver |
| 14 | Changes to Terms | Continued use = acceptance of updated Terms |
| 15 | Contact | medicalwallet473@gmail.com |

> **Key legal protections added (v1.1):**
> - Section 5 explicitly disclaims liability for data breaches, hacking, and cyberattacks
> - Section 11 caps liability at $0 for free app usage
> - Section 12 indemnification clause protects developer from user-initiated claims
> - Section 13 requires binding arbitration and waives class action rights

---

## 7. Tabs

### `SummaryTab`
**File:** `lib/tabs/summary_tab.dart`

Dashboard showing the latest entry from each section.

- Displays: prescriptions, upcoming appointments, recent vitals, activities, allergies, doctors, insurance
- Vitals card shows BP, pulse, weight, sugar, cholesterol as chips
- Tap any section card to navigate to its full tab
- Triggers parent `HomeScreen` refresh callbacks when data changes

---

### `PrescriptionsTab`
**File:** `lib/tabs/prescriptions_tab.dart`

- Two sub-tabs: Prescribed | Over the Counter
- Low supply warning badge when pills <= 7 days
- Pill count auto-decrements daily via `StorageService.decrementPillsIfNeeded()`
- Shows prescribing doctor name by linking `doctorId`

---

### `AppointmentsTab`
**File:** `lib/tabs/appointments_tab.dart`

- Sorted by appointment date/time (ascending)
- Past appointments are automatically deleted on tab load
- Displays doctor name, location, date/time, and alert count

---

### `VitalsTab`
**File:** `lib/tabs/vitals_tab.dart`

- Two sub-tabs: Daily | Misc
- Daily view shows mini vitals: BP, pulse, weight, sugar, cholesterol per day
- Same-day history chips for comparing multiple readings
- Doctor name displayed when linked
- Gender-specific misc fields (mammogram and period for female users)

---

### `ActivitiesTab`
**File:** `lib/tabs/activities_tab.dart`

- Activities older than 7 days are automatically deleted on tab load
- Grouped by date then by activity type
- Each type has a unique icon and color
- Tap a group to open `ActivityDetailScreen`

---

### `DoctorsTab`
**File:** `lib/tabs/doctors_tab.dart`

- Sorted alphabetically by last name
- Shows credential, specialty, and contact info
- Used as a picker source in Prescriptions and Vitals

---

### `InsuranceTab`
**File:** `lib/tabs/insurance_tab.dart`

- Three sub-tabs: Health | Dental | Vision
- Expired insurance shows a red warning badge
- Expiring within 30 days shows an amber warning badge
- Backed by SharedPreferences cache with Supabase sync

---

### `AllergiesTab`
**File:** `lib/tabs/allergies_tab.dart`

- Backed by SharedPreferences cache with Supabase fallback
- One-time migration from old local-only storage to Supabase on first load
- Displays allergy name, reason, and notes

---

## 8. Onboarding

### `OnboardingScreen`
**File:** `lib/onboarding/onboarding_screen.dart`

First-time user welcome flow.

- PageView with 10 slides
- Skip button (hidden on last page)
- Next / Get Started button
- Dot page indicators
- On completion: sets `onboarding_done = true` in SharedPreferences

---

### `OnboardingContent`
**File:** `lib/onboarding/onboarding_content.dart`

Static list of `OnboardingPage` objects (`kOnboardingPages`).

| # | Emoji | Title |
|---|---|---|
| 1 | 💙 | Your Health, Always at Hand |
| 2 | 🗂️ | Everything You Need, All in One App |
| 3 | 👋 | Welcome to My Medical Wallet |
| 4 | 📋 | Your Summary |
| 5 | 🩺 | Doctors |
| 6 | 💊 | Prescriptions |
| 7 | 📅 | Appointments |
| 8 | ❤️ | Vitals |
| 9 | 🏃 | Activities |
| 10 | 🔒 | A Few More Things |

---

## 9. Supabase Database Schema

### `profiles`
Stores user profile data.

| Column | Type | Description |
|---|---|---|
| id | UUID | Auth user ID (primary key) |
| name | TEXT | Full name |
| sex | TEXT | 'Male' or 'Female' |
| phone | TEXT | Phone number |
| avatar_type | TEXT | 'default' or 'custom' |
| avatar_index | INT | Index of default avatar (0–11) |
| avatar_image | TEXT | Base64 encoded custom avatar image |

---

### `prescriptions`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | Auth user ID (RLS) |
| name | TEXT | Medication name |
| type | TEXT | 'prescribed' or 'otc' |
| doctor_id | UUID | Linked doctor (nullable) |
| refill_date | TIMESTAMPTZ | Next refill date |
| instructions | TEXT | Dosage instructions |
| notification_hour | INT | Daily reminder hour |
| notification_minute | INT | Daily reminder minute |
| total_pills | INT | Remaining pill count |
| pills_per_day | INT | Daily consumption |
| last_decrement_date | DATE | Last date pills were auto-decremented |
| created_at | TIMESTAMPTZ | Record creation date |

---

### `prescription_alerts`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| prescription_id | UUID | Parent prescription |
| user_id | UUID | Auth user ID (RLS) |
| scheduled_at | TIMESTAMPTZ | Alert fire time |
| acknowledged | BOOL | Whether user dismissed it |

---

### `appointments`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | Auth user ID (RLS) |
| title | TEXT | Appointment title |
| doctor_name | TEXT | Doctor's name |
| location | TEXT | Clinic/hospital |
| notes | TEXT | Additional notes |
| appointment_date_time | TIMESTAMPTZ | Appointment date and time |
| created_at | TIMESTAMPTZ | Record creation date |

---

### `appointment_alerts`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| appointment_id | UUID | Parent appointment |
| user_id | UUID | Auth user ID (RLS) |
| scheduled_at | TIMESTAMPTZ | Alert fire time |
| acknowledged | BOOL | Whether user dismissed it |

---

### `vitals`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | Auth user ID (RLS) |
| recorded_at | DATE | Date of entry |
| category | TEXT | 'daily', 'monthly', or 'open' |
| event_name | TEXT | Name for misc events |
| readings_data | TEXT | JSON blob of all readings (primary storage) |
| bp_systolic | INT | Legacy single BP systolic value |
| bp_diastolic | INT | Legacy single BP diastolic value |
| pulse | INT | Latest pulse reading (bpm) |
| weight | FLOAT | Legacy single weight value |
| weight_unit | TEXT | 'lbs' or 'kg' |
| sugar_level | FLOAT | Legacy single sugar value |
| sugar_unit | TEXT | 'mg/dL' or 'mmol/L' |
| cholesterol | FLOAT | Legacy single cholesterol value |
| cholesterol_unit | TEXT | 'mg/dL' or 'mmol/L' |
| colonoscopy_date | DATE | Colonoscopy date |
| period_date | DATE | Menstrual period date |
| mammogram_date | DATE | Mammogram date |
| dental_date | DATE | Dental checkup date |
| eye_exam_date | DATE | Eye exam date |
| risk_level | TEXT | Color-coded risk indicator |
| notes | TEXT | General notes |
| doctor_id | UUID | Linked doctor |
| created_at | TIMESTAMPTZ | Record creation date |

> **Note:** `readings_data` is a JSON string storing arrays of readings per type. It takes precedence over legacy individual columns on read.

---

### `activities`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | Auth user ID (RLS) |
| type | TEXT | Activity type |
| walk_type | TEXT | 'Brisk' or 'Regular' (walk only) |
| distance | FLOAT | Miles (walk/run only) |
| duration | INT | Minutes |
| recorded_at | TIMESTAMPTZ | Activity date/time |
| notes | TEXT | Notes |
| created_at | TIMESTAMPTZ | Record creation date |

---

### `doctors`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | Auth user ID (RLS) |
| first_name | TEXT | First name |
| last_name | TEXT | Last name |
| credential | TEXT | e.g., MD, DO, NP |
| specialty | TEXT | Medical specialty |
| phone | TEXT | Contact number |
| address | TEXT | Street address |
| city | TEXT | City |
| state | TEXT | State abbreviation |
| zip | TEXT | ZIP code |
| npi_number | TEXT | NPI Registry number |
| notes | TEXT | Notes |
| created_at | TIMESTAMPTZ | Record creation date |

---

### `allergies`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | Auth user ID (RLS) |
| name | TEXT | Allergy name |
| reason | TEXT | 'Medicinal', 'Environmental', 'Nutritional' |
| notes | TEXT | Notes |
| created_at | TIMESTAMPTZ | Record creation date |

---

### `insurance`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | Auth user ID (RLS) |
| type | TEXT | 'Health', 'Dental', 'Vision' |
| provider_name | TEXT | Insurance company |
| plan_name | TEXT | Plan name |
| member_id | TEXT | Member ID |
| group_number | TEXT | Group number |
| effective_date | DATE | Coverage start date |
| expiration_date | DATE | Coverage end date |
| phone | TEXT | Provider phone |
| website | TEXT | Provider website |
| copay | TEXT | Copay amount |
| deductible | TEXT | Deductible amount |
| notes | TEXT | Additional notes |
| created_at | TIMESTAMPTZ | Record creation date |

---

### `user_consents`

| Column | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | Auth user ID (RLS) |
| email | TEXT | User's email at consent time |
| agreed_at | TIMESTAMPTZ | Timestamp of agreement |
| terms_version | TEXT | Version of terms agreed to |
| agreed | BOOL | Whether user agreed |

---

## 10. Key App Flows

### Authentication Flow

```
App Launch
  └─ onboarding_done? 
       No  → OnboardingScreen → LoginScreen
       Yes → isLoggedIn?
               No  → LoginScreen
               Yes → biometricEnabled?
                       Yes → BiometricLockScreen → HomeScreen
                       No  → HomeScreen
```

---

### Notification Scheduling Flow

```
User sets notification time in prescription/appointment
  └─ NotificationService.scheduleDailyNotification() or scheduleOnceNotification()
       └─ TZDateTime created from device timezone
       └─ Exact alarm if SCHEDULE_EXACT_ALARM permission granted
       └─ Inexact alarm as fallback
       └─ Custom ringtone URI applied if set via RingtoneService
```

---

### Prescription Pill Tracking Flow

```
App launch / tab load
  └─ StorageService.decrementPillsIfNeeded()
       └─ For each prescription with pills tracking:
            └─ If today > lastDecrementDate
                 └─ totalPills -= pillsPerDay
                 └─ lastDecrementDate = today
                 └─ Update in Supabase
       └─ If totalPills <= (pillsPerDay * 7) → show low supply warning
```

---

### Vital Save with Schema Fallback

```
StorageService.saveVital(v)
  └─ Build row including readings_data JSON + pulse column
  └─ Try insert
       └─ PGRST204 (unknown column)?
            └─ Remove readings_data, retry
                 └─ PGRST204 again?
                      └─ Remove pulse, retry
                      └─ Success (legacy schema)
                 └─ Success (no readings_data column)
       └─ Success (full schema)
```

---

### Vital Reading Time Accuracy

Each reading (BP, Pulse, Sugar, Cholesterol, Weight) is saved as a separate `Vital` row. The `Vital.recordedAt` is used for day-grouping and as a fallback time when `readings_data` is unavailable.

**Fix in `_makeSingleReadingVital` (`lib/screens/add_vital_screen.dart`):**

- **New mode**: `recordedAt` = reading's full timestamp → correct time even in fallback
- **Edit mode**: `recordedAt` = existing record's **date** + reading's actual **time** → stays grouped under original day AND shows correct entry time

```dart
final recordedAt = _isEditing
    ? DateTime(_recordedAt.year, _recordedAt.month, _recordedAt.day,
               readingTime.hour, readingTime.minute, readingTime.second)
    : readingTime;
```

Applies to all 5 types: BP, Pulse, Sugar, Cholesterol, Weight.

---

### NPI Doctor Lookup

```
AddDoctorScreen → user enters NPI number or searches by name
  └─ HTTP GET https://npiregistry.cms.hhs.gov/api/?
       └─ Parses response JSON
       └─ Auto-fills: first name, last name, credential, specialty, address, city, state, ZIP
```

---

### Session Timeout Flow

```
HomeScreen init
  └─ Read session_login_time from SharedPreferences
  └─ If now - session_login_time > 1 hour
       └─ AuthService.logout()
       └─ Navigate to LoginScreen
  └─ Else: start 1-hour timer → same logout flow on expiry
```

---

## 11. Platform Permissions

### Android (`android/app/src/main/AndroidManifest.xml`)

| Permission | Purpose |
|---|---|
| `INTERNET` | Supabase API calls |
| `USE_BIOMETRIC` | Fingerprint authentication |
| `USE_FINGERPRINT` | Legacy fingerprint support |
| `POST_NOTIFICATIONS` | Show notifications (Android 13+) |
| `RECEIVE_BOOT_COMPLETED` | Reschedule notifications after device reboot |
| `VIBRATE` | Notification vibration |
| `SCHEDULE_EXACT_ALARM` | Exact notification timing |
| `WAKE_LOCK` | Keep device awake during notifications |

### iOS (`ios/Runner/Info.plist`)

| Key | Value |
|---|---|
| `NSFaceIDUsageDescription` | "My Medical Wallet uses Face ID to keep your health data secure." |
| `ITSAppUsesNonExemptEncryption` | `false` (standard HTTPS only, no custom encryption) |
| Supported orientations | Portrait, Landscape Left, Landscape Right |
| iPad orientations | All 4 orientations |

---

## 12. Security & Privacy

| Aspect | Implementation |
|---|---|
| Transport Security | HTTPS for all Supabase communication |
| Database Access | Row Level Security (RLS) — users see only their own rows via `user_id` filter |
| Biometric Auth | Platform-provided via `local_auth` — biometric data never leaves the device |
| Session Timeout | 1-hour auto-logout via SharedPreferences timestamp |
| Avatar Storage | Custom avatars stored as base64 in Supabase `profiles` table |
| Data Scope | Non-HIPAA basic health information (not EMR/EHR medical records) |
| Third-Party Sharing | None — data is never sold or shared with advertisers |
| App Store | Standard Apple EULA, Privacy Policy linked in paywall and App Store listing |
| Liability Disclaimer | Developer not liable for breaches, hacking, or unauthorized access (Terms §5, §11) |
| Indemnification | Users indemnify developer against claims from misuse or credential failure (Terms §12) |
| Governing Law | Florida state law; binding arbitration; class action waiver (Terms §13) |

---

## 13. Color Scheme

| Color | Hex | Usage |
|---|---|---|
| Primary | `#FF6B6B` | App bar, buttons, primary actions (coral) |
| Secondary | `#FF8C42` | Gradient end, accents (orange) |
| Blue | `#3B82F6` | Appointments, info |
| Purple | `#8B5CF6` | Activities |
| Green | `#22C55E` | Success, healthy indicators |
| Orange | `#F97316` | Warnings, alerts |
| Pink | `#EC4899` | Pulse vital |
| Red | `#EF4444` | Errors, expired |
| Gradient | `#FF6B6B → #FF8C42` | Top-left to bottom-right on cards |

---

## 14. App Icon

**Source script:** `generate_icon.py` (requires Pillow)  
**Master icon:** `assets/icons/app_icon.png` (1024×1024)  
**Adaptive foreground:** `assets/icons/app_icon_foreground.png` (padded, for Android circle mask)

Design: coral-to-orange gradient background, white heart with ECG pulse line.

To regenerate icons after changes:
```bash
python3 generate_icon.py
flutter pub run flutter_launcher_icons
```

---

## 15. Android Package Name

**Package:** `com.mymedicalwallet.app`  
**Changed from:** `com.medreminder.medication_reminder` (was taken on Google Play)  
**MainActivity location:** `android/app/src/main/kotlin/com/mymedicalwallet/app/MainActivity.kt`

---

## 16. Google Play & App Store

| Platform | Status |
|---|---|
| iOS (TestFlight) | Build 2012 uploaded |
| Android (Google Play) | Closed testing — in review |

**Play Store assets location:** `images/`
- `play_store_icon_512.png` — 512×512 store icon
- `play_store_feature_graphic.png` — 1024×500 feature graphic
- `screenshot_*.png` — phone, 7-inch, and 10-inch tablet screenshots

**Privacy policy:** `docs/privacy-policy.html` (hosted on GitHub Pages)
