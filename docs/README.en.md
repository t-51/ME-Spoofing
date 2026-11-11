# ME Spoofing — MHPanel Anti-DPI & Multi-Transport Proxy

[![Flutter CI](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)
[![Google Play Compliant](https://img.shields.io/badge/Google%20Play-VPN%20Exempt%20(Userspace%20Proxy)-brightgreen)](https://developer.android.com/distribute/play-policies)
[![Languages](https://img.shields.io/badge/Languages-10%20Locales-blue)](../lib/l10n/app_localizations.dart)
[![Version](https://img.shields.io/badge/Version-1.1.0-orange)](../pubspec.yaml)

---

## 📖 Overview

**ME Spoofing** is an advanced, high-performance userspace proxy relay and Deep Packet Inspection (DPI) circumvention engine developed for **MHPanel**. It provides robust, low-latency censorship bypass using multi-layered transport protocols — TCP fragmentation, decoy SNI injection, and Cloudflare Anycast IP fronting — without requiring any VPN permissions or system-level privileges.

---

## 🏗️ Architecture & Google Play Compliance (No VpnService)

Unlike conventional VPN applications, **ME Spoofing does not register or use Android's `VpnService` API**:

| Property | Detail |
|---|---|
| **No System VPN Profile** | Does not alter OS-level global routing tables or install virtual TUN interfaces |
| **Pure Userspace Local Relay** | Engine binds exclusively to `127.0.0.1:<ports>` as an intelligent forwarder |
| **100% Google Play Policy Compliant** | Completely exempt from Google Play VPN application restrictions |
| **Universal Client Support** | Compatible with **Happ**, **v2rayNG**, **Npv Tunnel**, **Sing-box**, Telegram proxy, browsers |

This architecture means the app requires **no special permissions** beyond internet access, making it safe, lightweight, and fully policy-compliant.

---

## 🚀 Two Transport Modes

### Mode 1 — Direct SNI Spoofing & TCP Fragmentation (Port 15443)

Direct connection to MHPanel edge nodes with:
- **Micro-fragmentation of TLS ClientHello** across TCP record boundaries with microsecond-level delays
- **Decoy fake SNI injection** — trusted domain names are injected to fool DPI inspection engines
- Best for most networks where the main server IP is reachable

### Mode 2 — Cloudflare Clean IP Transport (Port 443)

Routes all traffic via clean, unblocked **Cloudflare Anycast IP addresses** with:
- **Dynamic SNI rewriting and fragmentation** to prevent ISP-level SNI-based filtering
- **Anycast IP fronting** — traffic arrives at Cloudflare's global network before being forwarded
- Best for environments where the primary MHPanel server IP is blocked

---

## ⚡ Key Features

### 📊 Live Connection Logs (Filterable)

Real-time streaming log view with four filter tabs:
- **All** — every proxy event
- **Fake Injection** — SNI spoofing & decoy injection events
- **Fragment** — TCP fragmentation events
- **Errors** — connection errors and warnings

### 📡 Live Network Statistics

Real-time network metrics displayed on the home screen:
- **Download speed** (live, per-second)
- **Upload speed** (live, per-second)
- **Active concurrent connections** count

### 🔀 Routing Assistant Dialog

A smart config conversion tool:
1. Paste your existing V2Ray / Xray JSON config
2. The assistant rewrites it to use `127.0.0.1:<port>` as the upstream
3. Outputs a ready-to-use config **plus** bypass routing rules for local traffic
4. Paste the result directly into Happ, v2rayNG, Sing-box, or Npv Tunnel

### ⏱️ Smart Timer & Reward System

- Timer **only counts down while actively connected** — pauses immediately on disconnect
- Prevents unfair time consumption during network interruptions
- **4-hour bonus reward** available via ad-watching

### 🔄 Live Update Checker

- Checks GitHub Releases for new versions on demand
- Accessible via the **bell icon** in the app header
- Shows changelog summary for available updates

### 🔧 Dynamic Port Management

- Add, edit, and remove any number of local listener ports from Settings
- Each port can be independently configured and toggled

### 🎨 Dark / Light Theme

- Automatically follows the OS dark/light mode setting
- Overridable manually in app settings

### 🌍 10-Language Internationalization

Full RTL and LTR support for: **Persian, English, Arabic, Chinese (Simplified), Russian, Spanish, Italian, German, French, Hindi**  
Automatic system language detection on first launch.

---

## 📱 Setup Guide

### Step 1: Install the APK

Download the latest release APK from [GitHub Releases](https://github.com/t-51/snispoof/releases) and install it.

### Step 2: Choose Your Transport Mode

| Scenario | Recommended Mode |
|---|---|
| Server IP is reachable | Mode 1 — SNI Fragmentation |
| Server IP is blocked | Mode 2 — Cloudflare Clean IP |

### Step 3: Connect

1. Open the app and tap **Connect**
2. The proxy becomes available at `127.0.0.1:<configured port>`
3. Configure your preferred client (Happ, v2rayNG, etc.) to use this proxy address

### Step 4: Use the Routing Assistant (Optional)

If you have an existing V2Ray/Xray config:
1. Tap the **Routing Assistant** icon on the home screen
2. Paste your config JSON
3. Copy the converted config — it's ready to use in any supported client

### Step 5: Configure Your Client

Point your client's proxy settings to `127.0.0.1:<port>`. Example for common clients:

- **Happ**: Paste the routing profile generated by the Routing Assistant
- **v2rayNG**: Import the converted config from the Routing Assistant
- **Sing-box**: Use the converted outbound config with the generated routing rules
- **Telegram**: Set SOCKS5 proxy to `127.0.0.1:<port>`

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

# Run the test suite (12 unit tests)
flutter test

# Build production APK
flutter build apk --release
```

---

## 🔗 Back to Main README

[← Back to README](../README.md)

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](../LICENSE) file for details.
