# ME Spoofing — MHPanel Anti-DPI & Multi-Transport Proxy

[![Flutter CI](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Google Play Compliant](https://img.shields.io/badge/Google%20Play-VPN%20Exempt%20(Userspace%20Proxy)-brightgreen)](https://developer.android.com/distribute/play-policies)
[![Languages](https://img.shields.io/badge/Languages-10%20Locales-blue)](lib/l10n/app_localizations.dart)
[![Version](https://img.shields.io/badge/Version-1.1.0-orange)](pubspec.yaml)

---

### 🌐 Select Language / انتخاب زبان / اختر اللغة / 选择语言 / Выберите язык / Seleccionar idioma / Seleziona lingua / Sprache wählen / Choisir la langue / भाषा चुनें

[🇮🇷 فارسی](#-فارسی) • [🇺🇸 English](#-english) • [🇸🇦 العربية](#-العربية) • [🇨🇳 简体中文](#-简体中文) • [🇷🇺 Русский](#-русский) • [🇪🇸 Español](#-español) • [🇮🇹 Italiano](#-italiano) • [🇩🇪 Deutsch](#-deutsch) • [🇫🇷 Français](#-français) • [🇮🇳 हिन्दी](#-हिन्दी)

---

<div dir="rtl">

## 🇮🇷 فارسی

**ME Spoofing** یک موتور پروکسی لوکال و دورزننده پیشرفته سیستم‌های فیلترینگ و بازرسی عمیق بسته‌ها (DPI) است که بر اساس استانداردهای **MHPanel** طراحی شده است. این ابزار با استفاده از چند لایه پروتکل‌های انتقال، قطعه‌بندی ترافیک TCP (فراگمنتیشن)، تزریق SNI جعلی و مخفی، تونل‌های DNS و استفاده از آی‌پی‌های تمیز کلادفلر، ارتباطی امن، پایدار و پرسرعت را بدون قطعی فراهم می‌سازد.

### 🛡️ سازگاری کامل با سیاست‌های گوگل‌پلی (بدون VpnService)
برخلاف وی‌پی‌ان‌های مرسوم، این برنامه از سرویس `VpnService` سیستم‌عامل اندروید استفاده نمی‌کند:
* **بدون ساخت پروفایل VPN سیستم:** جدول روتینگ کل سیستم تغییر نکرده و هیچ رابط مجازی TUN نصب نمی‌شود.
* **پروکسی فضای کاربری (Userspace Relay):** برنامه به عنوان یک پروکسی فورواردر روی آدرس‌های لوکال (`127.0.0.1:<ports>`) اجرا می‌شود.
* **سازگاری ۱۰۰٪ با قوانین انتشار:** به دلیل عدم ادعای کارکرد به عنوان VPN، مشمول محدودیت‌ها و سخت‌گیری‌های گوگل‌پلی نمی‌شود.
* **سازگاری عمومی با کلاینت‌ها:** با تمامی نرم‌افزارهای پراکسی مانند Happ، v2rayNG، Npv Tunnel، Sing-box و تلگرام کار می‌کند.

### 🚀 ۳ حالت انتقال داده (Multi-Transport Modes)
1. **حالت ۱ - مستقیم با فراگمنتیشن SNI (پورت 15443):**
   * اتصال مستقیم به سرورهای لبه پنل با فرگمنت بسته TLS ClientHello در سطح رکورد و تاخیرهای میکروثانیه‌ای.
   * تزریق دامنه‌های SNI جعلی مورد تایید جهت فریب رادارهای DPI.
2. **حالت ۲ - انتقال از طریق آی‌پی تمیز کلادفلر (پورت 443):**
   * عبور ترافیک از شبکه Anycast کلادفلر با آی‌پی‌های تمیز و بازنویسی داینامیک SNI.
   * مناسب شرایطی که آی‌پی سرور اصلی فیلتر شده است.
3. **حالت ۳ - تونل DNS (شامل VayDNS، DNSTT، Slipstream):**
   * کپسوله‌سازی ترافیک درون درخواست‌های DNS (روی پروتکل‌های DoH، DoT، TCP یا UDP) با پشتیبانی همزمان از چند ریزالور و سنجش زنده تاخیر (Ping).

### ⚡ ویژگی‌های کلیدی
* **تولید خودکار پروفایل روتینگ:** ایجاد رول‌های روتینگ اختصاصی برای نرم‌افزارهای محبوب (Happ, v2rayNG, Sing-box, Npv Tunnel) تنها با یک کلیک.
* **مدیریت پورت‌های داینامیک:** امکان افزودن، ویرایش و مدیریت تعداد دلخواه پورت لوکال در بخش تنظیمات.
* **سیستم زمان‌بندی هوشمند:** محاسبه زمان فقط هنگام اتصال، توقف کامل مصرف زمان پس از قطع اتصال و قابلیت دریافت ۴ ساعت پاداش.
* **پشتیبانی از ۱۰ زبان زنده دنیا:** فارسی، انگلیسی، عربی، چینی، روسی، اسپانیایی، ایتالیایی، آلمانی، فرانسوی و هندی با شناسایی خودکار زبان سیستم.
* **هماهنگی تم:** تغییر خودکار یا دستی تم بین حالت روشن و تاریک منطبق با سیستم عامل.
* **اطلاع‌رسانی بروزرسانی:** بررسی لحظه‌ای نسخه‌های جدید از روی گیت‌هاب از طریق زنگوله بالای صفحه.

---

</div>

## 🇺🇸 English

**ME Spoofing** is an advanced, high-performance userspace proxy relay and DPI-circumvention engine developed for **MHPanel**. It provides robust censorship bypass using multi-layered transport protocols, TCP fragmentation, decoy SNI injection, Cloudflare Clean IP fronting, and userspace DNS tunneling.

### 🛡️ Architecture & Google Play Compliance (No VpnService)
Unlike conventional VPN applications, **ME Spoofing does not register or use Android's `VpnService` API**:
* **No System VPN Profile:** The application does not alter the operating system's global network routing tables, install TUN virtual interfaces, or request VPN permissions.
* **Pure Userspace Local Relay:** The engine binds exclusively to local loopback addresses (`127.0.0.1:<ports>`), acting as an intelligent intermediate forwarder.
* **100% Google Play Policy Compliant:** Because the app operates strictly as a local proxy forwarder, it is completely exempt from Google Play Store restrictions on VPN applications.
* **Universal Client Support:** Compatible with any application supporting socks5, http, or local TCP listening (e.g., **Happ**, **v2rayNG**, **Npv Tunnel**, **Sing-box**, Telegram proxy, and web browsers).

### 🚀 Three Multi-Transport Modes
1. **Mode 1: Direct SNI & TCP Fragmentation (Port 15443):**
   * Direct connection to MHPanel edge nodes over port `15443`.
   * Real-time TCP segmentation of the TLS ClientHello across record boundaries with microsecond delays.
   * Decoy fake SNI injection to bypass Deep Packet Inspection (DPI) firewalls.
2. **Mode 2: Cloudflare Clean IP Transport (Port 443):**
   * Routes traffic through verified, unblocked Cloudflare Anycast IP addresses.
   * Dynamic SNI rewriting and fragmentation prevents SNI-based filtering on ISP networks.
3. **Mode 3: DNS Tunnel Transport (VayDNS, DNSTT, Slipstream, NoizDNS):**
   * Encapsulates connection streams into DNS requests (via UDP 53, TCP 53, DoH 443, or DoT 853) with multi-resolver fallback and live ping latency telemetry.

### ⚡ Key Features
* **One-Click Client Routing Profiles:** Generate optimized routing rules for Happ, v2rayNG, Sing-box, and Npv Tunnel instantly.
* **Dynamic Port Management:** Add, remove, and manage any number of custom listener ports on the fly.
* **Smart Allowance System:** Timer only decrements while connected. Disconnecting immediately stops consumption. Optional 4-hour reward system.
* **10-Language Internationalization:** Full support for Persian, English, Arabic, Chinese, Russian, Spanish, Italian, German, French, and Hindi with RTL/LTR layouts.
* **Theme Synchronization:** Seamless dark/light theme switching following the OS or customized in settings.
* **Live Update Checker:** In-app GitHub release notifications via the header bell icon.

---

<div dir="rtl">

## 🇸🇦 العربية

**ME Spoofing** هو محرك بروكسي متطور ومحلي لتجاوز تقنيات الفحص العميق للحزم (DPI) تم تطويره لصالح **MHPanel**. يوفر تجاوزاً قوياً للحجب عبر بروتوكولات نقل متعددة الطبقات، وتجزئة حزم TCP، وحقن عناوين SNI مموهة، واستخدام عناوين IP نظيفة من Cloudflare، والأنفاق عبر بروتوكول DNS.

### 🛡️ التوافق التام مع سياسات Google Play (بدون VpnService)
على عكس تطبيقات VPN التقليدية، **لا يستخدم ME Spoofing خدمة `VpnService` الخاصة بنظام أندرويد**:
* **بدون إنشاء ملف VPN على النظام:** لا يغير التطبيق جداول التوجيه العامة للنظام، ولا يقوم بتثبيت واجهات TUN افتراضية.
* **بروكسي محلي في مساحة المستخدم:** يرتبط التطبيق حصرياً بعناوين الاسترجاع المحلي (`127.0.0.1:<ports>`).
* **متوافق بنسبة 100% مع متجر Google Play:** لكونه بروكسي محلي وليس نفقاً على مستوى النظام، فهو معفى من قيود Google Play الخاصة بتطبيقات VPN.
* **دعم شامل للتطبيقات:** يتكامل بسلاسة مع Happ و v2rayNG و Sing-box و Npv Tunnel وتليجرام ومتصفحات الإنترنت.

### 🚀 أوضاع النقل الثلاثة (Multi-Transport)
1. **الوضع 1 - مباشر مع تجزئة SNI (المنفذ 15443):** اتصال مباشر مع خوادم MHPanel وتجزئة حزم TLS ClientHello مع تأخيرات زمنية وحقن SNI مموه.
2. **الوضع 2 - وسيط Cloudflare Clean IP (المنفذ 443):** توجيه البيانات عبر عناوين Cloudflare Anycast النظيفة غير المحجوبة مع إعادة كتابة SNI بشكل ديناميكي.
3. **الوضع 3 - نفق DNS (تشمل VayDNS و DNSTT و Slipstream):** تغليف حركة البيانات داخل استعلامات DNS (عبر UDP أو TCP أو DoH أو DoT 853) مع دعم المحللات المتعددة والقياس اللحظي للاستجابة.

### ⚡ الميزات الرئيسية
* **إنشاء ملفات التوجيه بنقرة واحدة:** إنشاء قواعد التوجيه التلقائية لتطبيقات Happ و v2rayNG و Sing-box و Npv Tunnel.
* **إدارة المنافذ ديناميكياً:** إضافة وتعديل منافذ الاستماع المحلية دون قيود ثابتة.
* **نظام ذكي للوقت:** استهلاك الوقت يتوقف فور قطع الاتصال، مع إمكانية الحصول على مكافأة 4 ساعات إضافية.
* **دعم 10 لغات:** دعم كامل للغة العربية والفارسية والإنجليزية والصينية والروسية والإسبانية والإيطالية والألمانية والفرنسية والهندية.
* **مزامنة المظهر:** دعم الوضع الداكن والفاتح تلقائياً أو يدوياً عبر الإعدادات.

---

</div>

## 🇨🇳 简体中文

**ME Spoofing** 是一款为 **MHPanel** 打造的高性能用户态代理中继与 DPI 审查规避引擎。它结合了多层传输协议、TCP 分片、伪装 SNI 注入、Cloudflare Clean IP 前置以及用户态 DNS 隧道技术，提供高速、稳定、安全的抗封锁网络连接。

### 🛡️ 架构与 Google Play 政策合规（无 VpnService）
与传统 VPN 应用不同，**ME Spoofing 不注册也不使用 Android 的 `VpnService` API**：
* **不创建系统级 VPN 配置文件：** 应用不修改操作系统的全局路由表，不安装虚拟 TUN 接口，亦无需任何系统 VPN 权限。
* **纯用户态本地转发：** 核心引擎仅绑定到本地环回地址（`127.0.0.1:<端口>`），作为智能的中间转发器运行。
* **100% 符合 Google Play 政策：** 由于其作为本地用户空间代理运行而非系统网络隧道，因此完全免受 Google Play 对 VPN 服务的严苛限制。
* **广泛的客户端兼容性：** 可与任何支持 socks5、http 或本地 TCP 代理的应用配合使用（如 **Happ**、**v2rayNG**、**Sing-box**、**Npv Tunnel**、Telegram 等）。

### 🚀 三大传输模式
1. **模式 1：直连 SNI 与 TCP 分片（端口 15443）：**
   * 直连 MHPanel 边缘节点，在 TLS ClientHello 阶段跨记录边界执行微秒级分片。
   * 注入伪装 SNI 域名，有效迷惑深度数据包检测（DPI）防火墙。
2. **模式 2：Cloudflare Clean IP 传输（端口 443）：**
   * 通过已验证的未封锁 Cloudflare Anycast IP 进行流量传输。
   * 动态重写 SNI 配合分片，防御运营商基于 SNI 的拦截。
3. **模式 3：DNS 隧道传输（VayDNS、DNSTT、Slipstream）：**
   * 支持 UDP 53、TCP 53、DoH 443 与 DoT 853 四大传输协议，具备多解析器并发容灾与实时 Ping 延迟遥测。

### ⚡ 核心功能
* **一键生成客户端路由规则：** 自动为 Happ、v2rayNG、Sing-box 和 Npv Tunnel 生成优化的路由配置规则。
* **动态端口管理：** 在设置中自由添加、修改和删除本地监听端口。
* **智能计时与时长系统：** 仅在连接时消耗使用时间，断开连接立即暂停倒计时，并支持 4 小时激励时长。
* **支持 10 种国际语言：** 完整支持中文、波斯语、英语、阿拉伯语、俄语、西班牙语、意大利语、德语、法语和印地语。
* **深浅主题同步：** 完美跟随系统深色/浅色模式或自定义切换。
* **在线更新检测：** 顶部铃铛图标实时检查 GitHub Release 最新版本与更新日志。

---

## 🇷🇺 Русский

**ME Spoofing** — это высокопроизводительный локальный прокси-движок и инструмент обхода систем глубокой инспекции пакетов (DPI), разработанный для **MHPanel**. Приложение обеспечивает устойчивый обход блокировок благодаря фрагментации TCP, внедрению поддельных SNI, использованию чистых IP-адресов Cloudflare (Clean IP) и DNS-туннелированию в пространстве пользователя.

### 🛡️ Полное соответствие правилам Google Play (Без VpnService)
В отличие от классических VPN-приложений, **ME Spoofing не использует API `VpnService` Android**:
* **Без создания системного VPN-профиля:** Программа не изменяет глобальные таблицы маршрутизации ОС и не устанавливает виртуальный интерфейс TUN.
* **Локальный прокси в пространстве пользователя:** Движок слушает исключительно локальные адреса (`127.0.0.1:<порты>`), выступая промежуточным шлюзом.
* **100% соответствие правилам Google Play:** Так как приложение является локальным ретранслятором, оно полностью свободно от ограничений Google Play для VPN.
* **Универсальная поддержка клиентов:** Совместимо с Happ, v2rayNG, Sing-box, Npv Tunnel, Telegram и любыми веб-браузерами.

### 🚀 Три режима передачи данных
1. **Режим 1: Прямое подключение и фрагментация SNI (Порт 15443):**
   * Прямое соединение с серверами MHPanel с микросекундной фрагментацией заголовка TLS ClientHello.
   * Подмена доменов SNI на доверенные для обхода систем DPI.
2. **Режим 2: Транспорт Cloudflare Clean IP (Порт 443):**
   * Маршрутизация через белые Anycast IP Cloudflare с динамической перезаписью SNI.
3. **Режим 3: DNS-туннель (VayDNS, DNSTT, Slipstream):**
   * Инкапсуляция трафика в DNS-запросы (UDP 53, TCP 53, DoH 443 или DoT 853) с поддержкой нескольких резолверов и живым мониторингом пинга.

### ⚡ Ключевые возможности
* **Генератор профилей маршрутизации в один клик:** Мгновенное создание правил обхода для Happ, v2rayNG, Sing-box и Npv Tunnel.
* **Динамическое управление портами:** Добавление и удаление локальных портов прослушивания в настройках.
* **Умная система времени:** Время расходуется только при активном подключении. Начисление бонусных 4 часов.
* **Поддержка 10 языков:** Русский, фарси, английский, арабский, китайский, испанский, итальянский, немецкий, французский и хинди.
* **Синхронизация темы:** Автоматическое переключение светлой и темной темы в соответствии с ОС.

---

## 🇪🇸 Español

**ME Spoofing** es un motor de retransmisión proxy en espacio de usuario y evasión de DPI de alto rendimiento diseñado para **MHPanel**. Ofrece elusión de censura mediante protocolos de transporte multicapa, fragmentación TCP, inyección de SNI señuelo, IP limpias de Cloudflare y túneles DNS en espacio de usuario.

### 🛡️ Cumplimiento total de Google Play (Sin VpnService)
A diferencia de las aplicaciones VPN convencionales, **ME Spoofing no utiliza la API `VpnService` de Android**:
* **Sin perfil VPN del sistema:** No altera la tabla de enrutamiento global ni instala interfaces TUN virtuales.
* **Retransmisor local en espacio de usuario:** Se ejecuta exclusivamente en direcciones de loopback local (`127.0.0.1:<puertos>`).
* **100% conforme con Google Play:** Exento de las restricciones para servicios VPN al ser un proxy local.
* **Compatibilidad universal:** Funciona con Happ, v2rayNG, Sing-box, Npv Tunnel, Telegram y navegadores web.

### 🚀 Tres modos de transporte
1. **Modo 1: SNI directo y fragmentación TCP (Puerto 15443):** Conexión directa con fragmentación de TLS ClientHello e inyección de SNI falso.
2. **Modo 2: Transporte Cloudflare Clean IP (Puerto 443):** Tráfico a través de IPs Anycast de Cloudflare con reescritura dinámica de SNI.
3. **Modo 3: Túnel DNS (VayDNS, DNSTT, Slipstream):** Encapsulación de flujos de datos en consultas DNS (DoH, DoT 853, TCP 53 o UDP 53) con soporte multi-resolver y telemetría de latencia en vivo.

### ⚡ Características principales
* **Perfiles de enrutamiento con un solo clic:** Reglas optimizadas automáticas para Happ, v2rayNG, Sing-box y Npv Tunnel.
* **Gestión dinámica de puertos:** Adición y configuración flexible de puertos locales.
* **Gestión inteligente del tiempo:** El contador solo disminuye durante la conexión activa; recompensa opcional de 4 horas.
* **Soporte para 10 idiomas:** Español, persa, inglés, árabe, chino, ruso, italiano, alemán, francés e hindi.
* **Temas Claro y Oscuro:** Sincronización completa con el sistema o selección manual.

---

## 🇮🇹 Italiano

**ME Spoofing** è un motore proxy avanzato nello spazio utente ed elusione DPI progettato per **MHPanel**. Consente di superare la censura online tramite protocolli di trasporto multilivello, frammentazione TCP, iniezione di SNI esca, IP puliti di Cloudflare e tunneling DNS.

### 🛡️ Conformità con Google Play (Nessun VpnService)
* **Nessun profilo VPN di sistema:** Non modifica le tabelle di routing di sistema e non richiede permessi VPN.
* **Proxy locale in spazio utente:** Ascolta unicamente sulle porte loopback locali (`127.0.0.1:<porte>`).
* **Conformità al 100%:** Pienamente conforme ai criteri di Google Play Store per i proxy locali.
* **Supporto universale per client:** Compatibile con Happ, v2rayNG, Sing-box, Npv Tunnel e Telegram.

### 🚀 Tre modalità di trasporto
1. **Modalità 1: SNI diretto e frammentazione TCP (Porta 15443):** Frammentazione del TLS ClientHello e SNI esca.
2. **Modalità 2: Cloudflare Clean IP (Porta 443):** Instradamento tramite IP Anycast Cloudflare e riscrittura dinamica dell'SNI.
3. **Modalità 3: Tunnel DNS (VayDNS, DNSTT, Slipstream):** Incapsulamento del traffico in query DNS (DoH, DoT 853, TCP 53 o UDP 53) con failover multi-resolver e latenza in tempo reale.

### ⚡ Funzionalità principali
* **Profili di routing in un clic:** Generazione automatica delle regole di routing per Happ, v2rayNG, Sing-box e Npv Tunnel.
* **Gestione dinamica delle porte:** Aggiungi e rimuovi porte di ascolto locali in qualsiasi momento.
* **Sistema a tempo intelligente:** Il tempo si consuma solo durante la connessione.
* **Localizzazione in 10 lingue:** Italiano, persiano, inglese, arabo, cinese, russo, spagnolo, tedesco, francese e hindi.

---

## 🇩🇪 Deutsch

**ME Spoofing** ist eine leistungsstarke Userspace-Proxy-Engine und Anti-DPI-Lösung für **MHPanel**. Sie bietet robuste Zensurumgehung durch mehrschichtige Übertragungsprotokolle, TCP-Fragmentierung, SNI-Täuschung, Cloudflare Clean IP-Fronting und Userspace-DNS-Tunnel.

### 🛡️ Google Play-Konformität (Kein VpnService)
* **Kein System-VPN-Profil:** Modifiziert keine systemweiten Routing-Tabellen und installiert keine virtuellen TUN-Schnittstellen.
* **Reiner Userspace-Proxy:** Bindet ausschließlich an lokale Loopback-Adressen (`127.0.0.1:<Ports>`).
* **100% richtlinienkonform:** Da es sich um einen lokalen Proxy handelt, greifen keine VPN-Einschränkungen des Google Play Stores.
* **Universelle Client-Kompatibilität:** Unterstützt Happ, v2rayNG, Sing-box, Npv Tunnel, Telegram und Browser.

### 🚀 Drei Transport-Modi
1. **Modus 1: Direktes SNI & TCP-Fragmentierung (Port 15443):** TLS ClientHello-Segmentierung und Fake-SNI-Injektion.
2. **Modus 2: Cloudflare Clean IP (Port 443):** Routing über saubere Cloudflare Anycast-IPs mit SNI-Umschreibung.
3. **Modus 3: DNS-Tunnel (VayDNS, DNSTT, Slipstream):** Kapselung in DNS-Anfragen (DoH, DoT 853, TCP 53 oder UDP 53) mit Multi-Resolver-Ausfallsicherung und Live-Ping-Telemetrie.

### ⚡ Hauptmerkmale
* **1-Klick Client-Routing-Profile:** Erstellt Routing-Regeln für Happ, v2rayNG, Sing-box und Npv Tunnel mit einem Fingertipp.
* **Dynamische Portverwaltung:** Beliebige Listener-Ports in den Einstellungen hinzufügen und anpassen.
* **Intelligentes Zeitsystem:** Zeitzählung pausiert sofort beim Trennen der Verbindung.
* **10 Sprachen:** Deutsch, Persisch, Englisch, Arabisch, Chinesisch, Russisch, Spanisch, Italienisch, Französisch und Hindi.

---

## 🇫🇷 Français

**ME Spoofing** est un moteur de relais proxy en espace utilisateur et de contournement du DPI haute performance conçu pour **MHPanel**. Il offre un contournement efficace de la censure via des protocoles multicouches, la fragmentation TCP, l'injection de SNI leurre, les adresses IP propres Cloudflare et le tunneling DNS en espace utilisateur.

### 🛡️ Conformité Google Play (Sans VpnService)
* **Aucun profil VPN système :** Ne modifie pas la table de routage globale et n'installe pas d'interface virtuelle TUN.
* **Relais local en espace utilisateur :** Écoute uniquement sur les adresses loopback locales (`127.0.0.1:<ports>`).
* **100% conforme aux règles Google Play :** Exempt des restrictions imposées aux applications VPN.
* **Compatibilité universelle :** Fonctionne avec Happ, v2rayNG, Sing-box, Npv Tunnel, Telegram et les navigateurs.

### 🚀 Trois modes de transport
1. **Mode 1 : SNI direct et fragmentation TCP (Port 15443) :** Segmentation de TLS ClientHello et injection de SNI leurre.
2. **Mode 2 : Transport Cloudflare Clean IP (Port 443) :** Routage via les adresses IP Anycast propres de Cloudflare.
3. **Mode 3 : Tunnel DNS (VayDNS, DNSTT, Slipstream) :** Encapsulation du trafic dans des requêtes DNS (DoH, DoT 853, TCP 53 ou UDP 53) avec basculement multi-résolveurs et télémétrie de ping en direct.

### ⚡ Fonctionnalités clés
* **Profils de routage en un clic :** Règles de routage instantanées pour Happ, v2rayNG, Sing-box et Npv Tunnel.
* **Gestion dynamique des ports :** Ajoutez et configurez vos ports d'écoute locaux librement.
* **Gestion intelligente du temps :** Consommation arrêtée lors de la déconnexion.
* **Traduction en 10 langues :** Français, persan, anglais, arabe, chinois, russe, espagnol, italien, allemand et hindi.

---

## 🇮🇳 हिन्दी

**ME Spoofing** एक उन्नत और उच्च-प्रदर्शन यूजरस्पेस प्रॉक्सी और डीपीआई (DPI) बाईपास इंजन है जिसे **MHPanel** के लिए विकसित किया गया है। यह टीसीपी फ्रैग्मेंटेशन (TCP Fragmentation), नकली एसएनआई (Decoy SNI), क्लाउडफ्लेयर क्लीन आईपी और डीएनएस टनलिंग तकनीकों का उपयोग करके इंटरनेट प्रतिबंधों को सुरक्षित रूप से बायपास करता है।

### 🛡️ गूगल प्ले नीतियों के पूर्णतः अनुरूप (बिना VpnService)
* **कोई सिस्टम वीपीएन प्रोफ़ाइल नहीं:** यह डिवाइस की वैश्विक रूटिंग टेबल को नहीं बदलता और न ही कोई TUN वर्चुअल इंटरफ़ेस बनाता है।
* **लोकल यूजरस्पेस रिले:** इंजन केवल लोकल लूपबैक पतों (`127.0.0.1:<ports>`) पर काम करता है।
* **100% प्ले स्टोर अनुपालन:** चूंकि यह एक लोकल प्रॉक्सी है, इसलिए यह वीपीएन प्रतिबंधों से मुक्त है।
* **यूनिवर्सल क्लाइंट सपोर्ट:** Happ, v2rayNG, Sing-box, Npv Tunnel और टेलीग्राम के साथ सहजता से काम करता है।

### 🚀 तीन मल्टी-ट्रांसपोर्ट मोड्स
1. **मोड 1 - डायरेक्ट एसएनआई और टीसीपी फ्रैग्मेंटेशन (पोर्ट 15443):** TLS ClientHello का माइक्रोसेकंड फ्रैग्मेंटेशन और नकली SNI इंजेक्शन।
2. **मोड 2 - क्लाउडफ्लेयर क्लीन आईपी ट्रांसपोर्ट (पोर्ट 443):** स्वच्छ Anycast IP और डायनामिक SNI रीराइटिंग के माध्यम से सुरक्षित कनेक्शन।
3. **मोड 3 - डीएनएस टनल (VayDNS, DNSTT, Slipstream):** 4 ट्रांसपोर्ट्स (UDP 53, TCP 53, DoH 443, DoT 853), मल्टी-रिज़ॉल्वर फेलओवर और लाइव लेटेंसी टेलीमेट्री के साथ डेटा ट्रांसफर।

### ⚡ मुख्य विशेषताएं
* **एक क्लिक में क्लाइंट रूटिंग प्रोफाइल:** Happ, v2rayNG, Sing-box और Npv Tunnel के लिए तत्काल रूटिंग नियम।
* **डायनेमिक पोर्ट प्रबंधन:** सेटिंग्स में आसानी से नए लोकल पोर्ट्स जोड़ें और प्रबंधित करें।
* **स्मार्ट टाइमर सिस्टम:** डिस्कनेक्ट होने पर समय की खपत तुरंत रुक जाती है। 4 घंटे का बोनस विकल्प।
* **10 भाषाओं का समर्थन:** हिन्दी, फारसी, अंग्रेजी, अरबी, चीनी, रूसी, स्पेनिश, इतालवी, जर्मन और फ्रेंच।
* **डार्क और लाइट थीम:** सिस्टम सेटिंग्स के अनुसार स्वचालित थीम परिवर्तन।

---

## 🛠️ Building & Development / ساخت و توسعه

### Prerequisites
* Flutter SDK `^3.9.0`
* Android SDK (API level 24+)

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
