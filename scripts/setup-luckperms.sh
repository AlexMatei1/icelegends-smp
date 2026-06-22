#!/bin/bash
# ============================================================
# Setup LuckPerms — Inițializare grupuri și permisiuni
# Rulează DUPĂ primul start complet al serverului:
#   bash scripts/setup-luckperms.sh
# Idempotent — safe to run multiple times (creategroup ignoră dacă există)
# ============================================================
set -euo pipefail

# Comanda RCON via Docker
RCON="docker exec mc rcon-cli"

# ── Verificare server activ ───────────────────────────────────
if ! docker ps --format '{{.Names}}' | grep -q '^mc$'; then
  echo "[LuckPerms] ERROR: Containerul mc nu rulează!"
  echo "[LuckPerms] Pornește serverul mai întâi: docker compose up -d"
  exit 1
fi

echo "[LuckPerms] === Inițializare grupuri ==="

# ── Creare Grupuri ────────────────────────────────────────────
echo "[LuckPerms] Creare grupuri..."

# Grup implicit pentru toți jucătorii noi
$RCON 'lp creategroup jucator'
# Moderator junior — primă linie de suport
$RCON 'lp creategroup helper'
# Moderator complet — ban/rollback
$RCON 'lp creategroup moderator'
# Admin — control complet
$RCON 'lp creategroup admin'

echo "[LuckPerms] Grupuri create."

# ── Greutăți (Display Order) ──────────────────────────────────
echo "[LuckPerms] Setare greutăți..."

# Greutate mai mare = prioritate mai mare în TAB/chat
$RCON 'lp group jucator   setweight 10'
$RCON 'lp group helper    setweight 20'
$RCON 'lp group moderator setweight 30'
$RCON 'lp group admin     setweight 100'

# ── Prefixe Chat ──────────────────────────────────────────────
echo "[LuckPerms] Setare prefixe..."

# Prefix afișat înaintea numelui în chat și TAB
$RCON "lp group jucator   meta setprefix '&7Jucător &8| '"
$RCON "lp group helper    meta setprefix '&aHelper &8| '"
$RCON "lp group moderator meta setprefix '&bModerator &8| '"
$RCON "lp group admin     meta setprefix '&cAdmin &8| '"

# ── Grup Implicit ─────────────────────────────────────────────
echo "[LuckPerms] Setare grup implicit..."

# Toți jucătorii noi primesc automat grupul jucator
$RCON 'lp group jucator setdefault true'

# ── Permisiuni Helper ─────────────────────────────────────────
echo "[LuckPerms] Setare permisiuni Helper..."

# EssentialsX — moderare ușoară
$RCON 'lp group helper permission set essentials.mute true'
$RCON 'lp group helper permission set essentials.unmute true'
$RCON 'lp group helper permission set essentials.kick true'
$RCON 'lp group helper permission set essentials.invsee true'
$RCON 'lp group helper permission set essentials.seen true'
$RCON 'lp group helper permission set essentials.whois true'
# Home-uri extra față de jucători
$RCON 'lp group helper permission set essentials.sethome.multiple.helper true'

# Prism — inspecție și lookup (înlocuiește CoreProtect)
$RCON 'lp group helper permission set prism.inspect true'
$RCON 'lp group helper permission set prism.lookup true'

# ── Permisiuni Moderator ──────────────────────────────────────
echo "[LuckPerms] Setare permisiuni Moderator..."

# Moștenire de la Helper
$RCON 'lp group moderator parent add helper'

# EssentialsX — ban/unban complet
$RCON 'lp group moderator permission set essentials.ban true'
$RCON 'lp group moderator permission set essentials.unban true'
$RCON 'lp group moderator permission set essentials.tempban true'
$RCON 'lp group moderator permission set essentials.banlist true'
# Fly și teleportare pentru investigații
$RCON 'lp group moderator permission set essentials.fly true'
$RCON 'lp group moderator permission set essentials.gamemode true'
$RCON 'lp group moderator permission set essentials.tp true'
$RCON 'lp group moderator permission set essentials.tpto true'
# Home-uri extra
$RCON 'lp group moderator permission set essentials.sethome.multiple.moderator true'

# Prism — rollback și restore pentru grief (înlocuiește CoreProtect)
$RCON 'lp group moderator permission set prism.rollback true'
$RCON 'lp group moderator permission set prism.restore true'
$RCON 'lp group moderator permission set prism.teleport true'

# Multiverse — acces la toate lumile pentru investigații
$RCON 'lp group moderator permission set multiverse.access.* true'
$RCON 'lp group moderator permission set multiverse.teleport.self.* true'

# Towny admin — ștergere town pentru grief sever
$RCON 'lp group moderator permission set towny.admin.town.delete true'
$RCON 'lp group moderator permission set towny.admin.town.bankhistory true'

# ── Permisiuni Admin ──────────────────────────────────────────
echo "[LuckPerms] Setare permisiuni Admin..."

# Moștenire de la Moderator
$RCON 'lp group admin parent add moderator'

# Wildcard — toate permisiunile
$RCON 'lp group admin permission set * true'

# ── Permisiuni Jucator (grup implicit) ────────────────────────
echo "[LuckPerms] Setare permisiuni Jucator..."

# EssentialsX — comenzi de bază
$RCON 'lp group jucator permission set essentials.home true'
$RCON 'lp group jucator permission set essentials.sethome true'
$RCON 'lp group jucator permission set essentials.sethome.multiple true'
$RCON 'lp group jucator permission set essentials.sethome.multiple.jucator true'
$RCON 'lp group jucator permission set essentials.tpa true'
$RCON 'lp group jucator permission set essentials.tpaccept true'
$RCON 'lp group jucator permission set essentials.tpdeny true'
$RCON 'lp group jucator permission set essentials.spawn true'
$RCON 'lp group jucator permission set essentials.msg true'
$RCON 'lp group jucator permission set essentials.reply true'

# Quests — participare la quest-uri
$RCON 'lp group jucator permission set quests.quests true'
$RCON 'lp group jucator permission set quests.quest true'
$RCON 'lp group jucator permission set quests.stats true'

# Towny — management town personal
$RCON 'lp group jucator permission set towny.command.town true'
$RCON 'lp group jucator permission set towny.command.nation true'
$RCON 'lp group jucator permission set towny.command.plot true'
$RCON 'lp group jucator permission set towny.command.plot.claim true'

# AureliumSkills — vizualizare skills
$RCON 'lp group jucator permission set auraskills.skills true'
$RCON 'lp group jucator permission set auraskills.stats true'

# ── Verificare ────────────────────────────────────────────────
echo ""
echo "[LuckPerms] === Setup complet! ==="
echo ""
echo "[LuckPerms] Verificare grupuri:"
$RCON 'lp listgroups'
echo ""
echo "[LuckPerms] Comenzi utile:"
echo "  Atribuire rank: /lp user <username> group add <grup>"
echo "  Info jucator:   /lp user <username> info"
echo "  Editor web:     /lp editor"
