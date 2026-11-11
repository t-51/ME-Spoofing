# Privacy Policy for ME Spoofing

**Application:** ME Spoofing (`com.kigaping.mespoofing`)  
**Developer:** MHPanel / t-51  
**Effective Date:** November 12, 2026  

---

## 1. Overview
This Privacy Policy describes how **ME Spoofing** ("we", "our", or "the app") handles user data. We take user privacy seriously. **ME Spoofing is built from the ground up as a privacy-centric, zero-logging local proxy engine.**

---

## 2. No Collection of Personal Data (Zero-Log Policy)
We strictly adhere to a **Zero-Log Policy**:
- We **do not** collect, store, inspect, monitor, or share any personal identifiable information (PII).
- We **do not** track or record your browsing history, accessed domains, visited websites, DNS queries, or payload contents.
- The app operates as an in-memory, userspace proxy bound to `127.0.0.1`. All packet transformations (including TCP fragmentation and decoy SNI injection) happen solely in the device's volatile memory.
- No network traffic or telemetry is uploaded to any servers managed by the developer.

---

## 3. Third-Party Services & Advertising
To support ongoing maintenance and provide optional reward time, the application integrates third-party ad services:

### Google AdMob (Google Mobile Ads SDK)
The app displays banner ads and rewarded video advertisements powered by Google AdMob. To serve advertisements and prevent fraudulent activity, Google AdMob may automatically collect and process certain non-personally identifiable diagnostic and device metrics, including:
- Google Advertising ID (GAID)
- Coarse location data (derived from IP address by Google)
- Hardware device model, OS version, and language
- Ad interaction metrics, diagnostic logs, and performance statistics

For more information on how Google collects and uses data, please refer to:
- [Google Privacy Policy](https://policies.google.com/privacy)
- [How Google uses information from sites or apps that use our services](https://policies.google.com/technologies/partner-sites)

---

## 4. Android Permissions
The application requests only permissions essential to providing local proxy functionality:

| Permission | Purpose |
|---|---|
| `android.permission.INTERNET` | Enables the proxy engine to relay outbound requests initiated by the user. |
| `android.permission.ACCESS_NETWORK_STATE` | Monitors network connectivity changes (e.g. Wi-Fi to Mobile Data) for connection stability. |
| `android.permission.POST_NOTIFICATIONS` | Displays a persistent notification showing active proxy status (Android 13+). |
| `android.permission.FOREGROUND_SERVICE` (`dataSync` / `specialUse`) | Keeps the user-initiated proxy service active in the background without being killed by the OS. |
| `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Optional user prompt to ensure device battery savers do not terminate the proxy prematurely. |
| `android.permission.RECEIVE_BOOT_COMPLETED` | Optional automatic proxy service reconnection on device reboot (if enabled by user). |

> **Note:** ME Spoofing operates strictly as a userspace socket relay and does **not** require or use Android's `VpnService` permission.

---

## 5. Children's Privacy
ME Spoofing does not address or target anyone under the age of 13 (or under 16 in the European Union). We do not knowingly collect personal identifiable information from children.

---

## 6. Data Security
Because no personal user data or activity logs are transmitted to or stored on remote servers, your data is inherently protected against external data breaches.

---

## 7. Changes to This Privacy Policy
We may revise this Privacy Policy from time to time. Updates will be published directly to this page along with an updated effective date.

---

## 8. Contact Us
If you have any questions or concerns regarding this Privacy Policy, please contact us:
- **Email:** [ahmadi09120@gmail.com](mailto:ahmadi09120@gmail.com)
- **GitHub Issues:** [https://github.com/t-51/ME-Spoofing/issues](https://github.com/t-51/ME-Spoofing/issues)
