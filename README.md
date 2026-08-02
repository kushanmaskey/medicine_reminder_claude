# My Medical Wallet

A Flutter app for iOS and Android that helps adults manage medications, doctors, vitals, appointments, and health records in one place.

**Package:** `com.mymedicalwallet.app`  
**Current Version:** 1.0.2+2017  
**Backend:** Supabase (PostgreSQL + Auth)  
**In-App Subscriptions:** RevenueCat

---

## Documentation

Full technical documentation is in [`DOCUMENTATION.md`](DOCUMENTATION.md), including:
- Project structure and dependencies
- Data models and services
- Supabase database schema
- Key app flows
- Platform permissions
- RevenueCat subscription setup
- Apple App Store payment & tax setup
- Google Play payment setup

---

## App Store Status

| Platform | Version | Status |
|---|---|---|
| iOS (App Store) | 1.0.2 (build 2017) | Waiting for Review |
| Android (Google Play) | — | Closed testing |

---

## Payment Setup Status

### Apple App Store Connect
| Item | Status |
|---|---|
| Paid Apps Agreement | Processing |
| Bank of America (8712) | Processing |
| W-9 Tax Form | Active |

### Google Play
| Item | Status |
|---|---|
| Checking account (712) | Verification pending — awaiting two test deposits |

> See [`DOCUMENTATION.md`](DOCUMENTATION.md) sections 17–19 for full details on RevenueCat, Apple, and Google Play payment setup.

---

## Local Development

### Prerequisites
- Flutter SDK 3.11+
- Xcode (iOS)
- Android Studio (Android)

### Run

```bash
flutter pub get
flutter run
```

### Build iOS

```bash
flutter build ipa --release
```

### Build Android

```bash
flutter build appbundle --release
```
