# ME Spoofing — MHPanel Anti-DPI & Multi-Transport Proxy

[![Flutter CI](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Google Play Compliant](https://img.shields.io/badge/Google%20Play-VPN%20Exempt%20(Userspace%20Proxy)-brightgreen)](https://developer.android.com/distribute/play-policies)
[![Languages](https://img.shields.io/badge/Languages-10%20Locales-blue)](lib/l10n/app_localizations.dart)

**ME Spoofing** is an advanced, high-performance userspace proxy relay and DPI-circumvention engine developed for **MHPanel**. It provides robust censorship bypass using multi-layered transport protocols, TCP fragmentation, decoy SNI injection, Cloudflare Clean IP fronting, and userspace DNS tunneling.

---

## 🛡️ Architecture & Google Play Compliance (No VpnService)

Unlike conventional VPN applications, **ME Spoofing does not register or use Android's `VpnService` API**. 

* **No System VPN Profile:** The application does not alter the operating system's global network routing tables, install TUN virtual interfaces, or require VPN permissions.
* **Pure Userspace Local Relay:** The engine binds exclusively to local loopback addresses (`127.0.0.1:<ports>`), acting as an intelligent intermediate forwarder.
* **100% Google Play Policy Compliant:** Because the app is a userspace proxy rather than a system-level tunnel, it is entirely exempt from Google Play Store restrictions on VPN services.
* **Universal Client Support:** Compatible with any application supporting socks5, http, or local TCP listening (e.g., **Happ**, **v2rayNG**, **Shadowsocks**, Telegram proxy settings, and desktop/mobile web browsers).

---

## 🚀 Three Multi-Transport Modes

ME Spoofing incorporates the latest [MHPanel Multi-Transport Specification](https://github.com/t-51/MHPanel/blob/main/docs/ANDROID_DNS_TUNNEL_AND_MULTI_TRANSPORT_SPEC.md):

### 1. Mode 1: Direct SNI & TCP Fragmentation (Port 15443)
* Direct connection to MHPanel edge nodes over port `15443`.
* Real-time TCP segmentation of the TLS ClientHello across record boundaries with configurable microsecond delays (`_mhFragmentDelayMs`).
* Decoy fake SNI injection (`speedtest.net`, `shaparak.ir`, etc.) to deceive Deep Packet Inspection (DPI) firewalls.
* Automatic server host failover across configured host lists.

### 2. Mode 2: Cloudflare Clean IP Transport (Port 443)
* Routes traffic through verified, unblocked Cloudflare Anycast IP addresses.
* Dynamic SNI rewriting and fragmentation prevents SNI-based filtering on ISP networks.
* Ideal for environments where direct connection to panel servers is completely filtered at the IP level.

### 3. Mode 3: DNS Tunnel Transport (VayDNS, DNSTT, Slipstream, NoizDNS)
* Encapsulates connection streams into DNS requests when all direct TCP/UDP ports are throttled or severed.
* Supports **DNS over HTTPS (DoH)** as well as **Standard UDP 53**.
* Zero kernel TUN dependencies; runs completely in userspace and relays traffic to local port listeners.

---

## ⚡ Key Features

* **Dynamic Port Management (No Hardcoding):** Add, remove, and manage any number of custom listener ports on the fly directly in Settings.
* **Smart Time & Allowance System:**
  * **Base Free Time:** Only consumes allowance while the proxy is connected. **Disconnecting immediately pauses the timer** and prevents background consumption.
  * **Zero Auto-Reconnect:** When disconnected or allowance expires, the proxy remains safely stopped until you explicitly tap the connect button.
  * **4-Hour Rewarded Ad Time:** Watch an optional ad to receive 4 full hours of wall-clock allowance.
* **10-Language Internationalization (i18n):**
  * Fully localized in **Persian (فارسی)**, **English**, **Arabic (العربية)**, **Chinese (中文)**, **Russian (Русский)**, **Spanish (Español)**, **Italian (Italiano)**, **German (Deutsch)**, **French (Français)**, and **Hindi (हिन्दी)**.
  * Supports system default locale detection, manual language switching, and comprehensive RTL/LTR layouts.
* **Theme Modes:**
  * Follows system theme (Dark/Light) by default.
  * Switch between System, Light, and Dark modes directly in Settings.
  * Unified theme synchronization across the Home screen, Settings, and live connection Logs screen.
* **Integrated Update Notification (Header Bell):**
  * Tap the notification bell in the header to check GitHub releases in real-time.
  * Displays version changelogs and provides direct one-tap APK download and installation.

---

## 📱 How to Use with Client Apps (e.g. Happ / v2rayNG)

1. Launch **ME Spoofing** and configure your server details in **Settings** (or use the preloaded MHPanel defaults).
2. Tap the central power button to start the engine. The status will turn **ACTIVE**.
3. Note your active local ports (e.g., `20456`, `20451`, `10809`, etc.).
4. In your client app (such as Happ or v2rayNG):
   * Set your server address / outbound address to `127.0.0.1`.
   * Set the port to match your chosen active port in ME Spoofing.
5. Connect your client — all outbound traffic will be spoofed, fragmented, and tunneled cleanly past DPI firewalls!

---

## 🛠️ Building & Development

### Prerequisites
* Flutter SDK `^3.9.0`
* Android SDK (API level 24+)

### Quick Start
```bash
# Clone the repository
git clone https://github.com/t-51/snispoof.git
cd snispoof

# Install dependencies
flutter pub get

# Run test suite
flutter test

# Build production APK
flutter build apk --release
```

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

