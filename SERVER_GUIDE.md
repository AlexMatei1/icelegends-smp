# IceLegends SMP — Server Guide
> Paper 26.1.2 · Skript 2.15.3 · Docker Compose · Updated: 2026-06-19

---

## Plugin List

### Active Plugins

| Plugin | Version | Role |
|--------|---------|------|
| Skript | 2.15.3 | All custom gameplay — economy, skills, shop, AH, quests, claims, chat, kits, daily, backpack, quiz, vote party, reports, bosses, warps, stats |
| EssentialsX | 2.22.0 | Economy backend (Vault), `/home`, `/spawn`, `/tpa` fallback, player userdata files |
| Vault | 1.7.3 | Economy API bridge between EssentialsX and Skript (`player's balance`) |
| LuckPerms | 5.5.53 | Permission groups: `default → jucator → helper → moderator → admin`. YAML storage |
| FancyNpcs | 2.10.1 | Hub NPCs (paznicul, meseriasul, primarul) with custom skins |
| DecentHolograms | 2.10.0 | Floating holograms in hub and SMP (leaderboards, signs) |
| FastAsyncWorldEdit | 2.15.2 | World editing for hub schematic save/restore (`/hubsave`, `/hubrestore`) |
| PlaceholderAPI | 2.12.2 | Placeholder support for other plugins |
| Multiverse-Core | 5.7.0 | Multi-world management: `hub`, `world` (SMP), `worldeditregentempworld` |
| NBTAPI | 2.15.7 | NBT data access used internally by Skript addons |
| Chunky | 1.4.40 | Pre-generates chunks around spawn to reduce lag on first exploration |
| ViaVersion | 5.9.2 | Allows clients newer than 1.21.x to connect |
| ViaBackwards | 5.9.2 | Allows clients as old as 1.8 to connect |

### Disabled Plugins (kept for reference)

| Plugin | Why Disabled |
|--------|-------------|
| AuraSkills 2.3.12 | Replaced by custom `smp-skills.sk` (Pamant/Foc/Viata/Apa/Vant) |
| DiscordSRV 1.30.5 | Not yet configured — needs Discord bot token |
| GrimAC | Anti-cheat — disabled during development, enable before public launch |
| MythicMobs 5.12.1 | Replaced by `smp-bosses.sk` |
| Plan 5.7 | Player analytics — replaced by the IceLegends web panel |
| Prism 4.3 | Block logging — replaced by `icelegends-logs.sk` |
| Quests 5.3.1 | Replaced by `smp-quests.sk` |
| Towny 0.103.0 | Land claiming — replaced by `smp-claims.sk` |
| Squaremap 1.3.13 | Live world map — can enable if you want a public map |

---

## Skript Scripts

### Hub
| Script | What it does |
|--------|-------------|
| `hub-core.sk` | `/hub` teleport, hub world setup, join behavior |
| `hub-busola.sk` | Compass GUI for hub navigation |
| `hub-cosmetics.sk` | Cosmetic selector in hub |
| `hub-leaderboard.sk` | In-game leaderboard holograms in hub |
| `hub-npcs.sk` | NPC interaction handlers |
| `hub-parkour.sk` | Parkour course checkpoints and rewards |
| `hub-portals.sk` | Portal pads that teleport to SMP / shop worlds |
| `hub-restore.sk` | Blocks explosions in hub, auto-restores minor damage |
| `hub-schematic.sk` | `/hubsave` and `/hubrestore` via FAWE schematic |
| `hub-setup.sk` | One-time hub world configuration |
| `hub-tablist.sk` | Custom tab list in hub |

