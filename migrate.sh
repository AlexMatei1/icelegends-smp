#!/bin/bash
# ============================================================
# IceLegends — Velocity Migration Script
# Ruleaza DUPA ce chunk pre-gen s-a terminat si serverul e oprit
# Usage: ./migrate.sh
# ============================================================
set -e

BASE="$(cd "$(dirname "$0")" && pwd)"
OLD="$BASE/data"
SERVERS="$BASE/servers"
SHARED="$BASE/shared"

echo "=== IceLegends Velocity Migration ==="
echo ""

# ── 1. Copiaza lumile ─────────────────────────────────────────
echo "[1/6] Copiere lumi..."

# Hub server — lumea hub
mkdir -p "$SERVERS/hub/data"
if [ -d "$OLD/hub" ]; then
    echo "  → Copiere lume hub..."
    cp -r "$OLD/hub" "$SERVERS/hub/data/hub"
fi

# SMP server — lumea principala + nether + end
mkdir -p "$SERVERS/smp/data"
for world in world world_nether world_the_end; do
    if [ -d "$OLD/$world" ]; then
        echo "  → Copiere lume $world..."
        cp -r "$OLD/$world" "$SERVERS/smp/data/$world"
    fi
done

# Shop server — lumea shop
mkdir -p "$SERVERS/shop/data"
if [ -d "$OLD/shop" ]; then
    echo "  → Copiere lume shop..."
    cp -r "$OLD/shop" "$SERVERS/shop/data/shop"
fi

# Parkour server — lumea parkour
mkdir -p "$SERVERS/parkour/data"
if [ -d "$OLD/parkour" ]; then
    echo "  → Copiere lume parkour..."
    cp -r "$OLD/parkour" "$SERVERS/parkour/data/parkour"
fi

echo "  ✔ Lumi copiate"
echo ""

# ── 2. Copiaza plugin-urile comune ───────────────────────────
echo "[2/6] Copiere plugin-uri..."

COMMON_PLUGINS=(
    "Skript-2.15.3.jar"
    "LuckPerms-Bukkit-5.5.53.jar"
    "EssentialsX-2.22.0.jar"
    "Vault-1.7.3.jar"
    "GrimAC.jar"
    "ViaVersion-5.9.2.jar"
    "ViaBackwards-5.9.2.jar"
    "NBTAPI-2.15.7.jar"
    "PlaceholderAPI-2.12.2.jar"
)

for SERVER in hub smp shop parkour; do
    mkdir -p "$SERVERS/$SERVER/data/plugins"
    for jar in "${COMMON_PLUGINS[@]}"; do
        if [ -f "$OLD/plugins/$jar" ]; then
            cp "$OLD/plugins/$jar" "$SERVERS/$SERVER/data/plugins/"
        fi
    done
done

# Plugin-uri specifice HUB
for jar in FancyNpcs-2.10.1.jar DecentHolograms-2.10.0.jar; do
    [ -f "$OLD/plugins/$jar" ] && cp "$OLD/plugins/$jar" "$SERVERS/hub/data/plugins/"
done

# Plugin-uri specifice SMP
for jar in AuraSkills-2.3.12.jar FastAsyncWorldEdit-Paper-2.15.2.jar MythicMobs-5.12.1.jar Prism-4.3.jar Quests-5.3.1-PikaMug.jar Squaremap-1.3.13.jar Plan-5.7-build-3306.jar DiscordSRV-1.30.5.jar; do
    [ -f "$OLD/plugins/$jar" ] && cp "$OLD/plugins/$jar" "$SERVERS/smp/data/plugins/"
done

# Plugin-uri specifice SHOP
for jar in FancyNpcs-2.10.1.jar DecentHolograms-2.10.0.jar; do
    [ -f "$OLD/plugins/$jar" ] && cp "$OLD/plugins/$jar" "$SERVERS/shop/data/plugins/"
done

# Plugin-uri specifice PARKOUR
# (nimic extra — Skript si Essentials ajung)

echo "  ✔ Plugin-uri copiate"
echo ""

# ── 3. Copiaza config plugin-uri ─────────────────────────────
echo "[3/6] Copiere configuratii plugin-uri..."

# LuckPerms config (va fi suprascris de config-ul MySQL)
for SERVER in hub smp shop parkour; do
    if [ -d "$OLD/plugins/LuckPerms" ]; then
        mkdir -p "$SERVERS/$SERVER/data/plugins/LuckPerms"
        cp -r "$OLD/plugins/LuckPerms/." "$SERVERS/$SERVER/data/plugins/LuckPerms/"
    fi
done

# EssentialsX config (fara userdata — va fi mountat shared)
for SERVER in hub smp shop parkour; do
    if [ -d "$OLD/plugins/Essentials" ]; then
        mkdir -p "$SERVERS/$SERVER/data/plugins/Essentials"
        cp "$OLD/plugins/Essentials/config.yml" "$SERVERS/$SERVER/data/plugins/Essentials/" 2>/dev/null || true
        cp "$OLD/plugins/Essentials/messages.properties" "$SERVERS/$SERVER/data/plugins/Essentials/" 2>/dev/null || true
    fi
done

# Essentials userdata shared
if [ -d "$OLD/plugins/Essentials/userdata" ]; then
    echo "  → Copiere userdata EssentialsX in shared/..."
    cp -r "$OLD/plugins/Essentials/userdata/." "$SHARED/essentials-userdata/"
fi

