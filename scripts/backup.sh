#!/bin/bash
# ============================================================
# Backup Zilnic — Minecraft SMP
# Crontab: 0 4 * * * /opt/minecraft/scripts/backup.sh >> /var/log/mc-backup.log 2>&1
# Retenție: 7 zile
# Exclude: lumea resurse (se resetează oricum)
# ============================================================
set -euo pipefail

# Director backup — creat de setup.sh
BACKUP_DIR="/opt/mc-backups"
# Directorul cu datele serverului (volum Docker)
MC_DATA_DIR="/opt/minecraft/data"
# Timestamp pentru numele arhivei
DATE=$(date +%Y-%m-%d_%H-%M)
# Număr de zile pentru retenție backup-uri
KEEP_DAYS=7
# Comanda RCON via Docker
RCON="docker exec mc rcon-cli"

# ── Verificări preliminare ────────────────────────────────────
# Creare director backup dacă nu există
mkdir -p "$BACKUP_DIR"

# Verifică dacă containerul MC rulează
if ! docker ps --format '{{.Names}}' | grep -q '^mc$'; then
  echo "[$(date)] ERROR: Containerul mc nu rulează! Backup anulat."
  exit 1
fi

echo "[$(date)] === Backup start ==="

# ── Pauză world saving pentru snapshot consistent ─────────────
# save-off previne coruperea datelor în timpul backup-ului
echo "[$(date)] Pauză salvare world (save-off)..."
$RCON 'save-off'

# Flush explicit pentru a se asigura că totul e scris pe disk
$RCON 'save-all flush'

# Așteptare pentru flush complet (5 secunde)
sleep 5

# ── Creare arhivă ─────────────────────────────────────────────
echo "[$(date)] Creare arhivă backup_$DATE.tar.gz..."
tar -czf "$BACKUP_DIR/backup_$DATE.tar.gz" \
  "$MC_DATA_DIR/" \
  --exclude="$MC_DATA_DIR/resurse" \
  --exclude="$MC_DATA_DIR/resurse/*" \
  --warning=no-file-changed

echo "[$(date)] Arhivă creată cu succes."

# ── Reactivare world saving ───────────────────────────────────
echo "[$(date)] Reactivare salvare world (save-on)..."
$RCON 'save-on'

# ── Ștergere backup-uri vechi ─────────────────────────────────
echo "[$(date)] Ștergere backup-uri mai vechi de $KEEP_DAYS zile..."
DELETED=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +"$KEEP_DAYS" -delete -print | wc -l)
echo "[$(date)] $DELETED backup-uri vechi șterse."

# ── Raport final ──────────────────────────────────────────────
SIZE=$(du -sh "$BACKUP_DIR/backup_$DATE.tar.gz" | cut -f1)
TOTAL=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "[$(date)] === Backup complet ==="
echo "[$(date)] Arhivă: backup_$DATE.tar.gz ($SIZE)"
echo "[$(date)] Total backup-uri: $TOTAL"
echo "[$(date)] Backup-uri disponibile:"
ls -lht "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -10
