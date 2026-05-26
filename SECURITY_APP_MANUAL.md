# AI Security: Anti-Scam & Elderly Safety Platform
## User Manual & Technical Specification (Updated)

### 1. Overview
AI Security is a production-grade, privacy-first security platform designed specifically for the Indian digital landscape. This app provides **Active Adversarial Defense**—it doesn't just filter spam; it predicts and blocks the specific tools and behaviors used by professional scam syndicates (Jamtara 2.0).

### 2. Core Protection Layers (Hardened)

#### A. On-Device Local AI (SLM)
The app runs a highly compressed **Small Language Model (SLM)** directly on your phone.
*   **Privacy:** No message content ever leaves your device.
*   **Accuracy:** Uses BERT-tiny quantized models to understand the *intent* of a message (e.g., a "Digital Arrest" threat vs. a real legal notice).

#### B. Cross-App Scanning & Adversarial Normalization
*   **Encrypted App Monitoring:** Uses Android Accessibility and Notification services to monitor WhatsApp, Telegram, and Signal.
*   **Bypass Prevention:** Includes a **Text Normalizer** that cleans character substitutions like `S.B.I`, `K_Y_C`, or `A@dhaar`, ensuring scammers cannot bypass filters using special characters or dots.

#### C. The "Last Mile" Transaction Shield
*   **Logic:** Monitors major Indian payment apps (**GPay, PhonePe, Paytm, BHIM**).
*   **Intervention:** If a payment app is opened within 15 minutes of receiving a critical scam alert, the app triggers a **High-Priority Safety Interceptor** to stop the user from sending money.

#### D. Remote Access Shield (Elite Protection)
*   **Anti-Takeover:** Monitors for the installation or opening of remote desktop apps like **AnyDesk, TeamViewer, and RustDesk**.
*   **Active Lockdown:** If these apps are opened during a potential scam event, the app triggers a **Remote Access Lockdown** alert, warning the user that their phone is about to be compromised.

#### E. Clipboard Guardian (OTP Protection)
*   **OTP Shield:** Monitors the system clipboard for sensitive 4-6 digit codes.
*   **Theft Prevention:** Detects if an OTP is copied while a scam threat is active, preventing the user from accidentally giving the code to a scammer over a call or remote session.

#### F. Family Safety Relay
*   **Guardian Alerts:** High-risk threats (Digital Arrest, Financial Fraud) are automatically relayed to a "Guardian" (son/daughter) via end-to-end encrypted alerts.

---

### 3. Screen Walkthrough

#### **Screen 1: Dashboard (The Shield)**
*   **Protection Score:** A real-time 0-100 score of your device's safety.
*   **Security Health Banner:** Appears automatically if vital permissions (Accessibility, Notification Access) are missing.
*   **Recent Activity:** A persistent log of the latest scams blocked, surviving even app restarts via SQLite.

#### **Screen 2: Permission Guardian (Mission Control)**
*   **Status Indicators:** One-tap status of SMS, Phone, Notification, and Deep Protection layers.
*   **Guided Setup:** Direct links to enable complex Android permissions with educational context.

#### **Screen 3: iOS Safety Scanner (Active Assistant)**
*   **Screenshot Scan:** iOS users can take a screenshot of a suspicious WhatsApp chat and scan it here.
*   **On-Device OCR:** Extracts text and provides an instant risk assessment using Apple's Vision Engine.

---

### 4. Why This is "Better than Google/Truecaller/Airtel"

| Feature | Standard Apps | **AI Security Platform** |
| :--- | :--- | :--- |
| **WhatsApp Content** | Blind | **Full Visibility** (Accessibility Layer) |
| **Digital Arrest** | Misses (Context blind) | **Active Detection & Education** |
| **GPay/PhonePe** | No Action | **Transaction Interceptor** |
| **AnyDesk/TeamViewer**| Ignored | **Remote Access Lockdown** |
| **Character Bypasses**| Easily Fooled | **Text Normalization Shield** |
| **Privacy** | Cloud Uploads | **Zero-Knowledge Architecture** |

---

### 5. Technical Compilation Guide (APK)

To compile the production APK, run the following in your terminal:

```powershell
# 1. Clean and prepare
flutter clean
flutter pub get

# 2. Generate persistent models
dart run build_runner build --delete-conflicting-outputs

# 3. Build Production APK (obfuscated)
flutter build apk --release --target-platform android-arm64 `
  --obfuscate `
  --split-debug-info=build/symbols
```

> **Debug symbols**: `build/symbols/` contains the mapping files needed to decode obfuscated stack traces from crash reports. Store these securely alongside each release — do not ship them in the APK.
