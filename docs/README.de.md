# ME Spoofing — Multi-Transport Anti-DPI Proxy für MHPanel

[![Flutter CI](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)
[![Google Play Compliant](https://img.shields.io/badge/Google%20Play-VPN%20befreit%20(Userspace%20Proxy)-brightgreen)](https://developer.android.com/distribute/play-policies)
[![Languages](https://img.shields.io/badge/Sprachen-10%20Lokalisierungen-blue)](../lib/l10n/app_localizations.dart)
[![Version](https://img.shields.io/badge/Version-1.1.0-orange)](../pubspec.yaml)

---

## 📖 Übersicht

**ME Spoofing** ist eine leistungsstarke Userspace-Proxy-Engine und Anti-DPI-Lösung (Deep Packet Inspection) für **MHPanel**. Sie bietet robuste Zensurumgehung durch mehrschichtige Übertragungsprotokolle — TCP-Fragmentierung, SNI-Täuschungsinjektion und Cloudflare Anycast IP-Fronting — ohne VPN-Berechtigungen oder Systemprivilegien zu benötigen.

---

## 🏗️ Architektur & Google Play-Konformität (Kein VpnService)

Im Gegensatz zu herkömmlichen VPN-Anwendungen **registriert und verwendet ME Spoofing die `VpnService` API von Android nicht**:

| Eigenschaft | Detail |
|---|---|
| **Kein System-VPN-Profil** | Modifiziert keine systemweiten Routing-Tabellen und installiert keine virtuellen TUN-Schnittstellen |
| **Reiner Userspace-Proxy** | Der Motor bindet ausschließlich an `127.0.0.1:<Ports>` als intelligenter Weiterleitungs-Dienst |
| **100% richtlinienkonform** | Vollständig von Google Play-Einschränkungen für VPN-Anwendungen befreit |
| **Universelle Client-Kompatibilität** | Unterstützt Happ, v2rayNG, Npv Tunnel, Sing-box, Telegram und Browser |

---

## 🚀 Zwei Transport-Modi

### Modus 1 — Direktes SNI & TCP-Fragmentierung (Port 15443)

Direkte Verbindung zu MHPanel Edge-Knoten mit:
- **Mikrosekunden-Fragmentierung von TLS ClientHello** über TCP-Record-Grenzen hinweg
- **Fake-SNI-Injektion** — vertrauenswürdige Domainnamen werden injiziert, um DPI-Systeme zu täuschen
- Optimal für die meisten Netzwerke, in denen die Haupt-Server-IP erreichbar ist

### Modus 2 — Cloudflare Clean IP-Transport (Port 443)

Leitet den gesamten Datenverkehr über saubere, nicht gesperrte **Cloudflare Anycast IP-Adressen**:
- **Dynamische SNI-Neuschreibung und Fragmentierung** zur Verhinderung SNI-basierter ISP-Filterung
- **Anycast IP-Fronting** — Datenverkehr erreicht Cloudflares globales Netzwerk vor der Weiterleitung
- Optimal wenn die primäre MHPanel-Server-IP gesperrt ist

---

## ⚡ Hauptmerkmale

### 📊 Live-Verbindungsprotokolle (Filterbar)

Echtzeit-Streaming-Protokollansicht mit vier Filterregisterkarten:
- **Alle** — jedes Proxy-Ereignis
- **Fake-Injektion** — SNI-Spoofing- und Täuschungs-SNI-Injektionsereignisse
- **Fragment** — TCP-Fragmentierungsereignisse
- **Fehler** — Verbindungsfehler und Warnungen

### 📡 Live-Netzwerkstatistiken

Echtzeit-Netzwerkmetriken auf dem Hauptbildschirm:
- **Download-Geschwindigkeit** (live, pro Sekunde)
- **Upload-Geschwindigkeit** (live, pro Sekunde)
- Anzahl **aktiver gleichzeitiger Verbindungen**

### 🔀 Routing-Assistent

Intelligentes Konfigurationskonvertierungs-Tool:
1. Fügen Sie Ihre vorhandene V2Ray / Xray JSON-Konfiguration ein
2. Der Assistent schreibt sie um, um `127.0.0.1:<Port>` als Upstream zu verwenden
3. Gibt eine sofort einsetzbare Konfiguration **plus** Bypass-Routing-Regeln für lokalen Datenverkehr aus
4. Ergebnis direkt in Happ, v2rayNG, Sing-box oder Npv Tunnel einfügen

### ⏱️ Intelligentes Timer- & Belohnungssystem

- Timer **zählt nur bei aktiver Verbindung** — pausiert sofort bei Trennung
- Verhindert unfairen Zeitverbrauch bei Netzwerkunterbrechungen
- **4-Stunden-Bonus** verfügbar durch Ansehen von Werbung

### 🔄 Live-Update-Prüfer

- Prüft GitHub Releases auf neue Versionen bei Bedarf
- Zugänglich über das **Glockensymbol** in der App-Kopfzeile
- Zeigt Changelog-Zusammenfassung für verfügbare Updates

### 🔧 Dynamische Portverwaltung

- Beliebige Listener-Ports in den Einstellungen hinzufügen, bearbeiten und entfernen

### 🎨 Dunkles / Helles Design

- Folgt automatisch der OS-Einstellung für Dunkel-/Hellmodus
- Manuell in den App-Einstellungen anpassbar

### 🌍 10-Sprachen-Internationalisierung

Vollständige RTL- und LTR-Unterstützung für: **Deutsch, Persisch, Englisch, Arabisch, Chinesisch, Russisch, Spanisch, Italienisch, Französisch, Hindi**  
Automatische Systemspracherkennung beim ersten Start.

---

## 📱 Einrichtungsanleitung

### Schritt 1: APK installieren

Laden Sie die neueste APK von [GitHub Releases](https://github.com/t-51/snispoof/releases) herunter und installieren Sie sie.

### Schritt 2: Transport-Modus wählen

| Szenario | Empfohlener Modus |
|---|---|
| Server-IP erreichbar | Modus 1 — SNI-Fragmentierung |
| Server-IP gesperrt | Modus 2 — Cloudflare Clean IP |

### Schritt 3: Verbinden

1. App öffnen und auf **Verbinden** tippen
2. Der Proxy ist auf `127.0.0.1:<konfigurierter Port>` verfügbar
3. Bevorzugten Client (Happ, v2rayNG usw.) konfigurieren, um diese Proxy-Adresse zu verwenden

### Schritt 4: Routing-Assistent verwenden (Optional)

Wenn Sie eine vorhandene V2Ray/Xray-Konfiguration haben:
1. Tippen Sie auf das **Routing-Assistent**-Symbol auf dem Hauptbildschirm
2. Fügen Sie Ihre Konfigurations-JSON ein
3. Konvertierte Konfiguration kopieren — sofort einsetzbar in jedem unterstützten Client

---

## 🛠️ Build & Entwicklung

### Voraussetzungen

- Flutter SDK `^3.9.0`
- Android SDK (API-Level 24+)

```bash
# Repository klonen
git clone https://github.com/t-51/snispoof.git
cd snispoof

# Abhängigkeiten installieren
flutter pub get

# Testsuite ausführen (12 Unit-Tests)
flutter test

# Produktions-APK erstellen
flutter build apk --release
```

---

## 🔗 Zurück zur Haupt-README

[← Zurück zur README](../README.md)

---

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert — Details in der Datei [LICENSE](../LICENSE).
