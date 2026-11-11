# ME Spoofing — Proxy Multi-Trasporto Anti-DPI per MHPanel

[![Flutter CI](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)
[![Google Play Compliant](https://img.shields.io/badge/Google%20Play-Esente%20da%20VPN%20(Proxy%20Spazio%20Utente)-brightgreen)](https://developer.android.com/distribute/play-policies)
[![Languages](https://img.shields.io/badge/Lingue-10%20Locali-blue)](../lib/l10n/app_localizations.dart)
[![Version](https://img.shields.io/badge/Versione-1.1.0-orange)](../pubspec.yaml)

---

## 📖 Panoramica

**ME Spoofing** è un motore proxy avanzato nello spazio utente per l'elusione del Deep Packet Inspection (DPI), progettato per **MHPanel**. Fornisce un robusto bypass della censura tramite protocolli di trasporto multilivello — frammentazione TCP, iniezione di SNI esca e fronting IP Anycast di Cloudflare — senza richiedere permessi VPN o privilegi di sistema.

---

## 🏗️ Architettura e Conformità Google Play (Nessun VpnService)

A differenza delle applicazioni VPN convenzionali, **ME Spoofing non registra né utilizza l'API `VpnService` di Android**:

| Proprietà | Dettaglio |
|---|---|
| **Nessun profilo VPN di sistema** | Non altera le tabelle di routing globali del SO né installa interfacce TUN virtuali |
| **Relay locale puro nello spazio utente** | Il motore si lega esclusivamente a `127.0.0.1:<porte>` come inoltro intelligente |
| **100% conforme alle politiche Google Play** | Completamente esente dalle restrizioni di Google Play per le applicazioni VPN |
| **Supporto universale per client** | Compatibile con Happ, v2rayNG, Npv Tunnel, Sing-box, Telegram e browser |

---

## 🚀 Due Modalità di Trasporto

### Modalità 1 — SNI Diretto e Frammentazione TCP (Porta 15443)

Connessione diretta ai nodi edge di MHPanel con:
- **Microfragmentazione di TLS ClientHello** attraverso i confini dei record TCP con ritardi a livello di microsecondi
- **Iniezione di SNI esca** — vengono iniettati nomi di dominio attendibili per ingannare i motori di ispezione DPI
- Ottimale per la maggior parte delle reti dove l'IP principale del server è raggiungibile

### Modalità 2 — Trasporto Cloudflare Clean IP (Porta 443)

Instrada tutto il traffico attraverso **indirizzi IP Anycast Cloudflare** puliti e non bloccati con:
- **Riscrittura dinamica di SNI e frammentazione** per prevenire il filtraggio basato su SNI da parte degli ISP
- **Fronting IP Anycast** — il traffico raggiunge la rete globale di Cloudflare prima di essere inoltrato
- Ottimale quando l'IP principale del server MHPanel è bloccato

---

## ⚡ Funzionalità Principali

### 📊 Log di Connessione in Tempo Reale (Filtrabili)

Visualizzazione log in streaming con quattro schede di filtro:
- **Tutto** — ogni evento del proxy
- **Iniezione Falsa** — eventi di spoofing SNI e iniezione SNI esca
- **Frammento** — eventi di frammentazione TCP
- **Errori** — errori di connessione e avvisi

### 📡 Statistiche di Rete in Tempo Reale

Metriche di rete in tempo reale nella schermata principale:
- **Velocità di download** (live, al secondo)
- **Velocità di upload** (live, al secondo)
- Numero di **connessioni simultanee attive**

### 🔀 Assistente di Routing

Strumento intelligente di conversione della configurazione:
1. Incolla la tua configurazione V2Ray / Xray JSON esistente
2. L'assistente la riscrive per usare `127.0.0.1:<porta>` come upstream
3. Genera una configurazione pronta all'uso **più** regole di routing bypass per il traffico locale
4. Incolla il risultato direttamente in Happ, v2rayNG, Sing-box o Npv Tunnel

### ⏱️ Sistema Timer Intelligente e Premi

- Il timer **conta solo durante la connessione attiva** — si mette in pausa immediatamente alla disconnessione
- Previene il consumo ingiusto di tempo durante le interruzioni di rete
- **Bonus di 4 ore aggiuntive** disponibile guardando annunci pubblicitari

### 🔄 Verifica Aggiornamenti in Tempo Reale

- Controlla GitHub Releases per nuove versioni su richiesta
- Accessibile tramite l'**icona a campana** nell'intestazione dell'app
- Mostra il riepilogo del changelog per gli aggiornamenti disponibili

### 🔧 Gestione Dinamica delle Porte

- Aggiungi, modifica e rimuovi qualsiasi numero di porte di ascolto locali dalle Impostazioni

### 🎨 Tema Scuro / Chiaro

- Segue automaticamente l'impostazione modalità scura/chiara del SO
- Personalizzabile manualmente nelle impostazioni dell'app

### 🌍 Internazionalizzazione in 10 Lingue

Supporto completo RTL e LTR per: **Italiano, Persiano, Inglese, Arabo, Cinese, Russo, Spagnolo, Tedesco, Francese, Hindi**  
Rilevamento automatico della lingua di sistema al primo avvio.

---

## 📱 Guida alla Configurazione

### Passo 1: Installare l'APK

Scarica l'ultimo APK da [GitHub Releases](https://github.com/t-51/snispoof/releases) e installalo.

### Passo 2: Scegliere la Modalità di Trasporto

| Scenario | Modalità Consigliata |
|---|---|
| IP del server raggiungibile | Modalità 1 — Frammentazione SNI |
| IP del server bloccato | Modalità 2 — Cloudflare Clean IP |

### Passo 3: Connettersi

1. Apri l'app e tocca **Connetti**
2. Il proxy sarà disponibile su `127.0.0.1:<porta configurata>`
3. Configura il tuo client preferito (Happ, v2rayNG, ecc.) per utilizzare questo indirizzo proxy

### Passo 4: Usare l'Assistente di Routing (Opzionale)

Se hai già una configurazione V2Ray/Xray:
1. Tocca l'icona **Assistente di Routing** nella schermata principale
2. Incolla il JSON della tua configurazione
3. Copia la configurazione convertita — pronta per l'uso in qualsiasi client supportato

---

## 🛠️ Build e Sviluppo

### Requisiti Prerequisiti

- Flutter SDK `^3.9.0`
- Android SDK (Livello API 24+)

```bash
# Clona il repository
git clone https://github.com/t-51/snispoof.git
cd snispoof

# Installa le dipendenze
flutter pub get

# Esegui la suite di test (12 unit test)
flutter test

# Compila APK di produzione
flutter build apk --release
```

---

## 🔗 Torna al README Principale

[← Torna al README](../README.md)

---

## 📄 Licenza

Questo progetto è licenziato sotto la Licenza MIT — consulta il file [LICENSE](../LICENSE) per i dettagli.
