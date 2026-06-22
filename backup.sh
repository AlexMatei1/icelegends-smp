#!/bin/bash
# IceLegends SMP — Daily backup
# Backs up: SMP world, Skript variables+scripts, panel DB
# Keeps last 7 backups. Run via cron at 3:00 AM daily.

BACKUP_DIR="/home/matei/minecraft-smp/backups"
DATE=$(date +%Y-%m-%d_%H-%M)
DEST="$BACKUP_DIR/$DATE"
KEEP=7

mkdir -p "$DEST"

# Save world to disk before backup
docker exec mc rcon-cli --password "$(grep RCON_PASSWORD /home/matei/minecraft-smp/.env | cut -d= -f2)" "save-all flush" 2>/dev/null
sleep 5

# World (overworld only — nether/end regenerate)
tar -czf "$DEST/world.tar.gz" \
    -C /home/matei/minecraft-smp/data \
    world/dimensions \
    world/level.dat \
    2>/dev/null

# Skript scripts + variable storage
tar -czf "$DEST/skript.tar.gz" \
    -C /home/matei/minecraft-smp/data/plugins \
    Skript/scripts \
    Skript/variables.csv \
    2>/dev/null

# Panel DB (named Docker volume)
docker run --rm \
    -v minecraft-smp_panel-data:/data \
    -v "$DEST":/backup \
    alpine sh -c "cp /data/panel.db /backup/panel.db" 2>/dev/null

# LuckPerms user data
tar -czf "$DEST/luckperms.tar.gz" \
    -C /home/matei/minecraft-smp/data/plugins/LuckPerms \
    yaml-storage \
    2>/dev/null

# Purge old backups, keep last $KEEP
ls -dt "$BACKUP_DIR"/20* 2>/dev/null | tail -n +$((KEEP + 1)) | xargs rm -rf 2>/dev/null

echo "[$(date)] Backup completed: $DEST"
