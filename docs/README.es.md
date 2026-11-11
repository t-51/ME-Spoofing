# ME Spoofing — Proxy Multi-Transporte Anti-DPI para MHPanel

[![Flutter CI](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)
[![Google Play Compliant](https://img.shields.io/badge/Google%20Play-Exento%20de%20VPN%20(Proxy%20Espacio%20Usuario)-brightgreen)](https://developer.android.com/distribute/play-policies)
[![Languages](https://img.shields.io/badge/Idiomas-10%20Locales-blue)](../lib/l10n/app_localizations.dart)
[![Version](https://img.shields.io/badge/Versión-1.1.0-orange)](../pubspec.yaml)

---

## 📖 Descripción General

**ME Spoofing** es un motor de retransmisión proxy en espacio de usuario y evasión de DPI de alto rendimiento diseñado para **MHPanel**. Ofrece elusión robusta de censura mediante protocolos de transporte multicapa — fragmentación TCP, inyección de SNI señuelo y fronting de IP Anycast de Cloudflare — sin requerir permisos VPN ni privilegios del sistema.

---

## 🏗️ Arquitectura y Cumplimiento de Google Play (Sin VpnService)

A diferencia de las aplicaciones VPN convencionales, **ME Spoofing no utiliza la API `VpnService` de Android**:

| Propiedad | Detalle |
|---|---|
| **Sin perfil VPN del sistema** | No altera las tablas de enrutamiento globales del SO ni instala interfaces TUN virtuales |
| **Retransmisor local en espacio de usuario** | El motor se enlaza exclusivamente a `127.0.0.1:<puertos>` como reenviador inteligente |
| **100% conforme con Google Play** | Completamente exento de las restricciones de Google Play para aplicaciones VPN |
| **Compatibilidad universal** | Compatible con Happ, v2rayNG, Npv Tunnel, Sing-box, Telegram y navegadores |

---

## 🚀 Dos Modos de Transporte

### Modo 1 — SNI Directo y Fragmentación TCP (Puerto 15443)

Conexión directa a nodos edge de MHPanel con:
- **Microfragmentación de TLS ClientHello** a través de límites de registros TCP con retrasos a nivel de microsegundos
- **Inyección de SNI señuelo** — se inyectan nombres de dominio de confianza para engañar a los motores de inspección DPI
- Óptimo para la mayoría de redes donde la IP del servidor principal es accesible

### Modo 2 — Transporte Cloudflare Clean IP (Puerto 443)

Enruta todo el tráfico a través de **direcciones IP Anycast de Cloudflare** limpias y no bloqueadas con:
- **Reescritura dinámica de SNI y fragmentación** para prevenir el filtrado basado en SNI de los ISP
- **Fronting de IP Anycast** — el tráfico llega a la red global de Cloudflare antes de ser reenviado
- Óptimo cuando la IP principal del servidor MHPanel está bloqueada

---

## ⚡ Características Principales

### 📊 Registros de Conexión en Vivo (Filtrables)

Vista de registros en tiempo real con cuatro pestañas de filtrado:
- **Todo** — cada evento del proxy
- **Inyección Falsa** — eventos de suplantación de SNI e inyección señuelo
- **Fragmento** — eventos de fragmentación TCP
- **Errores** — errores de conexión y advertencias

### 📡 Estadísticas de Red en Tiempo Real

Métricas de red en tiempo real en la pantalla principal:
- **Velocidad de descarga** (en vivo, por segundo)
- **Velocidad de carga** (en vivo, por segundo)
- Número de **conexiones simultáneas activas**

### 🔀 Asistente de Enrutamiento

Herramienta inteligente de conversión de configuración:
1. Pega tu configuración V2Ray / Xray JSON existente
2. El asistente la reescribe para usar `127.0.0.1:<puerto>` como upstream
3. Genera una configuración lista para usar **más** reglas de enrutamiento bypass para tráfico local
4. Pega el resultado directamente en Happ, v2rayNG, Sing-box o Npv Tunnel

### ⏱️ Sistema Inteligente de Tiempo y Recompensas

- El temporizador **solo cuenta mientras está activamente conectado** — se pausa inmediatamente al desconectarse
- Previene el consumo injusto de tiempo durante interrupciones de red
- **Recompensa de 4 horas adicionales** disponible viendo anuncios

### 🔄 Verificador de Actualizaciones en Vivo

- Comprueba GitHub Releases para nuevas versiones bajo demanda
- Accesible mediante el **ícono de campana** en el encabezado de la app
- Muestra el resumen del changelog para las actualizaciones disponibles

### 🔧 Gestión Dinámica de Puertos

- Agrega, edita y elimina cualquier número de puertos de escucha locales desde los Ajustes

### 🎨 Tema Oscuro / Claro

- Sigue automáticamente la configuración de modo oscuro/claro del SO
- Personalizable manualmente en los ajustes de la app

### 🌍 Internacionalización en 10 Idiomas

Soporte completo RTL y LTR para: **Español, Persa, Inglés, Árabe, Chino, Ruso, Italiano, Alemán, Francés, Hindi**  
Detección automática del idioma del sistema en el primer inicio.

---

## 📱 Guía de Configuración

### Paso 1: Instalar el APK

Descarga el último APK de [GitHub Releases](https://github.com/t-51/snispoof/releases) e instálalo.

### Paso 2: Elegir el Modo de Transporte

| Escenario | Modo Recomendado |
|---|---|
| IP del servidor accesible | Modo 1 — Fragmentación SNI |
| IP del servidor bloqueada | Modo 2 — Cloudflare Clean IP |

### Paso 3: Conectarse

1. Abre la app y toca **Conectar**
2. El proxy estará disponible en `127.0.0.1:<puerto configurado>`
3. Configura tu cliente favorito (Happ, v2rayNG, etc.) para usar esta dirección proxy

### Paso 4: Usar el Asistente de Enrutamiento (Opcional)

Si ya tienes una configuración V2Ray/Xray:
1. Toca el ícono del **Asistente de Enrutamiento** en la pantalla principal
2. Pega el JSON de tu configuración
3. Copia la configuración convertida — lista para usar en cualquier cliente compatible

---

## 🛠️ Compilación y Desarrollo

### Requisitos Previos

- Flutter SDK `^3.9.0`
- Android SDK (Nivel API 24+)

```bash
# Clonar el repositorio
git clone https://github.com/t-51/snispoof.git
cd snispoof

# Instalar dependencias
flutter pub get

# Ejecutar la suite de pruebas (12 pruebas unitarias)
flutter test

# Compilar APK de producción
flutter build apk --release
```

---

## 🔗 Volver al README Principal

[← Volver al README](../README.md)

---

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT — consulta el archivo [LICENSE](../LICENSE) para más detalles.
