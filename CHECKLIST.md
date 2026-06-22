# Checklist Pre-Launch & Season Start — SMP Românesc
# ============================================================
# OBLIGATORIU: Completează fiecare item înainte de a deschide serverul public.
# Un item necompletat = potențial risc de securitate sau experiență slabă.
# ============================================================

## Secțiunea 1 — Securitate Rețea (CRITIC)

### UFW Firewall
- [ ] UFW activ: `ufw status` afișează **ACTIVE**
- [ ] Singurele porturi deschise sunt 22 și 25565:
  ```bash
  ufw status verbose
  ```
- [ ] Port 25575 (RCON) confirmat BLOCAT:
  ```bash
  nc -zv localhost 25575   # trebuie să eșueze
  ```
- [ ] Port 8123 (Dynmap) confirmat BLOCAT extern:
  ```bash
  nc -zv <IP_VPS> 8123     # trebuie să eșueze din afara VPS-ului
  ```

### SSH Hardening
- [ ] Autentificare cu parolă DEZACTIVATĂ:
  ```bash
  grep PasswordAuthentication /etc/ssh/sshd_config.d/99-mc-hardening.conf
  # Trebuie să afișeze: PasswordAuthentication no
  ```
- [ ] Cheie SSH creată și funcțională **ÎNAINTE** de dezactivarea parolei
- [ ] Login root DEZACTIVAT:
  ```bash
  grep PermitRootLogin /etc/ssh/sshd_config.d/99-mc-hardening.conf
  # Trebuie să afișeze: PermitRootLogin no
  ```

## Secțiunea 2 — Docker & Server

- [ ] `ONLINE_MODE=true` în `.env` — verificat explicit, nu asumat:
  ```bash
  grep ONLINE_MODE /opt/minecraft/.env
  ```
- [ ] `RCON_PASSWORD` minim 24 de caractere random în `.env`:
  ```bash
  # Generare parolă sigură:
  openssl rand -base64 32
  ```
- [ ] Port RCON **ABSENT** din secțiunea `ports` în `docker-compose.yml`:
  ```bash
  grep 25575 docker-compose.yml   # trebuie să returneze NIMIC din secțiunea ports
  ```
- [ ] Port Dynmap **ABSENT** din secțiunea `ports` în `docker-compose.yml`:
  ```bash
  grep 8123 docker-compose.yml    # trebuie să returneze NIMIC din secțiunea ports
  ```
- [ ] Healthcheck prezent și activ:
  ```bash
  docker inspect mc --format '{{.State.Health.Status}}'
  # Trebuie să afișeze: healthy (după ~2 minute de la start)
  ```
- [ ] Serverul pornește fără erori în logs:
  ```bash
  docker compose logs mc | grep -i "done\|error\|exception"
  ```

## Secțiunea 3 — Fișiere & Secrete

- [ ] `.env` în `.gitignore`:
  ```bash
  grep '.env' .gitignore
  ```
- [ ] `.env` cu permisiuni restrictive (600):
  ```bash
  ls -la .env   # trebuie să afișeze: -rw-------
  # Setare: chmod 600 .env
  ```
- [ ] Nu există secrete hardcodate în `docker-compose.yml`:
  ```bash
  grep -i 'password\|token\|secret' docker-compose.yml
  # Trebuie să afișeze DOAR referințe la variabile: ${VAR}
  ```
- [ ] Toate plugin JAR-urile din DOWNLOAD_LIST.md (surse oficiale):
  ```bash
  ls -la plugins/*.jar
  ```

## Secțiunea 4 — Plugin-uri

- [ ] **Vault** pornit (apare în `/plugins`):
  ```bash
  docker exec mc rcon-cli plugins
  ```
- [ ] **LuckPerms** pornit și grupuri configurate:
  ```bash
  docker exec mc rcon-cli "lp listgroups"
  # Trebuie să afișeze: jucator, helper, moderator, admin
  ```
- [ ] **EssentialsX** — comenzi dezactivate verificate:
  ```bash
  # Login ca jucător test și încearcă /pay — trebuie să nu funcționeze
  ```
- [ ] **Prism** activ — test logging (înlocuiește CoreProtect incompatibil cu MC 26.1.x):
  ```bash
  # Place/break un bloc → /prism lookup p:<player> → verifică
  docker compose logs mc | grep -i "prism"
  ```
- [ ] **DiscordSRV** conectat la Discord:
  ```bash
  docker compose logs mc | grep -i "discordsrv"
  # Încearcă /discord în joc
  ```
