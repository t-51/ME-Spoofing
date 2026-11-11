# ME Spoofing — MHPanel 多传输模式反DPI用户态代理

[![Flutter CI](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)
[![Google Play Compliant](https://img.shields.io/badge/Google%20Play-VPN%20豁免%20(用户态代理)-brightgreen)](https://developer.android.com/distribute/play-policies)
[![Languages](https://img.shields.io/badge/语言-10%20种语言-blue)](../lib/l10n/app_localizations.dart)
[![Version](https://img.shields.io/badge/版本-1.1.0-orange)](../pubspec.yaml)

---

## 📖 概述

**ME Spoofing** 是一款为 **MHPanel** 打造的高性能用户态代理中继与 DPI 审查规避引擎。它通过多层传输协议 — TCP 分片、伪装 SNI 注入以及 Cloudflare Anycast IP 前置技术 — 提供高速、稳定、安全的抗封锁网络连接，无需任何 VPN 权限或系统级特权。

---

## 🏗️ 架构与 Google Play 政策合规（无 VpnService）

与传统 VPN 应用不同，**ME Spoofing 不注册也不使用 Android 的 `VpnService` API**：

| 特性 | 详情 |
|---|---|
| **不创建系统级 VPN 配置文件** | 不修改操作系统的全局路由表，不安装虚拟 TUN 接口 |
| **纯用户态本地转发** | 核心引擎仅绑定到 `127.0.0.1:<端口>`，作为智能中间转发器运行 |
| **100% 符合 Google Play 政策** | 完全免受 Google Play 对 VPN 应用的严苛限制 |
| **广泛的客户端兼容性** | **Happ**、**v2rayNG**、**Sing-box**、**Npv Tunnel**、Telegram、浏览器 |

---

## 🚀 两大传输模式

### 模式 1 — 直连 SNI 欺骗与 TCP 分片（端口 15443）

直连 MHPanel 边缘节点，具备：
- **TLS ClientHello 微秒级分片** — 跨 TCP 记录边界执行，延迟精确到微秒级
- **伪装 SNI 域名注入** — 注入可信域名，有效迷惑 DPI 检测引擎
- 适用于大多数主服务器 IP 可达的网络环境

### 模式 2 — Cloudflare Clean IP 传输（端口 443）

通过已验证的未封锁 **Cloudflare Anycast IP** 路由所有流量：
- **动态 SNI 重写与分片** — 防御运营商基于 SNI 的拦截机制
- **Anycast IP 前置** — 流量经 Cloudflare 全球网络中转后再转发
- 适用于主 MHPanel 服务器 IP 被封锁的网络环境

---

## ⚡ 核心功能

### 📊 实时连接日志（可过滤）

实时流式日志视图，提供四个过滤标签：
- **全部** — 所有代理事件
- **伪装注入** — SNI 欺骗与伪装 SNI 注入事件
- **分片** — TCP 分片事件
- **错误** — 连接错误与警告

### 📡 实时网络统计

主屏幕显示实时网络指标：
- **下载速度**（实时，每秒更新）
- **上传速度**（实时，每秒更新）
- **当前活跃连接数**

### 🔀 路由助手对话框

智能配置转换工具：
1. 粘贴您的 V2Ray / Xray JSON 配置
2. 助手将其改写为使用 `127.0.0.1:<端口>` 作为上游
3. 输出可直接使用的配置文件**以及**本地流量的 bypass 路由规则
4. 直接粘贴到 Happ、v2rayNG、Sing-box 或 Npv Tunnel 中使用

### ⏱️ 智能计时与奖励系统

- 计时器**仅在连接活跃时倒计时** — 断开连接立即暂停
- 防止网络中断期间不公平地消耗时间
- 通过观看广告可获得 **4 小时激励时长**

### 🔄 在线更新检测

- 按需检查 GitHub Release 最新版本
- 通过应用头部的**铃铛图标**访问
- 显示可用更新的更新日志摘要

### 🔧 动态端口管理

- 在设置中自由添加、修改和删除任意数量的本地监听端口

### 🎨 深色 / 浅色主题

- 自动跟随系统深色/浅色模式
- 可在应用设置中手动覆盖

### 🌍 10 种国际化语言

完整的 RTL 和 LTR 支持：**中文（简体）、波斯语、英语、阿拉伯语、俄语、西班牙语、意大利语、德语、法语、印地语**  
首次启动时自动检测系统语言。

---

## 📱 使用指南

### 第一步：安装 APK

从 [GitHub Releases](https://github.com/t-51/snispoof/releases) 下载最新版本 APK 并安装。

### 第二步：选择传输模式

| 场景 | 推荐模式 |
|---|---|
| 服务器 IP 可正常访问 | 模式 1 — SNI 分片 |
| 服务器 IP 被封锁 | 模式 2 — Cloudflare Clean IP |

### 第三步：连接

1. 打开应用，点击**连接**
2. 代理在 `127.0.0.1:<已配置端口>` 上可用
3. 在您的客户端（Happ、v2rayNG 等）中配置使用此代理地址

### 第四步：使用路由助手（可选）

如果您已有 V2Ray/Xray 配置：
1. 点击主屏幕上的**路由助手**图标
2. 粘贴您的配置 JSON
3. 复制转换后的配置 — 可直接在任何支持的客户端中使用

---

## 🛠️ 构建与开发

### 前提条件

- Flutter SDK `^3.9.0`
- Android SDK（API 级别 24+）

```bash
# 克隆仓库
git clone https://github.com/t-51/snispoof.git
cd snispoof

# 安装依赖
flutter pub get

# 运行测试套件（12 个单元测试）
flutter test

# 构建生产 APK
flutter build apk --release
```

---

## 🔗 返回主 README

[← 返回 README](../README.md)

---

## 📄 许可证

本项目采用 MIT 许可证 — 详情请参阅 [LICENSE](../LICENSE) 文件。
