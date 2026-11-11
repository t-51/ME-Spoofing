# ME Spoofing — MHPanel Anti-DPI & Multi-Transport Proxy

[![Flutter CI](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Google Play Compliant](https://img.shields.io/badge/Google%20Play-VPN%20Exempt%20(Userspace%20Proxy)-brightgreen)](https://developer.android.com/distribute/play-policies)
[![Languages](https://img.shields.io/badge/Languages-10%20Locales-blue)](lib/l10n/app_localizations.dart)
[![Version](https://img.shields.io/badge/Version-1.1.0-orange)](pubspec.yaml)

**ME Spoofing** is a high-performance, 100% userspace proxy relay and Deep Packet Inspection (DPI) circumvention engine for **MHPanel**. It bypasses internet censorship via TCP micro-fragmentation, decoy SNI injection, and Cloudflare Anycast IP fronting — with no VPN permissions, no TUN interfaces, and full Google Play compliance.

---

## 🌐 Read in Your Language

| Language | File |
|---|---|
| 🇮🇷 فارسی | [docs/README.fa.md](docs/README.fa.md) |
| 🇺🇸 English | [docs/README.en.md](docs/README.en.md) |
| 🇸🇦 العربية | [docs/README.ar.md](docs/README.ar.md) |
| 🇨🇳 简体中文 | [docs/README.zh.md](docs/README.zh.md) |
| 🇷🇺 Русский | [docs/README.ru.md](docs/README.ru.md) |
| 🇪🇸 Español | [docs/README.es.md](docs/README.es.md) |
| 🇮🇹 Italiano | [docs/README.it.md](docs/README.it.md) |
| 🇩🇪 Deutsch | [docs/README.de.md](docs/README.de.md) |
| 🇫🇷 Français | [docs/README.fr.md](docs/README.fr.md) |
| 🇮🇳 हिन्दी | [docs/README.hi.md](docs/README.hi.md) |

---

## ⚡ Quick Start (English)

### Two Transport Modes

| Mode | Protocol | Port | Use When |
|---|---|---|---|
| **Mode 1** | Direct SNI Spoofing + TCP Fragmentation | 15443 | Server IP is reachable |
| **Mode 2** | Cloudflare Clean IP Anycast | 443 | Server IP is blocked |

### Install & Connect

1. Download the latest APK from [**GitHub Releases**](https://github.com/t-51/snispoof/releases)
2. Open the app → Select a transport mode → Tap **Connect**
3. Configure your client (Happ, v2rayNG, Sing-box, Npv Tunnel, Telegram) to use `127.0.0.1:<port>`
4. Use the **Routing Assistant** to auto-convert your existing V2Ray/Xray config

For the full English guide → [docs/README.en.md](docs/README.en.md)

---

## 🔑 Key Highlights

- 🛡️ **No VpnService** — pure userspace proxy, 100% Google Play compliant
- 🔀 **Routing Assistant** — paste V2Ray config → get `127.0.0.1` config + bypass rules
- 📊 **Live Logs** — filterable by: All / Fake Injection / Fragment / Errors
- 📡 **Network Stats** — live download speed, upload speed, active connections
- ⏱️ **Smart Timer** — counts only while connected, 4-hour ad reward
- 🔄 **Live Update Checker** — GitHub release notifications via bell icon
- 🌍 **10 Languages** — fa, en, ar, zh, ru, es, it, de, fr, hi (auto-detect + RTL/LTR)

---

## 🛠️ Build & Development

### Prerequisites

- Flutter SDK `^3.9.0`
- Android SDK (API level 24+)

```bash
# Clone the repository
git clone https://github.com/t-51/snispoof.git
cd snispoof

# Install dependencies
flutter pub get

# Run test suite (12 unit tests)
flutter test

# Build production APK
flutter build apk --release
```

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
