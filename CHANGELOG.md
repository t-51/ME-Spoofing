# Changelog

All notable changes to **ME Spoofing** will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] — 2026-11-11 — "Streamlined & Stable"

### 💥 Breaking Changes

- **Removed DNS Tunnel (Mode 3) completely.** This mode and all associated infrastructure has been removed. Apps configured to use Mode 3 must be reconfigured to use Mode 1 or Mode 2.

### 🗑️ Removed

- **DNS Tunnel transport mode** (previously Mode 3: VayDNS / DNSTT / Slipstream / NoizDNS)
- **Native binary libraries** (~26 MB total removed):
  - `lib/arm64-v8a/libdnstt.so`
  - `lib/armeabi-v7a/libdnstt.so`
  - `lib/x86_64/libdnstt.so`
- **DNS tunnel home screen status card** — the connection status card specific to DNS tunnel mode
- **DNS tunnel log filter tab** — "DNS Tunnel" tab removed from the live log filter row
- **DNS tunnel settings section** — resolver configuration, DoH/DoT/UDP/TCP transport selection, multi-resolver priority controls
- **DNS tunnel connection statistics** — DNS-specific latency telemetry and resolver ping display
- Over **2,000 lines of Dart code** related to DNS tunnel logic, state management, and UI

### ✨ Improved

- **Mode 1 (Direct SNI + TCP Fragmentation, Port 15443)** — improved connection stability and reliability
- **Mode 2 (Cloudflare Clean IP, Port 443)** — improved reconnection logic and clean IP rotation
- **APK size** — reduced from ~80 MB to ~54 MB (net reduction of ~26 MB native binaries)
- **App startup time** — faster cold start due to reduced initialization surface
- **Code quality** — significant reduction in dead code paths and conditional DNS-tunnel branching

### ✅ Testing

- All **12 unit tests** passing
- Test coverage verified for Mode 1 and Mode 2 transport paths

### 📚 Documentation

- Split monolithic `README.md` into per-language files in `docs/`
- Added this `CHANGELOG.md`

---

## [1.0.0] — Initial Release

### ✨ Added

- **Mode 1**: Direct SNI spoofing + TCP fragmentation (port 15443)
  - TLS ClientHello micro-fragmentation across record boundaries
  - Decoy fake SNI injection to bypass DPI firewalls
- **Mode 2**: Cloudflare Clean IP transport (port 443)
  - Anycast IP fronting with dynamic SNI rewriting
- **Mode 3**: DNS Tunnel transport (VayDNS, DNSTT, Slipstream, NoizDNS)
  - UDP 53, TCP 53, DoH 443, DoT 853 transport variants
  - Multi-resolver failover with live latency telemetry
- **10-language support**: fa, en, ar, zh, ru, es, it, de, fr, hi (RTL/LTR auto-detection)
- **Routing Assistant**: paste V2Ray/Xray config → receive `127.0.0.1` config + bypass routing rules
- **Live connection logs**: filterable by All / Fake Injection / Fragment / DNS Tunnel / Errors
- **Live network stats**: download speed, upload speed, active connections
- **Smart timer system**: counts only while connected, pauses on disconnect
- **4-hour reward system**: bonus time via ad-watching
- **Dynamic port management**: add/edit/remove local listener ports from Settings
- **Live update checker**: GitHub release notifications via header bell icon
- **Dark/Light theme**: OS-synced or manually configured
- **Google Play compliant**: no `VpnService` API, no TUN interfaces, pure userspace relay

---

[1.1.0]: https://github.com/t-51/snispoof/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/t-51/snispoof/releases/tag/v1.0.0