# GrimAC database.yml (disabled)
for SERVER in hub smp shop parkour; do
    if [ -d "$OLD/plugins/GrimAC" ]; then
        mkdir -p "$SERVERS/$SERVER/data/plugins/GrimAC"
        cp -r "$OLD/plugins/GrimAC/." "$SERVERS/$SERVER/data/plugins/GrimAC/"
    fi
done

# FancyNPCs — Hub si Shop
if [ -d "$OLD/plugins/FancyNpcs" ]; then
    mkdir -p "$SERVERS/hub/data/plugins/FancyNpcs"
    cp -r "$OLD/plugins/FancyNpcs/." "$SERVERS/hub/data/plugins/FancyNpcs/"
    # Shop NPC-uri separate
    mkdir -p "$SERVERS/shop/data/plugins/FancyNpcs"
    cp -r "$OLD/plugins/FancyNpcs/." "$SERVERS/shop/data/plugins/FancyNpcs/"
fi

# DecentHolograms — Hub
if [ -d "$OLD/plugins/DecentHolograms" ]; then
    mkdir -p "$SERVERS/hub/data/plugins/DecentHolograms"
    cp -r "$OLD/plugins/DecentHolograms/." "$SERVERS/hub/data/plugins/DecentHolograms/"
fi

# PlaceholderAPI placeholders
if [ -d "$OLD/plugins/PlaceholderAPI" ]; then
    for SERVER in hub smp shop parkour; do
        mkdir -p "$SERVERS/$SERVER/data/plugins/PlaceholderAPI"
        cp -r "$OLD/plugins/PlaceholderAPI/." "$SERVERS/$SERVER/data/plugins/PlaceholderAPI/"
    done
fi

echo "  ✔ Configuratii copiate"
echo ""

# ── 4. Copiaza scripturile Skript ────────────────────────────
echo "[4/6] Copiere scripturi Skript..."

# Hub scripts
mkdir -p "$SERVERS/hub/data/plugins/Skript/scripts"
for sk in hub-busola hub-npcs hub-portals hub-leaderboard hub-parkour; do
    [ -f "$OLD/plugins/Skript/scripts/$sk.sk" ] && \
        cp "$OLD/plugins/Skript/scripts/$sk.sk" "$SERVERS/hub/data/plugins/Skript/scripts/"
done

# SMP scripts
mkdir -p "$SERVERS/smp/data/plugins/Skript/scripts"
for sk in smp-claims smp-economy smp-afk smp-chat smp-ranks smp-broadcast; do
    [ -f "$OLD/plugins/Skript/scripts/$sk.sk" ] && \
        cp "$OLD/plugins/Skript/scripts/$sk.sk" "$SERVERS/smp/data/plugins/Skript/scripts/"
done

# Shop scripts
mkdir -p "$SERVERS/shop/data/plugins/Skript/scripts"
for sk in shop-gui shop-admin shop-primar; do
    [ -f "$OLD/plugins/Skript/scripts/$sk.sk" ] && \
        cp "$OLD/plugins/Skript/scripts/$sk.sk" "$SERVERS/shop/data/plugins/Skript/scripts/"
done

# Parkour scripts (hub-parkour -> parkour.sk)
mkdir -p "$SERVERS/parkour/data/plugins/Skript/scripts"
[ -f "$OLD/plugins/Skript/scripts/hub-parkour.sk" ] && \
    cp "$OLD/plugins/Skript/scripts/hub-parkour.sk" "$SERVERS/parkour/data/plugins/Skript/scripts/parkour.sk"

# Skript config
for SERVER in hub smp shop parkour; do
    if [ -f "$OLD/plugins/Skript/config.sk" ]; then
        mkdir -p "$SERVERS/$SERVER/data/plugins/Skript"
        cp "$OLD/plugins/Skript/config.sk" "$SERVERS/$SERVER/data/plugins/Skript/"
    fi
done

echo "  ✔ Scripturi copiate"
echo ""

# ── 5. Copiaza variabilele Skript ────────────────────────────
echo "[5/6] Copiere variabile Skript..."

# Hub primeste variabilele hub + portal
[ -f "$OLD/plugins/Skript/variables.csv" ] && \
    cp "$OLD/plugins/Skript/variables.csv" "$SERVERS/hub/data/plugins/Skript/"

# SMP primeste toate variabilele (claims, ranks, stats, shop)
[ -f "$OLD/plugins/Skript/variables.csv" ] && \
    cp "$OLD/plugins/Skript/variables.csv" "$SERVERS/smp/data/plugins/Skript/"

# Shop primeste variabilele shop
[ -f "$OLD/plugins/Skript/variables.csv" ] && \
    cp "$OLD/plugins/Skript/variables.csv" "$SERVERS/shop/data/plugins/Skript/"

echo "  ✔ Variabile copiate"
echo ""

# ── 6. Copiaza Chunky (pre-gen deja facut) ───────────────────
echo "[6/6] Copiere Chunky..."
[ -f "$OLD/plugins/Chunky-Bukkit-1.4.40.jar" ] && {
    for SERVER in smp shop; do
        cp "$OLD/plugins/Chunky-Bukkit-1.4.40.jar" "$SERVERS/$SERVER/data/plugins/"
    done
}
echo "  ✔ Chunky copiat"
echo ""

echo "=== Migrare completa! ==="
echo ""
echo "Urmatorii pasi:"
echo "  1. Configureaza LuckPerms MySQL pe fiecare server (vezi servers/*/data/plugins/LuckPerms/config.yml)"
echo "  2. Copiaza server.properties si paper configs manual daca e nevoie"
echo "  3. Porneste cu: docker compose up -d"
echo "  4. Verifica logs: docker logs mc-velocity mc-hub mc-smp mc-shop mc-parkour"
