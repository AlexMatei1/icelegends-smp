#!/bin/bash
# ============================================================
# Update PaperMC — Verificare și actualizare server
# Compară versiunea curentă cu ultima disponibilă pe api.papermc.io
# Rulează manual înainte de update: bash scripts/update-paper.sh
# ============================================================
set -euo pipefail

# API PaperMC — endpoint pentru versiuni
PAPER_API="https://api.papermc.io/v2/projects/paper"
# Comanda RCON via Docker
RCON="docker exec mc rcon-cli"
# Directorul proiectului
MC_DIR="${MC_DIR:-/opt/minecraft}"

echo "=== Update PaperMC ==="

# ── Verificare versiune curentă ───────────────────────────────
echo "Verificare versiune curentă..."
if docker ps --format '{{.Names}}' | grep -q '^mc$'; then
  # Citește versiunea din running server
  CURRENT_VERSION=$($RCON 'version' 2>/dev/null | grep -oP 'MC: \K[0-9.]+' || echo "necunoscută")
  echo "Versiune curentă: $CURRENT_VERSION"
else
  echo "Serverul nu rulează — nu se poate determina versiunea curentă."
  CURRENT_VERSION="necunoscută"
fi

# ── Verificare ultima versiune disponibilă ────────────────────
echo "Verificare ultimă versiune pe api.papermc.io..."
LATEST_VERSION=$(curl -s "$PAPER_API" | jq -r '.versions[-1]')
LATEST_BUILD=$(curl -s "$PAPER_API/versions/$LATEST_VERSION" | jq -r '.builds[-1]')

echo "Ultimă versiune MC: $LATEST_VERSION"
echo "Ultimul build Paper: $LATEST_BUILD"

# URL download pentru informație (itzg/minecraft-server descarcă automat)
DOWNLOAD_URL="$PAPER_API/versions/$LATEST_VERSION/builds/$LATEST_BUILD/downloads/paper-$LATEST_VERSION-$LATEST_BUILD.jar"
echo "URL build nou: $DOWNLOAD_URL"

# ── Comparare ─────────────────────────────────────────────────
if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
  echo "✓ Serverul rulează deja versiunea $LATEST_VERSION. Niciun update necesar."
  echo ""
  echo "Dacă vrei să actualizezi build-ul Paper (nu MC version):"
  echo "  docker compose pull && docker compose up -d"
  exit 0
fi

echo ""
echo "Update disponibil: $CURRENT_VERSION → $LATEST_VERSION"
echo ""

# ── Confirmare utilizator ─────────────────────────────────────
read -r -p "Actualizezi la versiunea $LATEST_VERSION? (y/n): " -n 1
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Update anulat."
  exit 0
fi

# ── Procedura update ──────────────────────────────────────────
echo ""
echo "=== Procedura de update ==="

# Avertizare jucători dacă serverul rulează
if docker ps --format '{{.Names}}' | grep -q '^mc$'; then
  echo "Avertizare jucători..."
  $RCON "broadcast &c&l[ADMIN] &cServerul se restartează pentru update în 5 minute!" || true
  sleep 300
  $RCON "broadcast &c&l[ADMIN] &cRestart iminent — salveaza jocul!" || true
  sleep 30
fi

# Backup rapid înainte de update
echo "Backup rapid înainte de update..."
BACKUP_DIR="/opt/mc-backups"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y-%m-%d_%H-%M)
if docker ps --format '{{.Names}}' | grep -q '^mc$'; then
  $RCON 'save-off' || true
  $RCON 'save-all flush' || true
  sleep 5
fi
tar -czf "$BACKUP_DIR/pre-update_$DATE.tar.gz" "$MC_DIR/data/" \
  --exclude="$MC_DIR/data/resurse" \
  --warning=no-file-changed
echo "Backup creat: pre-update_$DATE.tar.gz"
if docker ps --format '{{.Names}}' | grep -q '^mc$'; then
  $RCON 'save-on' || true
fi

# Pull imagine Docker nouă
echo "Pull imagine Docker itzg/minecraft-server:latest..."
cd "$MC_DIR"
docker compose pull

# Repornire server cu versiunea nouă
echo "Repornire server cu versiunea nouă..."
docker compose up -d

echo ""
echo "=== Update complet! ==="
echo "Urmărește logs: docker compose logs -f mc"
echo "Verifică versiunea: docker exec mc rcon-cli version"
