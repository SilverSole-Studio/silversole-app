# SilverSole App Privacy Policy

**Last updated: August 31, 2026**
**Effective date: August 31, 2026**

> This is the English translation of the SilverSole privacy policy. In the event of any discrepancy, the Traditional Chinese version (`PRIVACY.zh-TW.md`) shall prevail.

---

## 1. About This Policy

DongYu Technology Co., Ltd. (動域科技股份有限公司, hereinafter "the Company", "we", "us") respects and protects your personal data. This policy explains how we collect, process, use, and safeguard your personal data when you use the **SilverSole mobile application** (the "App").

**Scope**

- This policy applies **only to the SilverSole mobile application** (Android / iOS).
- This policy does **not** apply to: the Company's website, the independent privacy policies of third-party services (Google, GitHub, etc.), or any other application you choose to send exported files to from within the App.

By downloading, installing, or using the App, you confirm that you have read and agree to this policy. If you do not agree, please discontinue use of the App.

---

## 2. Data Controller and Contact

| Item | Details |
| --- | --- |
| Company | DongYu Technology Co., Ltd. (動域科技股份有限公司) |
| Business registration no. | 62134975 |
| Registered address | 1F., No. 33, Dade Rd., Sanxia Dist., New Taipei City 237021, Taiwan |
| Privacy contact email | contact@dongyu.company |
| Support phone | +886 967-030-336 |

---

## 3. Data We Collect

### 3.1 Data you provide

| Category | Items | When collected |
| --- | --- | --- |
| Account identifiers | Email address, password | Sign-up and sign-in |
| Device binding data | Smart insole Device ID, device nickname | When pairing or binding a device |
| Preferences | Role (caregiver / wearer), transmission method, dark mode, theme, language | When you change settings |

> Sign-up requires **only an email address and a password**. We do not ask for your name, national ID, date of birth, phone number, or profile photo. Passwords are stored as one-way hashes by our backend provider; the Company cannot recover your plaintext password.

### 3.2 Data received from the smart insole

Over a Bluetooth Low Energy (BLE) connection, the App receives the following from the insole:

| Category | Items |
| --- | --- |
| Inertial sensor data | Tri-axis acceleration (ax / ay / az), tri-axis angular velocity (gx / gy / gz), pitch, roll |
| Plantar pressure data | Pressure values per sensing point, aggregate pressure |
| Wear and activity state | Whether the insole is being worn, activity timestamps |
| Device health | Battery percentage, charging state, heartbeat timestamps |
| Event data | Fall-detection trigger signals |
| Bluetooth connection info | Bluetooth device name, Bluetooth address / remote ID, signal strength |

> **Important**: Plantar pressure, gait, and fall-detection data may be considered health-related data. We process it only for the purposes described in this policy. **The App is a lifestyle and record-keeping aid, not a medical device. Its readings must not be used as the sole basis for medical diagnosis, treatment, or emergency response.**

### 3.3 Location data

| Purpose | Description | Leaves your phone? |
| --- | --- | --- |
| Show your current position on the map | The App requests your current coordinates from the operating system when you tap "locate" on the map screen or configure a safe zone | **No.** Used on-device only; not uploaded, not stored |
| Show the insole's location | The App reads location records (latitude, longitude, accuracy, timestamp) associated with your device from the backend | Provided by the backend; the App only reads and displays them |

### 3.4 Automatically generated technical data

| Category | Description |
| --- | --- |
| Session and authentication data | Access token, user identifier (UUID) |
| Update checks | The App queries GitHub for new releases; that request exposes your IP address and User-Agent to GitHub |
| Error and diagnostic logs | Kept locally on your phone for debugging only; not automatically transmitted to the Company |

---

## 4. Purposes of Collection and Use

We collect and use your personal data for the following specific purposes:

| Purpose | Description |
| --- | --- |
| Account management and authentication | Creating your account, signing in, maintaining sessions, password reset |
| Device connection and binding | Scanning, pairing, and connecting the smart insole; remembering your preferred device |
| Core functionality | Real-time gait and pressure charts, battery and connection status, fall alerts, activity statistics and analytics |
| Location and safe-zone features | Displaying device location and safe-zone boundaries on the map |
| Service operation and improvement | Troubleshooting, bug fixing, delivering update notifications |
| Legal compliance | Responding to lawful requests from competent authorities |

**We do not** sell, rent, or trade your personal data to third parties, and we do not use your sensor data for undisclosed marketing or advertising.

---

## 5. Permissions

| Permission | Why it is needed | If you decline |
| --- | --- | --- |
| Bluetooth (scan / connect) | Discover and connect to the smart insole | The device cannot connect; all live features are unavailable |
| Location (precise / approximate) | (1) Required by the OS for Bluetooth scanning on Android 11 and below; (2) showing your position on the map and setting safe zones | Map positioning is unavailable; on some Android versions Bluetooth scanning will not work |
| Notifications | Ongoing Bluetooth connection notice, fall and anomaly alerts | You will not receive alerts |
| Foreground service (Android) | Keeps the insole's Bluetooth connection alive while the App is in the background or the screen is locked | The connection drops when you leave the App, producing gaps in your records |
| Network access | Reaching the backend, loading maps and mini-games, checking for updates | Only offline features remain usable |
| File access / sharing | Exporting your recorded sessions as a JSON file via the system share sheet | You cannot export data |

You may revoke any of these permissions at any time in your device settings. Revocation stops the corresponding feature but does not affect the lawfulness of processing carried out beforehand.

---

## 6. Storage and Retention

### 6.1 Stored on your phone

