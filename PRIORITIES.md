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

## Future Utilities (Post-Launch)

### WhatsApp Storage Cleaner
Scan `/Android/media/com.whatsapp/WhatsApp/Media/`, categorize by age/size/type,
bulk-delete old forwarded images and videos. Storage permission already granted.
High viral potential — "free up 2.3 GB on first run" is a shareable result.

### OTP SMS Organizer
Already reading every SMS. Collect OTPs into a dedicated tab, auto-expire old
ones, bulk-delete with one tap. Strengthens security story (stale OTPs in inbox
are a risk) while being immediately useful.

### Spam Call Log Cleaner
Every call is already scored. Numbers flagged as scam/robocall can be offered for
bulk-deletion from the system call log. Quick to build, satisfying result.

### Family Quick-Dial Panel
Large-button speed-dial screen for saved guardian/family contacts. High value for
elderly users. Reuses family contacts already stored in SQLite.

### UPI Transaction Log
AccessibilityService already detects GPay/PhonePe/Paytm opens. Parse screen
content further to build a unified payment history across all UPI apps — something
no individual UPI app provides today.

> Note: Do NOT build call recording — legally grey in India, banned by Google Play.