### IceLegends Core
| Script | What it does |
|--------|-------------|
| `icelegends-afk.sk` | AFK detection — pauses playtime, shows AFK tag |
| `icelegends-anticheat.sk` | Basic custom anti-cheat checks |
| `icelegends-backpack.sk` | `/bp` — 27-slot persistent backpack per player |
| `icelegends-chat.sk` | Chat format with rank prefix and color |
| `icelegends-daily.sk` | `/daily` — login streak reward (50 × min(streak,5) coins) |
| `icelegends-economy.sk` | `/bal`, `/pay`, `/baltop` wrappers and coin formatting |
| `icelegends-events.sk` | Logs structured events (`[ICELEGENDS_KILL]` etc.) for the panel's live feed |
| `icelegends-homes.sk` | `/sethome`, `/home`, `/delhome` with per-rank limit |
| `icelegends-kit.sk` | `/kit starter` (one-time iron gear), `/kit daily` (24h), `/kit miner` (48h) |
| `icelegends-logs.sk` | Block place/break logging (replaces Prism) |
| `icelegends-misc.sk` | Misc QoL: join/quit messages, death messages, etc. |
| `icelegends-pm.sk` | `/msg`, `/r` private messages |
| `icelegends-quiz.sk` | Chat math quiz every 20 minutes — first answer wins 100 coins |
| `icelegends-report.sk` | `/report <player> <reason>` — notifies online staff, 5-min cooldown |
| `icelegends-staff.sk` | Staff tools: vanish, staffchat, freeze |
| `icelegends-stats.sk` | Playtime tracking (per minute, AFK excluded), playtime milestones, rank system |
| `icelegends-tpa.sk` | `/tpa`, `/tpaccept`, `/tpdeny` |
| `icelegends-voteparty.sk` | Vote counter — every 50 votes triggers party (200 coins + golden apple) |
| `icelegends-weblink.sk` | `/registerweb` — generates token for panel account linking |
| `icelegends-welcome.sk` | First-join welcome message + auto-gives starter kit |

### SMP Gameplay
| Script | What it does |
|--------|-------------|
| `smp-auction.sk` | `/ah` — paginated 54-slot auction house, `/ah sell <price>`, 5% listing tax, 48h expiry |
| `smp-bosses.sk` | Custom boss spawns with special drops |
| `smp-broadcasts.sk` | Rotating tip broadcasts every 5 minutes |
| `smp-claims.sk` | Land claiming system (replaces Towny) |
| `smp-cleaner.sk` | Periodic entity and item cleanup |
| `smp-combat.sk` | PvP tag, combat logger protection |
| `smp-inventories.sk` | Per-world inventory separation (hub vs SMP) |
| `smp-quests.sk` | Daily quest contracts — 3 per day, random objectives |
| `smp-shop.sk` | `/shop` — category GUI shop (Resurse, Hrana, Mob Drops, Agricultura, Special) |
| `smp-skills.sk` | 5-skill system: Pamant (mining), Foc (combat), Viata (farming), Apa (fishing), Vant (movement). Passive buffs at lv25/50/75 |
| `smp-sleep.sk` | Skip night when >50% of players sleep |
| `smp-warps.sk` | `/warp`, `/setwarp`, `/delwarp` (admin) |

### Shop World
| Script | What it does |
|--------|-------------|
| `shop-core.sk` | Main shop world NPC interactions |
| `shop-primar.sk` | Special shop with mayor NPC |
| `shop-setup.sk` | Shop world initial setup |

---

## LuckPerms Permission Groups

```
default
  └── jucator        (new verified player)
        └── helper   (staff trial)
              └── moderator
                    └── admin
```

### Key Permissions per Group

| Permission | jucator | helper | moderator | admin |
|-----------|---------|--------|-----------|-------|
| `/kit`, `/shop`, `/ah` | ✅ | ✅ | ✅ | ✅ |
| `/skills`, `/bp`, `/daily` | ✅ | ✅ | ✅ | ✅ |
| `/report`, `/tpa`, `/home` | ✅ | ✅ | ✅ | ✅ |
| `/reports`, `/rresolve` | ❌ | ✅ | ✅ | ✅ |
| `smp.logs.lookup` | ❌ | ✅ | ✅ | ✅ |
| `/ban`, `/kick`, `/mute` | ❌ | ❌ | ✅ | ✅ |
| `essentials.nick` | ❌ | ❌ | ✅ | ✅ |
| `/vptrigger`, `/quiz` (admin) | ❌ | ❌ | ❌ | ✅ |
| RCON / console | ❌ | ❌ | ❌ | ✅ |

---

## Panel ↔ Server Sync Map

