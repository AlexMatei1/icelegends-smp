# IceLegends SMP

A fully custom Romanian Minecraft survival multiplayer server — built from scratch with a Node.js web panel, Flutter Android app, 60+ Skript scripts, and a Docker-based server stack.

**Play at:** `mc.ice4legends.com`  
**Panel:** `https://mc.ice4legends.com/player`

---

## What's in this repo

```
icelegends-smp/
├── app/               Flutter Android app
├── panel/             Node.js REST API + web panel
├── skripts/
│   ├── smp/           49 Skript scripts for the main SMP world
│   ├── hub/           7 scripts for the Hub server
│   └── shop/          5 scripts for the Shop server
├── plugin-configs/    YAML configs for all major plugins
├── velocity/          Velocity proxy config
├── config/            Paper global & world-defaults config
├── scripts/           Deployment & maintenance shell scripts
└── docker-compose.yml Full Docker service stack
```

---

## Stack

| Layer | Technology |
|---|---|
| Minecraft server | Paper 1.21.4 via `itzg/minecraft-server` |
| Proxy | Velocity 3.5 |
| Scripting | Skript 2.15.3 (60+ scripts) |
| Panel backend | Node.js + Express + better-sqlite3 + ws |
| Panel frontend | Vanilla HTML/CSS/JS — ice-blue glassmorphism UI |
| Mobile app | Flutter 3.44 (Dart) — Android |
| Database | MariaDB 10.11 (LuckPerms) + SQLite (panel) |
| Networking | Cloudflare Tunnel + PlayIt.gg |
| Hosting | Docker Compose on a 7GB RAM VPS |

---

## Flutter App

Full-featured Android companion app for players. Built with Riverpod, GoRouter, and CachedNetworkImage.

**Screens:**
- Dashboard — live server status (30s auto-refresh), stats, activity feed
- Profile — skills radar chart, balance, playtime, achievements
- Misiuni — daily contracts with progress tracking
- Clasament — leaderboard (wealth & playtime)
- Bounty Board — place and view player bounties
- Războaie — declare and accept clan wars
- Stocks — player stock market (buy/sell shares)
- Magazin — item shop with category grid
- Clanuri — create, join, and manage clans
- Time Capsule — send a message to your future self
- Vot — vote links for all listing sites
- Contestație Ban — ban appeal form + history
- Anunțuri — staff announcements feed
- Admin Panel — server status, online players, live console (WebSocket)

**Design system:**
- Colors: void-blue `#020810`, ice cyan `#64DFDF`, aurora gradient background
- Fonts: Exo 2 (headings) + Inter (body)
- Components: `IceCard` (glassmorphism blur), `IceBackground` (aurora), `McItem` (Minecraft PNG icons)

**Build:**
```bash
cd app
flutter build apk --release
```

---

## Web Panel

Node.js server exposing a REST API and WebSocket console, with a full player-facing web interface styled to match the app.

**API highlights:**
- JWT auth — player tokens (`JWT_SECRET + '_player'`), admin tokens (`JWT_SECRET`)
- `/api/player/me` — current player stats
- `/api/status` — live server status via RCON
- `/api/bounties`, `/api/wars`, `/api/stocks`, `/api/clans` — full CRUD
- `/api/appeals` — ban appeal submission + admin review
- `/api/capsules` — time capsule delivery
- `/ws/console` — live Minecraft console over WebSocket (mod+ only)

**Run locally:**
```bash
cd panel
cp ../.env.example ../.env   # fill in your values
npm install
node server.js
```

---

## Skript Scripts

All custom gameplay logic is written in Skript — no Java plugins required beyond the base set.

| Script | Description |
|---|---|
| `icelegends-economy.sk` | Custom coin economy, /pay, /balance |
| `icelegends-bounty.sk` | Bounty system — place, claim, expire |
| `icelegends-stats.sk` | Kill tracking, playtime, stats sync to panel DB |
| `smp-skills.sk` | 5-element skill system (Pamant/Foc/Viata/Apa/Vant) |
| `smp-combat.sk` | Custom PvP rules, combat tag, death messages |
| `smp-auction.sk` | In-game auction house |
| `smp-quests.sk` | Daily quest tracking |
| `icelegends-chat.sk` | Custom chat format, rank tags, mentions |
| `icelegends-staff.sk` | Staff tools — /mute, /warn, /freeze |
| `icelegends-anticheat.sk` | Basic speed/reach checks |
| `hub-portals.sk` | Portal teleportation between worlds |
| `hub-cosmetics.sk` | Hub cosmetic system |
| *(+ 37 more)* | See `skripts/` directory |

---

## Docker Stack

Five containers managed by Docker Compose:

| Container | Role |
|---|---|
| `mc` | Paper Minecraft server (3GB heap, G1GC tuned) |
| `panel` | Node.js web panel + API |
| `mc-mysql` | MariaDB for LuckPerms |
| `playit` | PlayIt.gg agent for port forwarding |
| `cloudflared` | Cloudflare Tunnel for HTTPS + WebSocket |

**Start everything:**
```bash
cp .env.example .env   # fill in secrets
docker compose up -d
```

**Restart panel after changes:**
```bash
docker compose restart panel
```

---

## Environment Variables

Copy `.env.example` to `.env` and fill in:

```
MYSQL_ROOT_PASSWORD=
MYSQL_PASSWORD=
JWT_SECRET=
RCON_PASSWORD=
DISCORD_WEBHOOK_URL=
MAX_PLAYERS=
MOTD=
```

> Never commit `.env` — it is gitignored.

---

## Plugin List

See `plugins/DOWNLOAD_LIST.md` for the full list of required plugins and download links.

Key plugins: LuckPerms · EssentialsX · Vault · Skript · AureliumSkills · MythicMobs · Towny · CoreProtect · ShopGUI+ · DiscordSRV · GrimAC · Dynmap

---

## License

All Skript scripts, panel code, and Flutter app source are proprietary — © 2025 IceLegends / AlexMatei1.  
Do not copy or redistribute without permission.