The following is kept on your device only and is never uploaded automatically:

- App settings (role, dark mode, theme, transmission method, language)
- Paired Bluetooth device list and preferred device
- A rolling buffer of recent live sensor samples (cleared when the App closes)
- The fall-event counter (valid for the current App session only; reset on restart)
- Local storage created by the mini-game web pages inside the in-app WebView

**How to delete**: clear the App's data in your system settings, or uninstall the App.

### 6.2 Stored on our backend

| Data | Retention |
| --- | --- |
| Account data (email, hashed password, UUID) | For the life of the account; deleted within 30 days of an account-deletion request |
| Device status and heartbeat records | 12 months |
| Measurement and activity records | 12 months |
| Location records | 3 months |

Once the retention period expires, the purpose of collection ceases, or you exercise your right to erasure, we delete, destroy, or anonymize your personal data, unless retention is required by law.

---

## 7. Third-Party Services

The App integrates the following third-party services, each governed by its own privacy policy, which we encourage you to review:

| Service | Provider | Purpose | Data it may receive |
| --- | --- | --- | --- |
| Supabase | Supabase Inc. | Authentication, database, backend functions | Email, hashed password, device data, measurement and location records, connection IP |
| Google Maps Platform | Google LLC | Map tiles and rendering | Map viewport coordinates, device and network information |
| Cloudflare | Cloudflare, Inc. | Hosting of the in-app HTML5 mini-games | IP address, browser information |
| GitHub | GitHub, Inc. (Microsoft) | Checking for and downloading App updates | IP address, User-Agent |

The App contains **no** third-party advertising SDKs, behavioral tracking SDKs, or social login SDKs.

### In-app web content and mini-games

The App embeds HTML5 mini-games in a WebView. These pages may store local data such as game progress in your browser storage. While a game is running, the App forwards the insole's live motion signal to the game page for control input; that signal stays on your device.

---

## 8. Disclosure and International Transfers

We disclose your personal data only in the following circumstances:

1. **With your consent or at your initiative** — for example, when you use the share feature to export a recording and send it to an app or recipient you choose. Once exported, the file is under your control; the Company can neither track nor recall it.
2. **Service providers** — the cloud providers listed in Section 7, who are required to process data only as necessary to provide their service.
3. **Legal requirements** — lawful requests from courts, prosecutors, or competent authorities.
4. **Corporate transactions** — in a merger, acquisition, or reorganization, with prior notice to you by appropriate means.

**International transfers**: the servers of the above providers may be located outside Taiwan (for example, in the United States or Singapore). By using the App, you understand and agree that your data may be transferred to, processed, and stored abroad. We require our processors to apply protections no lower than those set out in this policy.

---

## 9. Security Measures

- All communication between the App and our backend is encrypted with **HTTPS / TLS**.
- The backend database enforces **Row Level Security**, so each user can access only their own records.
- Passwords are stored as **one-way hashes**; Company personnel cannot view your plaintext password.
- Access tokens are kept in the App's private storage area provided by the operating system.

Although we apply reasonable technical and organizational measures, no transmission over the internet can be guaranteed to be absolutely secure. Please keep your credentials safe and do not share them.

---

## 10. Your Rights

Under Taiwan's Personal Data Protection Act (and, where applicable, comparable laws in your jurisdiction), you may:

1. **Inquire about or request access to** your personal data
2. **Request a copy** of it
3. **Request correction or supplementation**
4. **Request that we cease collecting, processing, or using it**
5. **Request its deletion**

You may also at any time:

- Change your preferences and bound devices inside the App.
- Revoke any permission in your system settings.
- **Delete your account** — email the privacy contact in Section 2. We will complete the request within 30 days of receiving it and verifying your identity.

We will respond within **15 days** of receiving your request (extendable once by a further 15 days, with reasons given). We may need to verify your identity before acting, to prevent unauthorized access to your data.

If you believe our handling of your data violates data protection law, you have the right to lodge a complaint with the competent supervisory authority.

---

## 11. Children and Minors

The App is not designed for children under the age of 12. If a minor uses the App, a parent or legal guardian should read and accept this policy and supervise that use. If we learn that we have collected a minor's personal data without the required consent, we will delete it promptly.

If the App is used to care for an elderly person or another person under care, please ensure you have that person's consent — or their legal guardian's — before binding a device and viewing their data.

---

## 12. Changes to This Policy

We may revise this policy in response to legal changes, new features, or technical updates. Revisions will be published in the App and on the Company's website, and the "Last updated" date above will change. For material changes — such as new categories of data or new purposes of use — we will notify you separately by in-app notice or email and, where required, seek your consent again.

---

## 13. Contact Us

For questions or comments about this policy, or to exercise any of the rights in Section 10, please contact us:

**DongYu Technology Co., Ltd. (動域科技股份有限公司)**
Privacy contact: contact@dongyu.company
Address: 1F., No. 33, Dade Rd., Sanxia Dist., New Taipei City 237021, Taiwan
Phone: +886 967-030-336

---

<!--
[TO COMPLETE BEFORE PUBLISHING]
1. [x] Registration number, address, support phone, privacy mailbox (Sections 2 and 13) — filled 2026-08-31
2. [x] Retention periods for each data category (Section 6.2) — recommended values adopted
3. [x] Account-deletion turnaround (Sections 6.2 and 10) — 30 days
4. [x] Public URL: https://dongyu.company/products/silversole/privacy/en
   (a copy lives in the website repo under src/content/privacy/silversole/ — sync it when this file changes)
5. If automatic cloud upload of measurement data is enabled later, update Sections 3.2 and 6.2 to match
-->
