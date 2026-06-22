#!/bin/bash
# ============================================================
# Setup VPS — Configurare completă server Minecraft SMP
# Platformă: Ubuntu 22.04 LTS (linux/amd64)
# Rulează ca: sudo bash scripts/setup.sh
# Idempotent — safe to run multiple times
# ============================================================
set -euo pipefail

# Culori pentru output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Director de instalare — poate fi suprascris cu variabilă de mediu
INSTALL_DIR="${INSTALL_DIR:-/opt/minecraft}"
# Utilizator dedicat pentru server (non-root, fără shell)
MC_USER="mcserver"

# ── Verificare root ───────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  log_error "Rulează cu sudo: sudo bash scripts/setup.sh"
  exit 1
fi

log_info "=== Setup VPS Minecraft SMP ==="
log_info "Director instalare: $INSTALL_DIR"

# ── Actualizare sistem ────────────────────────────────────────
log_info "Actualizare pachete sistem..."
apt-get update -qq
apt-get upgrade -y -qq

# Pachete necesare
apt-get install -y -qq \
  curl \
  wget \
  git \
  jq \
  ufw \
  htop \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release

# ── Instalare Docker ──────────────────────────────────────────
if command -v docker &>/dev/null; then
  log_info "Docker deja instalat: $(docker --version)"
else
  log_info "Instalare Docker..."
  # Cheie GPG Docker
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Repository Docker
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable docker
  systemctl start docker
  log_info "Docker instalat: $(docker --version)"
fi

# ── Configurare UFW (Firewall) ────────────────────────────────
log_info "Configurare UFW firewall..."

# Reguli de bază — deny tot incoming, allow outgoing
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH — obligatoriu înainte de enable
ufw allow 22/tcp comment 'SSH access'

# Minecraft — port public pentru jucători
ufw allow 25565/tcp comment 'Minecraft TCP'
ufw allow 25565/udp comment 'Minecraft UDP'

# 8123 (Dynmap) și 25575 (RCON) — NICIODATĂ deschise
# Dynmap e accesibil via Cloudflare Tunnel
# RCON e accesibil via docker exec mc rcon-cli

# Activare UFW
ufw --force enable
log_info "UFW configurat:"
ufw status verbose

# ── Creare utilizator mcserver ────────────────────────────────
if id "$MC_USER" &>/dev/null; then
  log_info "Utilizatorul $MC_USER există deja."
else
  log_info "Creare utilizator $MC_USER..."
  # Utilizator sistem fără shell — securitate
  useradd --system \
    --shell /usr/sbin/nologin \
    --home-dir "$INSTALL_DIR" \
    --create-home \
    "$MC_USER"
  log_info "Utilizatorul $MC_USER creat."
fi

# Adaugă mcserver în grupul docker
usermod -aG docker "$MC_USER"

# ── Creare director instalare ─────────────────────────────────
log_info "Creare structură directori..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/data"
mkdir -p "$INSTALL_DIR/config"
mkdir -p "$INSTALL_DIR/plugin-configs"
mkdir -p "$INSTALL_DIR/scripts"
mkdir -p "$INSTALL_DIR/plugins"
mkdir -p "$INSTALL_DIR/worlds"
mkdir -p /opt/mc-backups
mkdir -p /opt/mc-archives

# Drepturi pe directori
chown -R "$MC_USER:$MC_USER" "$INSTALL_DIR"
chown -R "$MC_USER:$MC_USER" /opt/mc-backups
chown -R "$MC_USER:$MC_USER" /opt/mc-archives

# ── Swap file (previne OOM la GC spikes) ─────────────────────
if [[ ! -f /swapfile ]]; then
  log_info "Creare swap file 4GB..."
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  log_info "Swap 4GB activat."
else
  log_info "Swap file există deja: $(swapon --show)"
fi

# ── Configurare SSH hardening ─────────────────────────────────
log_warn "Configurare SSH hardening..."
log_warn "ASIGURAȚI-VĂ că aveți o cheie SSH adăugată înainte de restart!"
log_warn "Comandă adăugare cheie: ssh-copy-id -i ~/.ssh/id_ed25519.pub user@VPS_IP"

# Backup config SSH original
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak."$(date +%Y%m%d)"

# Setări securitate SSH
cat > /etc/ssh/sshd_config.d/99-mc-hardening.conf << 'EOF'
# Minecraft SMP — SSH Hardening
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

log_warn "SSH hardening aplicat. Restartezi sshd DOAR după ce verifici cheia SSH."
log_warn "Comandă restart SSH: sudo systemctl restart sshd"

# ── Crontab pentru backup și reset resurse ────────────────────
log_info "Configurare crontab..."

# Scriptul de backup zilnic la 04:00
BACKUP_CRON="0 4 * * * $INSTALL_DIR/scripts/backup.sh >> /var/log/mc-backup.log 2>&1"
# Resetul lumii de resurse în fiecare luni la 05:00
RESET_CRON="0 5 * * 1 $INSTALL_DIR/scripts/reset-resurse.sh >> /var/log/mc-resurse.log 2>&1"

# Adaugă cron-uri dacă nu există deja
(crontab -l 2>/dev/null | grep -v "backup.sh\|reset-resurse.sh"; \
  echo "$BACKUP_CRON"; echo "$RESET_CRON") | crontab -

log_info "Crontab configurat:"
crontab -l

# ── Drepturi scripturi ────────────────────────────────────────
if [[ -d "$INSTALL_DIR/scripts" ]]; then
  chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true
  log_info "Scripturi: chmod +x aplicat."
fi

# ── Verificare finală ─────────────────────────────────────────
log_info ""
log_info "=== Setup complet! ==="
log_info ""
log_info "Pași următori:"
log_info "  1. Copiază fișierele proiectului în: $INSTALL_DIR"
log_info "  2. Configurează .env: cp .env.example .env && nano .env"
log_info "  3. Setează chmod 600 pe .env: chmod 600 $INSTALL_DIR/.env"
log_info "  4. Descarcă plugin JARs din plugins/DOWNLOAD_LIST.md"
log_info "  5. Pornește serverul: cd $INSTALL_DIR && docker compose up -d"
log_info "  6. Urmărește logs: docker compose logs -f mc"
log_info "  7. Rulează setup LuckPerms după primul start complet"
log_info ""
log_warn "SECURITATE: Verifică UFW și SSH înainte de a deschide serverul public!"
log_warn "  ufw status verbose"
log_warn "  grep PasswordAuthentication /etc/ssh/sshd_config.d/99-mc-hardening.conf"