| Panel Feature | How it syncs | Latency |
|--------------|-------------|---------|
| Live player count / TPS | RCON `/list` + `/gc` every 5 min | ~5 min |
| Leaderboard (balance) | Reads Essentials `userdata/*.yml` directly | ~5 min |
| Leaderboard (playtime) | Reads Skript `variables.csv` | ~5 min |
| Player profile | Essentials userdata + variables.csv + LuckPerms YAML | ~5 min |
| Live event feed | Tails `latest.log` for `[ICELEGENDS_*]` lines | ~1 sec |
| Player registration | RCON `/iclwebtoken <uuid>` on token submit | instant |
| Admin: kick/ban/broadcast | RCON command passthrough | instant |
| Admin: economy give/set | RCON `eco give/set` | instant |
| Admin: console | RCON raw command | instant |
| Ban appeals | SQLite DB in panel only | N/A |
| Announcements | SQLite DB in panel only (no in-game sync yet) | N/A |
| Vote party counter | ❌ Not connected — `countVote()` never called | — |

---

## Server Verification Checklist

### Infrastructure
- [ ] `docker compose ps` — all containers show `healthy` or `Up`
- [ ] Panel accessible via Cloudflare tunnel URL
- [ ] MC accessible via playit.gg on port 25565
- [ ] Load average stays < 3.0 at idle, < 6.0 with players (`uptime`)
- [ ] MC container memory stays < 2.5 GB (`docker stats`)
- [ ] No errors in `data/logs/latest.log` on startup

### Worlds
- [ ] Hub world loads — `/hub` teleports correctly
- [ ] SMP world loads — spawn is set, no fall into void
- [ ] Shop world loads — NPCs present
- [ ] Per-world inventories are separated (hub gear ≠ SMP gear)
- [ ] Hub explosions are blocked (`hub-restore.sk`)
- [ ] `/hubsave` saves schematic (admin, in hub, with FAWE selection)
- [ ] `/hubrestore` restores hub from saved schematic

### Economy
- [ ] `/bal` returns balance
- [ ] `/pay <player> 10` transfers coins
- [ ] `/baltop` shows leaderboard
- [ ] Vault hooked into EssentialsX (check startup log for `[Vault] [Economy] Essentials Economy found`)

### Kits & Daily
- [ ] `/kit` shows list of available kits
- [ ] `/kit starter` gives iron set + tools + food — usable only once per player
- [ ] `/kit daily` gives food + 100 coins — 24h cooldown enforced
- [ ] `/kit miner` gives diamond pickaxe Eff3 — 48h cooldown enforced
- [ ] `/daily` on first login of the day awards coins and increments streak
- [ ] Streak resets if player misses a day

### Skills
- [ ] `/skills` opens the skill display
- [ ] `/skills pamant` shows Pamant XP and level
- [ ] Mining coal ore → Pamant XP added
- [ ] Mining diamond ore → Pamant XP added (more than coal)
- [ ] Ancient debris → Pamant XP added (80 XP)
- [ ] Killing zombie → Foc XP added
- [ ] Killing creeper → Foc XP added (4 XP)
- [ ] Breaking wheat/carrot → Viata XP added
- [ ] Level 25 Pamant → Haste I buff applied every 60s
- [ ] Level 75 Pamant → Haste II buff applied
- [ ] Level 25 Vant → fall damage reduced to 70%
- [ ] Level 75 Vant → fall damage fully cancelled

### Shop
- [ ] `/shop` opens 3-row category GUI
- [ ] Resurse category opens with items and prices
- [ ] Left-click on item → buys, deducts coins
- [ ] Right-click on item → sells, adds coins
- [ ] Ender pearl item type resolves correctly (no type ambiguity warning)
- [ ] Special category (elytra, totem) shows correct prices
- [ ] Insufficient funds shows error, does not give item

### Auction House
- [ ] `/ah` opens 54-slot GUI with pagination arrows
- [ ] `/ah sell 500` with item in hand → lists item, deducts 5% tax (25 coins)
- [ ] Max 5 active listings per player enforced
- [ ] Left-click on listing → buys item, deducts price from buyer, credits seller
- [ ] `/ah cancel` → shows own listings, right-click removes listing + returns item
- [ ] Listing disappears after 48 hours (expiry check)
- [ ] Offline seller receives coins when their listing is bought

