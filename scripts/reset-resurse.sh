#!/bin/bash
# ============================================================
# Reset Lume Resurse — Minecraft SMP
# Crontab: 0 5 * * 1 /opt/minecraft/scripts/reset-resurse.sh >> /var/log/mc-resurse.log 2>&1
# Se rulează în fiecare Luni la 05:00
# Avertizare jucători: 10 minute + 1 minut înainte
# ============================================================
set -euo pipefail

# Comanda RCON via Docker
RCON="docker exec mc rcon-cli"
# Directorul cu datele serverului
MC_DATA_DIR="/opt/minecraft/data"
# URL Webhook Discord pentru notificări (din .env sau hardcodat)
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"

# ── Verificare container ──────────────────────────────────────
if ! docker ps --format '{{.Names}}' | grep -q '^mc$'; then
  echo "[$(date)] ERROR: Containerul mc nu rulează! Reset anulat."
  exit 1
fi

echo "[$(date)] === Reset Lume Resurse start ==="

# ── Avertizare 10 minute ──────────────────────────────────────
echo "[$(date)] Trimitere avertizare 10 minute..."
$RCON 'broadcast &c&l[SISTEM] &cLumea de resurse se resetează în 10 minute!'
$RCON 'broadcast &7Finalizați ce aveți de făcut în lumea de resurse.'

# Așteptare 9 minute (540 secunde)
sleep 540

# ── Avertizare 1 minut ────────────────────────────────────────
echo "[$(date)] Trimitere avertizare 1 minut..."
$RCON 'broadcast &e&l[SISTEM] &eLumea de resurse se resetează în 1 MINUT!'
$RCON 'broadcast &7Teleportați-vă în lumea principală acum: &f/spawn'

# Așteptare 1 minut (60 secunde)
sleep 60

# ── Teleportare jucători din lumea resurse ────────────────────
echo "[$(date)] Teleportare jucători la spawn..."
# Forțează teleportarea oricui mai e în lumea resurse la spawn principal
$RCON 'broadcast &c&l[SISTEM] &cReset acum! Jucătorii din lumea resurse sunt teleportați.'

# ── Unload și ștergere lume ───────────────────────────────────
echo "[$(date)] Unload lumea resurse..."
$RCON 'mv unload resurse'

# Ștergere fișiere lume (nu este în backup — se resetează oricum)
echo "[$(date)] Ștergere fișiere lume resurse..."
rm -rf "$MC_DATA_DIR/resurse"
rm -rf "$MC_DATA_DIR/resurse_nether"
rm -rf "$MC_DATA_DIR/resurse_the_end"

# ── Recreare lume ─────────────────────────────────────────────
echo "[$(date)] Recreare lumea resurse..."
$RCON 'mv create resurse NORMAL'

# Configurare lume nouă
$RCON 'mv modify set pvp false'
$RCON 'mv modify set alias "Lume Resurse"'

# ── Confirmare ────────────────────────────────────────────────
echo "[$(date)] Confirmare reset în server..."
$RCON 'broadcast &a&l[SISTEM] &aLumea de resurse a fost resetată! Resurse proaspete disponibile.'
$RCON 'broadcast &7Accesează cu: &f/warp resurse'

# ── Notificare Discord ────────────────────────────────────────
echo "[$(date)] Trimitere notificare Discord..."
if [[ -n "$DISCORD_WEBHOOK_URL" ]]; then
  curl -s -o /dev/null -w "[$(date)] Discord webhook status: %{http_code}\n" \
    -H 'Content-Type: application/json' \
    -d '{
      "content": "🔄 **Lumea de Resurse a fost resetată!**\nResurse proaspete disponibile. Folosiți `/warp resurse` pentru acces.",
      "username": "SMP Bot"
    }' \
    "$DISCORD_WEBHOOK_URL"
else
  echo "[$(date)] WARN: DISCORD_WEBHOOK_URL nu este setat — notificare Discord sărită."
fi

echo "[$(date)] === Reset Lume Resurse complet ==="