- [ ] **Squaremap** accesibil via Cloudflare Tunnel (înlocuiește Dynmap incompatibil cu MC 26.1.x):
  ```bash
  curl -I https://map.serverultau.ro   # trebuie să returneze 200
  # Port intern: 8123 (Squaremap configurat în data/plugins/squaremap/config.yml)
  ```
- [ ] **Towny** pornit, wars dezactivate:
  ```bash
  docker exec mc rcon-cli "towny status"
  ```
- [ ] **ShopGUI+** funcțional:
  ```bash
  # Login ca jucător → /shop → verifică categoriile și prețurile
  ```
- [ ] **MythicMobs** — test spawn boss în world de test:
  ```bash
  docker exec mc rcon-cli "mm m spawn UmbraSenina"
  # Verifică că boss-ul apare corect cu 3000 HP
  ```

## Secțiunea 5 — Backup & Recovery

- [ ] `scripts/backup.sh` testat manual:
  ```bash
  bash /opt/minecraft/scripts/backup.sh
  ls -lh /opt/mc-backups/
  # Trebuie să existe arhiva backup_*.tar.gz
  ```
- [ ] Crontab configurat pentru backup zilnic:
  ```bash
  crontab -l | grep backup
  # Trebuie să afișeze: 0 4 * * * .../backup.sh
  ```
- [ ] Crontab configurat pentru reset resurse luni:
  ```bash
  crontab -l | grep reset-resurse
  # Trebuie să afișeze: 0 5 * * 1 .../reset-resurse.sh
  ```
- [ ] Test restore backup (în director temporar):
  ```bash
  mkdir /tmp/test-restore
  tar -xzf /opt/mc-backups/backup_*.tar.gz -C /tmp/test-restore
  ls /tmp/test-restore
  rm -rf /tmp/test-restore
  ```

## Secțiunea 6 — Start Sezon (14 Pași)

- [ ] 1. VPS provisionat → `bash scripts/setup.sh`
- [ ] 2. `.env` configurat cu valori de producție (nu PLACEHOLDER)
- [ ] 3. `docker compose up -d` → așteptare mesaj „Done!" în logs
- [ ] 4. `bash scripts/setup-luckperms.sh` → toate grupurile create
- [ ] 5. Plugin JAR-uri copiate în `data/plugins/` (din plugins/)
- [ ] 6. `docker compose restart mc` → reload plugin configs
- [ ] 7. Construire spawn (mod creativ Admin)
- [ ] 8. NPC-uri plasate la spawn (comenzi din docs/09_spawn_design.md)
- [ ] 9. `/mv create resurse NORMAL` + `/mvwarp create resurse`
- [ ] 10. Verificare CoreProtect: place/break bloc → `/co inspect`
- [ ] 11. Verificare DiscordSRV: mesaj în joc → apare în #chat-minecraft
- [ ] 12. Verificare Dynmap: `map.serverultau.ro` se încarcă în browser
- [ ] 13. Whitelist test cu 2–3 jucători de încredere (24h)
- [ ] 14. Anunț public în Discord cu IP + reguli

## Secțiunea 7 — Calendar Admin

| Săptămâna | Acțiune | Comandă |
|-----------|---------|---------|
| 1 | Launch server | `docker compose up -d` |
| 2 | Review economie | `/baltop` — dacă top > 50k, reduce sell cu 20% |
| 3 | Activare wars | `/ta toggle war` (anunț Discord 24h înainte) |
| 4 | Treasure Hunt | Anunț în #events |
| 6 | Review economie | Verifică inflația prețurilor |
| 8 | Boss teaser | Post în #events |
| 10 | Unlock Q3 | `/quests unlock <player> umbra-sezonului` |
| 11 | Boss Fight | `/mm m spawn UmbraSenina` (procedura din docs/07) |
| 12 | Anunță end sezon | 2 săptămâni înainte |
| 13 | Awards | Roluri Discord „Campion S1" / „Legendă S1" |
| 14 | Reset sezon | `bash scripts/backup.sh` → `docker compose down` → arhivă |

## Secțiunea 8 — Review Lunar Securitate

- [ ] `docker compose pull` — actualizare imagini Docker
- [ ] Verificare advisory-uri PaperMC: https://papermc.io/
- [ ] Verificare changelog plugin-uri pentru patch-uri de securitate
- [ ] Test restore backup (restaurare în folder temp, verificare world)
- [ ] Review log-uri CoreProtect pentru pattern-uri neobișnuite
- [ ] Check disk usage: `df -h` — alertă dacă >80%:
  ```bash
  df -h /opt
  ```

---
*Versiune checklist: SMP-ARCH-001 v1.0.0*
*Generat conform: 12_security.md + 15_season_lifecycle.md*
