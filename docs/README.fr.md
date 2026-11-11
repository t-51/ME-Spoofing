# ME Spoofing — Proxy Multi-Transport Anti-DPI pour MHPanel

[![Flutter CI](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)
[![Google Play Compliant](https://img.shields.io/badge/Google%20Play-Exempté%20VPN%20(Proxy%20Espace%20Utilisateur)-brightgreen)](https://developer.android.com/distribute/play-policies)
[![Languages](https://img.shields.io/badge/Langues-10%20Locales-blue)](../lib/l10n/app_localizations.dart)
[![Version](https://img.shields.io/badge/Version-1.1.0-orange)](../pubspec.yaml)

---

## 📖 Présentation

**ME Spoofing** est un moteur de relais proxy en espace utilisateur et de contournement du DPI (Deep Packet Inspection) haute performance conçu pour **MHPanel**. Il offre un contournement robuste de la censure via des protocoles de transport multicouches — fragmentation TCP, injection de SNI leurre et fronting d'adresses IP Anycast Cloudflare — sans nécessiter de permissions VPN ni de privilèges système.

---

## 🏗️ Architecture et Conformité Google Play (Sans VpnService)

Contrairement aux applications VPN conventionnelles, **ME Spoofing n'enregistre pas et n'utilise pas l'API `VpnService` d'Android** :

| Propriété | Détail |
|---|---|
| **Aucun profil VPN système** | Ne modifie pas les tables de routage globales du système d'exploitation et n'installe pas d'interface TUN virtuelle |
| **Relais local pur en espace utilisateur** | Le moteur se lie exclusivement à `127.0.0.1:<ports>` comme transmetteur intelligent |
| **100% conforme aux règles Google Play** | Complètement exempté des restrictions Google Play applicables aux VPN |
| **Compatibilité universelle** | Compatible avec Happ, v2rayNG, Npv Tunnel, Sing-box, Telegram et les navigateurs |

---

## 🚀 Deux Modes de Transport

### Mode 1 — SNI Direct et Fragmentation TCP (Port 15443)

Connexion directe aux nœuds edge de MHPanel avec :
- **Microfragmentation de TLS ClientHello** à travers les limites des enregistrements TCP avec des délais à l'échelle de la microseconde
- **Injection de SNI leurre** — des noms de domaine de confiance sont injectés pour tromper les moteurs d'inspection DPI
- Optimal pour la plupart des réseaux où l'adresse IP principale du serveur est accessible

### Mode 2 — Transport Cloudflare Clean IP (Port 443)

Achemine tout le trafic via des **adresses IP Anycast Cloudflare** propres et non bloquées avec :
- **Réécriture dynamique du SNI et fragmentation** pour prévenir le filtrage basé sur SNI des FAI
- **Fronting IP Anycast** — le trafic atteint le réseau mondial Cloudflare avant d'être transmis
- Optimal lorsque l'adresse IP principale du serveur MHPanel est bloquée

---

## ⚡ Fonctionnalités Clés

### 📊 Journaux de Connexion en Direct (Filtrables)

Vue de journaux en streaming en temps réel avec quatre onglets de filtrage :
- **Tout** — chaque événement du proxy
- **Injection Fausse** — événements d'usurpation SNI et d'injection SNI leurre
- **Fragment** — événements de fragmentation TCP
- **Erreurs** — erreurs de connexion et avertissements

### 📡 Statistiques Réseau en Temps Réel

Métriques réseau en temps réel sur l'écran principal :
- **Vitesse de téléchargement** (en direct, par seconde)
- **Vitesse d'envoi** (en direct, par seconde)
- Nombre de **connexions simultanées actives**

### 🔀 Assistant de Routage

Outil intelligent de conversion de configuration :
1. Collez votre configuration V2Ray / Xray JSON existante
2. L'assistant la réécrit pour utiliser `127.0.0.1:<port>` comme upstream
3. Génère une configuration prête à l'emploi **plus** des règles de routage bypass pour le trafic local
4. Collez le résultat directement dans Happ, v2rayNG, Sing-box ou Npv Tunnel

### ⏱️ Système de Minuterie Intelligente et Récompenses

- La minuterie **ne décompte que lors d'une connexion active** — se met en pause immédiatement à la déconnexion
- Prévient la consommation injuste de temps pendant les interruptions réseau
- **Bonus de 4 heures supplémentaires** disponible en regardant des publicités

### 🔄 Vérificateur de Mises à Jour en Direct

- Vérifie les GitHub Releases pour de nouvelles versions à la demande
- Accessible via l'**icône cloche** dans l'en-tête de l'application
- Affiche le résumé du changelog pour les mises à jour disponibles

### 🔧 Gestion Dynamique des Ports

- Ajoutez, modifiez et supprimez n'importe quel nombre de ports d'écoute locaux depuis les Paramètres

### 🎨 Thème Sombre / Clair

- Suit automatiquement le paramètre mode sombre/clair du système d'exploitation
- Personnalisable manuellement dans les paramètres de l'application

### 🌍 Internationalisation en 10 Langues

Support complet RTL et LTR pour : **Français, Persan, Anglais, Arabe, Chinois, Russe, Espagnol, Italien, Allemand, Hindi**  
Détection automatique de la langue système au premier lancement.

---

## 📱 Guide de Configuration

### Étape 1 : Installer l'APK

Téléchargez le dernier APK depuis [GitHub Releases](https://github.com/t-51/snispoof/releases) et installez-le.

### Étape 2 : Choisir le Mode de Transport

| Scénario | Mode Recommandé |
|---|---|
| IP du serveur accessible | Mode 1 — Fragmentation SNI |
| IP du serveur bloquée | Mode 2 — Cloudflare Clean IP |

### Étape 3 : Se Connecter

1. Ouvrez l'application et appuyez sur **Connecter**
2. Le proxy sera disponible sur `127.0.0.1:<port configuré>`
3. Configurez votre client préféré (Happ, v2rayNG, etc.) pour utiliser cette adresse proxy

### Étape 4 : Utiliser l'Assistant de Routage (Optionnel)

Si vous avez déjà une configuration V2Ray/Xray :
1. Appuyez sur l'icône **Assistant de Routage** sur l'écran principal
2. Collez le JSON de votre configuration
3. Copiez la configuration convertie — prête à l'emploi dans tout client supporté

---

## 🛠️ Build et Développement

### Prérequis

- Flutter SDK `^3.9.0`
- Android SDK (Niveau API 24+)

```bash
# Cloner le dépôt
git clone https://github.com/t-51/snispoof.git
cd snispoof

# Installer les dépendances
flutter pub get

# Exécuter la suite de tests (12 tests unitaires)
flutter test

# Compiler l'APK de production
flutter build apk --release
```

---

## 🔗 Retour au README Principal

[← Retour au README](../README.md)

---

## 📄 Licence

Ce projet est licencié sous la Licence MIT — consultez le fichier [LICENSE](../LICENSE) pour les détails.
