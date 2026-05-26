# Deployment Priorities

## Priority 1 — This Week (Build & Security)

- [ ] Fix CI so a clean release APK builds successfully
- [ ] Create release keystore, configure signing in `android/app/build.gradle`
      (store credentials as GitHub Secrets — never commit the keystore)
- [ ] Replace `GUARDIAN_PUBLIC_KEY_PLACEHOLDER` in `notification_monitoring_service.dart:76`
      and `deep_scan_service.dart:57` with a real key exchange mechanism

## Priority 2 — Before Any Users

- [ ] Write tests for `SecurityEngine`, `ThreatRepository`, and SOS trigger
- [ ] Implement ML Kit OCR in `image_scam_analyzer.dart` or remove the screenshot
      scan feature from the UI entirely
- [ ] Draft a privacy policy and host it at a public URL

## Priority 3 — Before Play Store

- [ ] Set up backend or replace `family_safety_relay.dart` API calls with a real
      messaging mechanism (Firebase, WhatsApp Business API, etc.)
- [ ] Prepare Accessibility Service policy justification for Google Play review
- [ ] Beta test with 5–10 real elderly users on physical devices
- [ ] Remove empty Google Maps API key from `AndroidManifest.xml` or obtain a real one
