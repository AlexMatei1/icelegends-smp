<div align="center">

# ❄️ IceLegends SMP

**A fully custom Romanian Minecraft survival server**  
*Built from scratch — Flutter app · Node.js panel · 60+ Skript scripts · Docker stack*

<br/>

[![Minecraft](https://img.shields.io/badge/PaperMC-26.1.2-62b447?style=for-the-badge&logo=minecraft&logoColor=white)](https://papermc.io)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-54C5F8?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-Express-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Skript](https://img.shields.io/badge/Skript-2.15.3-7C3AED?style=for-the-badge)](https://skriptlang.org)

<br/>

🌐 **Server:** `mc.ice4legends.com` &nbsp;|&nbsp; 🖥️ **Panel:** `mc.ice4legends.com/player`

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Repository Structure](#-repository-structure)
- [Flutter App](#-flutter-app)
- [Web Panel](#-web-panel)
- [Skript Scripts](#-skript-scripts)
- [Docker Stack](#-docker-stack)
- [Setup Guide](#-setup-guide)
- [Environment Variables](#-environment-variables)

---

## 🌟 Overview

IceLegends SMP is a feature-rich Minecraft server built for the Romanian community. Every system — economy, bounties, clan wars, stock market, skills, daily quests — is custom-built with no paid gameplay plugins.

<table>
<tr>
<td width="50%">

**🎮 Gameplay Features**
- 5-element skill system (Pamant · Foc · Viata · Apa · Vant)
- Player-run stock market
- Clan wars with kill tracking
- Bounty hunting system
- Daily contracts & quests
- Auction house
- Time Capsule messages
- Custom economy with /pay, /balance

</td>
<td width="50%">

**🛠️ Technical Highlights**
- Full REST API with JWT auth
- Live server console over WebSocket
- Flutter app with glassmorphism UI
- Minecraft PNG icon system (McItem)
- Aurora gradient design language
- Docker Compose orchestration
- Cloudflare Tunnel for HTTPS/WSS
- MariaDB + SQLite persistence

</td>
</tr>
</table>

---

## 📁 Repository Structure

```
icelegends-smp/
│
├── 📱 app/                     Flutter Android app
│   ├── lib/features/           14 screens (dashboard, profile, wars…)
│   ├── lib/shared/widgets/     IceCard, IceBackground, McItem, PlayerAvatar
│   └── lib/core/               Auth, routing, theme, API client
│
├── 🖥️  panel/                   Node.js web panel
│   ├── server.js               REST API + WebSocket console (~1200 lines)
│   └── public/player/          Web UI (HTML/CSS/JS)
│
├── 📜 skripts/                  All Skript automation
│   ├── smp/                    49 scripts — economy, combat, skills…
│   ├── hub/                    7 scripts  — portals, cosmetics, NPCs…
│   └── shop/                   5 scripts  — shop economy & display
│
├── ⚙️  plugin-configs/           Plugin YAML configurations
│   └── luckperms, quests, mythicmobs, shopgui, towny, essentialsx…
│
├── 🔀 velocity/                 Velocity proxy (velocity.toml)
├── 📦 config/                   Paper global & world-defaults
├── 🐳 docker-compose.yml        Full Docker service stack
└── 🔧 scripts/                  Deploy & maintenance shell scripts
```

---

## 📱 Flutter App

A full-featured Android companion app for players, built with **Riverpod** state management, **GoRouter** navigation, and a custom ice-blue design system.

### Screens

| Screen | Icon | Description |
|--------|------|-------------|
| Dashboard | 💎 diamond | Live server status · stats · activity feed |
| Profile | 🏺 totem | Skills radar · balance · playtime · achievements |
| Misiuni | ➡️ arrow | Daily contracts with progress bar |
| Clasament | 🥇 gold_ingot | Wealth & playtime leaderboard |
| Bounty Board | 🏹 crossbow | Place & claim player bounties |
| Războaie | ⚔️ diamond_sword | Declare & accept clan wars |
| Stocks | 📊 gold_ingot | Player stock market — buy/sell shares |
| Magazin | 💚 emerald | Item shop with category grid |
| Clanuri | 🛡️ iron_chestplate | Create, join & manage clans |
| Time Capsule | 🟢 ender_pearl | Send a message to your future self |
| Vot | 📄 paper | Vote links for all listing sites |
| Contestație Ban | 📖 book | Ban appeal form + history |
| Anunțuri | 🗺️ map | Staff announcements feed |
| Admin Panel | 🥚 dragon_egg | Server stats · online players · live console |

### Design System

```
Colors:       Background #020810  ·  Ice Cyan #64DFDF  ·  Gold #FFD580
              Green #64FFDA  ·  Red #FF5252  ·  Purple #CE93D8

Fonts:        Exo 2 — headings & labels
              Inter — body text & values

Components:   IceCard      → glassmorphism blur card with colored border glow
              IceBackground → static aurora with 3 radial gradient layers
              McItem        → Minecraft PNG icons (pixel-art, FilterQuality.none)
              PlayerAvatar  → Crafatar skin head with optional ice glow ring
```

### Build

```bash
cd app
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Install wirelessly (ADB)
adb connect 192.168.x.x:5555
adb install -r app-release.apk
```

---

## 🖥️ Web Panel

A Node.js server exposing a full REST API and a WebSocket console, with a player-facing web interface that matches the Flutter app's design language.

### API Endpoints

<details>
<summary><b>Authentication</b></summary>

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login` | Login → JWT token |
| POST | `/api/auth/register` | Register new account |
| GET | `/api/player/me` | Current player stats |

</details>

<details>
<summary><b>Gameplay</b></summary>

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/status` | Live server status (RCON) |
| GET/POST | `/api/bounties` | List / place bounties |
| GET/POST | `/api/wars` | List wars / declare war |
| POST | `/api/wars/:id/accept` | Accept a war challenge |
| GET/POST | `/api/stocks` | Market listings / trade |
| GET/POST | `/api/clans` | List clans / create clan |
| GET/POST | `/api/capsules` | List / send time capsule |
| GET/POST | `/api/appeals` | List / submit ban appeal |
| GET/POST | `/api/player/missions/me` | Daily contracts |
| GET | `/api/leaderboard` | Wealth & playtime rankings |
| GET | `/api/events` | Recent server activity feed |

</details>

<details>
<summary><b>Admin</b></summary>

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/player/admin/status` | TPS, RAM, online players |
| POST | `/api/player/admin/broadcast` | Broadcast message to server |
| POST | `/api/player/admin/players/:name/kick` | Kick player |
| POST | `/api/player/admin/players/:name/ban` | Ban player |
| `WSS` | `/ws/console` | Live console stream (mod+ only) |

</details>

### JWT Auth Model

```
Player tokens  →  signed with  JWT_SECRET + '_player'
Admin tokens   →  signed with  JWT_SECRET
WebSocket      →  tries player token first, falls back to admin token
```

### Run Locally

```bash
cd panel
npm install
node server.js
# Listens on PORT from .env (default 3000)
```

---

## 📜 Skript Scripts

All custom gameplay logic is written in **Skript** — zero Java plugins required beyond the base plugin set. 61 scripts across three servers.

### SMP Server — 49 scripts

| Script | What it does |
|--------|-------------|
| `icelegends-economy.sk` | Coin economy — /pay, /balance, transaction logs |
| `icelegends-bounty.sk` | Bounty system — place, claim, auto-expire |
| `icelegends-stats.sk` | Kill / death / playtime tracking, synced to panel DB |
| `smp-skills.sk` | 5-element skill system with level progression |
| `smp-combat.sk` | PvP rules, combat tag, custom death messages |
| `smp-auction.sk` | In-game auction house |
| `smp-quests.sk` | Daily contract tracking & rewards |
| `icelegends-chat.sk` | Rank tags, chat format, @mentions |
| `icelegends-staff.sk` | Staff tools — /mute, /warn, /freeze, /spy |
| `icelegends-anticheat.sk` | Speed & reach violation detection |
| `icelegends-backpack.sk` | Persistent portable backpack system |
| `icelegends-logs.sk` | Admin activity log (all punishments & events) |
| `icelegends-kit.sk` | Starter kit on first join |
| `smp-bosses.sk` | Custom boss spawning & mechanics |
| `smp-claims.sk` | Land claiming system |
| `icelegends-weblink.sk` | In-game → panel sync bridge |
| *(+ 33 more)* | See `skripts/smp/` |

### Hub Server — 7 scripts

`hub-portals` · `hub-cosmetics` · `hub-npcs` · `hub-leaderboard` · `hub-tablist` · `hub-core` · `hub-busola`

### Shop Server — 5 scripts

`shop-core` · `shop-economy` · `shop-primar` · `shop-hub` · `shop-setup`

---

## 🐳 Docker Stack

```
┌─────────────────────────────────────────────────────┐
│                    Docker Network                    │
│                                                      │
│  ┌──────────────┐    ┌──────────────┐               │
│  │     mc       │    │    panel     │               │
│  │ Paper 1.21.4 │    │   Node.js    │               │
│  │   3GB heap   │    │  REST + WSS  │               │
│  └──────┬───────┘    └──────┬───────┘               │
│         │                   │                        │
│  ┌──────┴───────┐    ┌──────┴───────┐               │
│  │  mc-mysql    │    │  cloudflared │               │
│  │ MariaDB 10.11│    │  CF Tunnel   │               │
│  │  LuckPerms   │    │  HTTPS/WSS   │               │
│  └──────────────┘    └──────────────┘               │
│                      ┌──────────────┐               │
│                      │    playit    │               │
│                      │ Port Forward │               │
│                      └──────────────┘               │
└─────────────────────────────────────────────────────┘
```

| Container | Image | Role |
|-----------|-------|------|
| `mc` | `itzg/minecraft-server` | Paper 1.21.4 — 3GB heap, G1GC tuned |
| `panel` | custom Dockerfile | Node.js REST API + web panel |
| `mc-mysql` | `mariadb:10.11` | Database for LuckPerms |
| `playit` | `playit-cloud/playit-agent` | Port forwarding for `mc.ice4legends.com` |
| `cloudflared` | `cloudflare/cloudflared` | HTTPS + WebSocket tunnel |

---

## 🚀 Setup Guide

### Prerequisites

- Docker & Docker Compose
- Git

### 1 — Clone & configure

```bash
git clone https://github.com/AlexMatei1/icelegends-smp.git
cd icelegends-smp
cp .env.example .env
nano .env   # fill in all values
```

### 2 — Start the stack

```bash
docker compose up -d
```

### 3 — Install plugins

See `plugins/DOWNLOAD_LIST.md` for the full list. Drop JARs into `data/plugins/`.

Key plugins required: `LuckPerms` · `EssentialsX` · `Vault` · `Skript` · `SkBee` · `SkQuery` · `AureliumSkills` · `MythicMobs` · `Towny` · `CoreProtect` · `ShopGUI+` · `DiscordSRV`

### 4 — Deploy Skript scripts

```bash
# Copy scripts to the live server
cp skripts/smp/*.sk   data/plugins/Skript/scripts/
cp skripts/hub/*.sk   servers/hub/data/plugins/Skript/scripts/
cp skripts/shop/*.sk  servers/shop/data/plugins/Skript/scripts/

# Reload in-game
/skript reload all
```

### 5 — Reload after panel changes

```bash
docker compose restart panel
```

---

## 🔑 Environment Variables

| Variable | Description |
|----------|-------------|
| `JWT_SECRET` | Secret key for JWT signing |
| `MYSQL_ROOT_PASSWORD` | MariaDB root password |
| `MYSQL_PASSWORD` | LuckPerms DB user password |
| `RCON_PASSWORD` | Minecraft RCON password |
| `RCON_PORT` | RCON port (default `25575`) |
| `DISCORD_WEBHOOK_URL` | Discord notifications webhook |
| `MAX_PLAYERS` | Server player cap |
| `MOTD` | Server list message of the day |

> ⚠️ **Never commit `.env`** — it is gitignored. Use `.env.example` as the template.

---

## 📦 Required Plugins

See [`plugins/DOWNLOAD_LIST.md`](plugins/DOWNLOAD_LIST.md) for download links and versions.

---

<div align="center">

**© 2025 IceLegends / AlexMatei1** — All rights reserved.  
Source code is provided for reference only. Do not redistribute without permission.

</div>
