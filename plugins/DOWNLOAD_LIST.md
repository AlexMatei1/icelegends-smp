# Plugin Download List — SMP Românesc
# ============================================================
# INSTRUCȚIUNI:
#   1. Descarcă JAR-ul din URL-ul oficial de mai jos
#   2. Verifică integritate: sha256sum <fișier>.jar
#   3. Compară cu hash-ul de pe pagina oficială
#   4. Pune JAR-ul în acest folder: plugins/
#   5. docker compose restart mc
#   6. Verifică în logs că pluginul a pornit fără erori:
#      docker compose logs mc | grep -i "<PluginName>"
# ============================================================
# SECURITATE: Descarcă EXCLUSIV din sursele listate mai jos.
# JAR-uri din surse neoficiale = risc de backdoor / RCE.
# ============================================================

## Layer 1 — Fundație Invizibilă (OBLIGATORII înainte de launch)

| Plugin | Versiune Minimă | URL Oficial | Gratuit? | Note |
|--------|----------------|-------------|----------|------|
| **Vault** | 1.7.3+ | https://dev.bukkit.org/projects/vault/files | ✅ Gratuit | Descarcă din tab „Files" → ultima versiune |
| **LuckPerms** | 5.x | https://luckperms.net/download | ✅ Gratuit | Alege **Bukkit** (nu BungeeCord/Velocity) |
| **Prism** | 4.3+ | https://modrinth.com/plugin/prism/versions | ✅ Gratuit | Block logging (CoreProtect NU suportă MC 26.1.x) — necesită NBTAPI |
| **NBTAPI** | 2.15+ | https://modrinth.com/plugin/nbtapi/versions | ✅ Gratuit | Dependință pentru Prism |
| **EssentialsX** | 2.21+ | https://essentialsx.net/downloads.html | ✅ Gratuit | Descarcă pachetul complet (EssentialsX.jar) |

## Layer 2 — Vanilla+ (OBLIGATORII pentru funcționalitate completă)

| Plugin | Versiune Minimă | URL Oficial | Gratuit? | Note |
|--------|----------------|-------------|----------|------|
| **AureliumSkills / AuraSkills** | 2.x | https://aurelium.dev/auraskills/download | ✅ Gratuit | Versiunea pentru PaperMC |
| **DiscordSRV** | 1.27+ | https://modrinth.com/plugin/discordsrv/versions | ✅ Gratuit | Necesită bot Discord configurat |
| **Squaremap** | 1.3+ | https://modrinth.com/plugin/squaremap/versions | ✅ Gratuit | Hartă web (Dynmap NU suportă MC 26.1.x) — port 8123 |

## Layer 3 — Unicitate (OBLIGATORII pentru gameplay complet)

| Plugin | Versiune Minimă | URL Oficial | Gratuit? | Note |
|--------|----------------|-------------|----------|------|
| **Towny Advanced** | 0.100+ | https://github.com/TownyAdvanced/Towny/releases | ✅ Gratuit | Descarcă Towny-*.jar (nu sources.jar) |
| **ShopGUI+** | 2.x | https://www.spigotmc.org/resources/shopgui.6515/ | ⚠️ ~$20 USD | Plătit pe SpigotMC — cumpără legal |
| **Quests** | 4.x | https://modrinth.com/plugin/quests/versions | ✅ Gratuit | Plugin Quests by PikaMug |
| **Citizens** | 2.0.35+ | https://citizensnpcs.co/download.html | ✅ Gratuit | Necesar pentru NPC-urile Quests |
| **MythicMobs** | 5.x | https://mythicmobs.net/index.php | ✅ Gratuit (Free) | Free version suficientă; Premium ~$10 |
| **Multiverse-Core** | 4.x | https://github.com/Multiverse/Multiverse-Core/releases | ✅ Gratuit | Descarcă .jar (nu sources sau javadoc) |

## Performanță & Securitate (Recomandate)

| Plugin | URL Oficial | Note |
|--------|-------------|------|
| **ViaVersion** | https://modrinth.com/plugin/viaversion/versions | Suport clienți versiuni mai noi |
| **ViaBackwards** | https://modrinth.com/plugin/viabackwards/versions | Suport clienți versiuni mai vechi |
| **Grim AntiCheat** | https://github.com/MWHunter/Grim/releases | Cea mai bună soluție free |
| **Spark** | https://modrinth.com/plugin/spark/versions | Profiler TPS — esențial pentru debugging |
| **ClearLag** | https://www.spigotmc.org/resources/clearlag.68271/ | Curăță entities excesive automat |

## Calitate & UX (Opționale — Săptămâna 1+)

| Plugin | URL Oficial | Note |
|--------|-------------|------|
| **TAB** | https://github.com/NEZNAMY/TAB/releases | Tablist personalizat cu prefixe LuckPerms |
| **DecentHolograms** | https://modrinth.com/plugin/decentholograms/versions | Holograme la spawn |
| **PlaceholderAPI** | https://modrinth.com/plugin/placeholderapi/versions | Necesar pentru DecentHolograms |
| **Plan Analytics** | https://github.com/plan-player-analytics/Plan/releases | Analytics detaliate jucători |
| **CommandTimer** | https://www.spigotmc.org/resources/commandtimer.84634/ | Comenzi automate (broadcast orar) |
| **PlayerWarps** | https://www.spigotmc.org/resources/player-warps.66692/ | Warp-uri create de jucători |

## Comunitate (Opționale — după Week 2)

| Plugin | URL Oficial | Note |
|--------|-------------|------|
| **Brewery** | https://github.com/mc-brew/Brewery/releases | Alcool custom (brewing) |
| **HeadDatabase** | https://www.spigotmc.org/resources/headdatabase.14280/ | Capete decorative |
| **ImageOnMap** | https://github.com/SebCodesTheWeb/image-on-map-reloaded/releases | Imagini pe hărți in-game |
| **GSit** | https://modrinth.com/plugin/gsit/versions | Stat pe scaune/blocuri |

---

## Verificare Integritate (Recomandat)

```bash
# Verifică hash SHA-256 după descărcare
sha256sum plugins/LuckPerms-Bukkit-5.x.x.jar

# Compară cu hash-ul de pe pagina oficială
# Dacă hash-urile nu coincid → ȘTERGE fișierul, descarcă din nou
```

## Ordine Instalare

```
1. Vault             — fără el, ShopGUI+ și economia nu funcționează
2. LuckPerms         — fără el, permisiunile nu funcționează
3. CoreProtect        — instalează devreme pentru logging complet
4. EssentialsX        — după Vault
5. Towny Advanced     — după LuckPerms
6. Citizens           — înainte de Quests (Quests depinde de Citizens)
7. Quests             — după Citizens
8. AureliumSkills     — independent
9. ShopGUI+           — după Vault (OBLIGATORIU)
10. MythicMobs        — independent
11. DiscordSRV        — independent (necesită bot configurat)
12. Dynmap            — independent
13. Multiverse-Core   — instalează devreme (necesar pentru lumea resurse)
```