### Backpack
- [ ] `/bp` (or `/backpack`, `/rucsac`) opens 27-slot inventory
- [ ] Items placed in backpack persist after closing
- [ ] Items persist after relog
- [ ] Multiple players' backpacks are independent

### Chat Quiz
- [ ] Quiz fires automatically every 20 minutes
- [ ] Question is a simple math operation (add/subtract/multiply)
- [ ] First player to type correct answer in chat wins 100 coins
- [ ] `/quiz` (admin) triggers a quiz immediately
- [ ] No quiz fires when no players are online

### Vote Party
- [ ] `/voteparty` shows current vote count and votes needed
- [ ] `/vptrigger` (admin) manually triggers party — all online players get 200 coins + golden apple
- [ ] Party broadcast appears in chat with title

### Reports
- [ ] `/report <player> <reason>` — notified online staff
- [ ] 5-minute cooldown between reports enforced
- [ ] Can't report yourself
- [ ] Reason must be ≥ 5 characters
- [ ] `/reports` (staff) shows last 10 reports with status
- [ ] `/rresolve <id>` marks report as handled

### Permissions
- [ ] New player joins as `default`, gets promoted to `jucator` (verify auto-promotion or manual flow)
- [ ] `jucator` can use `/kit`, `/shop`, `/ah`, `/skills`, `/bp`, `/daily`, `/report`
- [ ] `jucator` cannot use `/ban`, `/rresolve`, `/reports`
- [ ] `helper` can see `/reports` and use `smp.logs.lookup`
- [ ] `moderator` can `/ban`, `/kick`, `/essentials:nick`
- [ ] `admin` can `/vptrigger`, `/quiz` (admin), RCON commands
- [ ] No orphaned permissions (Prism, Towny) in any group

### Panel — Player Portal
- [ ] Login page works, JWT cookie set correctly
- [ ] Dashboard shows player's balance and skill levels
- [ ] Announcements banner appears when an announcement is posted
- [ ] Leaderboard page (`/player/leaderboard`) loads Coins and Playtime tabs
- [ ] Appeal form submits correctly
- [ ] Appeal status lookup by username works (no login required)
- [ ] Admin tab visible for moderator/admin/owner accounts
- [ ] Admin: kick/ban/unban a player via panel
- [ ] Admin: broadcast a message via panel (appears in-game)
- [ ] Admin: post/delete announcements
- [ ] Owner: access console tab and run a raw command

### Panel — Public Pages
- [ ] `index.html` loads and shows live player count + TPS in ticker and hero section
- [ ] Portal link works and redirects to login page
- [ ] `leaderboard.html` accessible at `/player/leaderboard`

### Panel — Sync Gaps (needs manual work)
- [ ] **Vote party integration** — connect a voting site webhook or Votifier plugin to call `/vptrigger` via RCON when a player votes
- [ ] **Announcements in-game** — decide if panel announcements should also broadcast in-game chat (currently panel-only)
- [ ] **DiscordSRV** — if Discord bridge is wanted: enable plugin, add bot token to env, configure channels
- [ ] **GrimAC** — enable before public launch to prevent cheating
- [ ] **World backups** — set up a cron job or `docker compose` schedule to zip and archive `./data/` periodically

### Pre-Launch Final
- [ ] `online-mode` decision — currently `false` (offline/cracked). Set to `true` for premium-only
- [ ] Whitelist enabled while in beta (`/whitelist on`)
- [ ] MOTD set correctly in `.env`
- [ ] Max players set correctly in `.env` (`MAX_PLAYERS`)
- [ ] RCON password is strong and not default
- [ ] Panel `JWT_SECRET` and `ADMIN_PASSWORD` are set to non-default values in `.env`
- [ ] Cloudflare tunnel token is valid and panel is reachable externally
- [ ] playit.gg tunnel is active and MC port 25565 is reachable
- [ ] Run `sk reload all` after any script changes — verify zero errors in log
- [ ] Run `lp reload` after any LuckPerms YAML edits
