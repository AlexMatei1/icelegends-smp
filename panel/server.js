'use strict';
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const { Rcon } = require('rcon-client');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Database = require('better-sqlite3');
const cookieParser = require('cookie-parser');
const fs = require('fs');
const path = require('path');

// ── Config ──────────────────────────────────────────────────
const PORT        = parseInt(process.env.PORT || '3000');
const RCON_HOST   = process.env.RCON_HOST || 'mc';
const RCON_PORT   = parseInt(process.env.RCON_PORT || '25575');
const RCON_PASS   = process.env.RCON_PASSWORD || '';
const JWT_SECRET  = process.env.JWT_SECRET || 'change-me-in-env';
const MC_LOG_PATH = process.env.MC_LOG_PATH || '/mc-logs/latest.log';
const DATA_DIR    = process.env.MC_DATA_PATH || '/mc-data';

// ── Database ─────────────────────────────────────────────────
const db = new Database('/app/data/panel.db');
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'moderator',
    created_at INTEGER DEFAULT (unixepoch())
  );
  CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    admin TEXT NOT NULL,
    action TEXT NOT NULL,
    detail TEXT,
    ts INTEGER DEFAULT (unixepoch())
  );
  CREATE TABLE IF NOT EXISTS player_accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    created_at INTEGER DEFAULT (unixepoch())
  );
  CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    actor TEXT,
    target TEXT,
    detail TEXT,
    ts INTEGER DEFAULT (unixepoch())
  );
  CREATE TABLE IF NOT EXISTS bounties (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    placer_uuid TEXT NOT NULL,
    placer_name TEXT NOT NULL,
    target_name TEXT NOT NULL,
    amount INTEGER NOT NULL,
    placed_at INTEGER DEFAULT (unixepoch()),
    claimed_by TEXT,
    claimed_at INTEGER,
    status TEXT DEFAULT 'active'
  );
  CREATE TABLE IF NOT EXISTS stocks (
    uuid TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    price REAL DEFAULT 100,
    shares_out INTEGER DEFAULT 1000,
    last_updated INTEGER DEFAULT (unixepoch())
  );
  CREATE TABLE IF NOT EXISTS holdings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    investor_uuid TEXT NOT NULL,
    stock_uuid TEXT NOT NULL,
    shares INTEGER NOT NULL DEFAULT 0,
    avg_price REAL NOT NULL DEFAULT 100,
    UNIQUE(investor_uuid, stock_uuid)
  );
  CREATE TABLE IF NOT EXISTS time_capsules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_uuid TEXT NOT NULL,
    from_name TEXT NOT NULL,
    to_name TEXT NOT NULL,
    message TEXT NOT NULL CHECK(length(message) <= 500),
    created_at INTEGER DEFAULT (unixepoch()),
    deliver_at INTEGER NOT NULL,
    delivered INTEGER DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS wars (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    challenger_uuid TEXT NOT NULL,
    challenger_name TEXT NOT NULL,
    target_name TEXT NOT NULL,
    target_uuid TEXT,
    stake INTEGER DEFAULT 0,
    declared_at INTEGER DEFAULT (unixepoch()),
    accepted_at INTEGER,
    ends_at INTEGER,
    status TEXT DEFAULT 'pending',
    challenger_kills INTEGER DEFAULT 0,
    target_kills INTEGER DEFAULT 0,
    winner_name TEXT
  );
  CREATE TABLE IF NOT EXISTS announcements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    author TEXT NOT NULL,
    pinned INTEGER DEFAULT 0,
    created_at INTEGER DEFAULT (unixepoch())
  );
`);
try { db.exec("ALTER TABLE appeals ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'"); } catch {}
try { db.exec("ALTER TABLE appeals ADD COLUMN staff_note TEXT DEFAULT ''"); } catch {}
// Creare cont owner implicit dacă nu există niciun user
const userCount = db.prepare('SELECT COUNT(*) as c FROM users').get().c;
if (userCount === 0) {
  const hash = bcrypt.hashSync(process.env.ADMIN_PASSWORD || 'admin123', 10);
  db.prepare("INSERT INTO users (username,password,role) VALUES (?,?,?)").run('admin', hash, 'owner');
  console.log('[panel] Creat user default: admin / (din ADMIN_PASSWORD sau "admin123")');
}
// Migrare: adaugă coloana role la player_accounts dacă lipseşte
try { db.exec("ALTER TABLE player_accounts ADD COLUMN role TEXT NOT NULL DEFAULT 'player'"); } catch {}
// Forţează rolul corect pentru Matei (owner server)
db.prepare("UPDATE player_accounts SET role='owner' WHERE username='Matei'").run();

// ── RCON Manager ─────────────────────────────────────────────
let rcon = null;
let rconReady = false;

async function connectRcon() {
  try {
    rcon = new Rcon({ host: RCON_HOST, port: RCON_PORT, password: RCON_PASS, timeout: 5000 });
    await rcon.connect();
    rconReady = true;
    console.log('[rcon] Conectat.');
    rcon.on('end', () => { rconReady = false; setTimeout(connectRcon, 5000); });
    // Sync all active bounties into Skript variables on every (re)connect
    syncBountiesToSkript().catch(() => {});
  } catch (e) {
    rconReady = false;
    console.warn('[rcon] Eroare conectare:', e.message, '— retry în 10s');
    setTimeout(connectRcon, 10000);
  }
}

async function syncBountiesToSkript() {
  const active = db.prepare("SELECT * FROM bounties WHERE status='active'").all();
  for (const b of active) {
    try { await rconCmd(`icl_bounty_set ${b.target_name} ${b.amount}`); } catch {}
  }
  if (active.length) console.log(`[bounty] Synced ${active.length} active bounty(ies) to Skript.`);
}
connectRcon();

async function rconCmd(cmd) {
  if (!rconReady) throw new Error('RCON indisponibil');
  return await rcon.send(cmd);
}

// ── Express ───────────────────────────────────────────────────
const app = express();
const server = http.createServer(app);

app.use(express.json());
app.use(cookieParser());
app.use('/admin', express.static(path.join(__dirname, 'public/admin')));
// Serve player pages with and without .html extension
app.use('/player', express.static(path.join(__dirname, 'public/player'), { extensions: ['html'] }));
app.use(express.static(path.join(__dirname, 'public')));
// Redirect /player and /player/ to dashboard
app.get('/player', (_req, res) => res.redirect('/player/dashboard'));
app.get('/player/', (_req, res) => res.redirect('/player/dashboard'));

// ── JWT Auth Middleware ───────────────────────────────────────
function auth(req, res, next) {
  const token = req.cookies.token || req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Neautentificat' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Token invalid' });
  }
}
function ownerOnly(req, res, next) {
  if (req.user?.role !== 'owner') return res.status(403).json({ error: 'Acces interzis' });
  next();
}

// ── Helpers ───────────────────────────────────────────────────
function parsePlayerList(raw) {
  // "There are X of a max of Y players online: a, b, c"
  const match = raw.match(/players online:(.*)/i);
  if (!match) return [];
  return match[1].split(',').map(s => s.trim()).filter(Boolean);
}

function parseTps(raw) {
  const clean = raw.replace(/§[0-9a-fk-or]/gi, '');
  const nums = clean.match(/[\d.]+/g) || [];
  return nums.length >= 3 ? parseFloat(nums[nums.length - 3]) : null;
}

// Citire top 5 balante din EssentialsX userdata
function getTopBalances(limit = 5) {
  const userdata = path.join(DATA_DIR, 'plugins/Essentials/userdata');
  if (!fs.existsSync(userdata)) return [];
  const entries = [];
  for (const file of fs.readdirSync(userdata)) {
    if (!file.endsWith('.yml')) continue;
    try {
      const content = fs.readFileSync(path.join(userdata, file), 'utf8');
      const moneyMatch = content.match(/^money:\s*'?([\d.]+)'?/m);
      const nameMatch  = content.match(/^last-account-name:\s*(.+)/m);
      if (moneyMatch && nameMatch) {
        entries.push({ name: nameMatch[1].trim(), balance: parseFloat(moneyMatch[1]) });
      }
    } catch {}
  }
  return entries.sort((a, b) => b.balance - a.balance).slice(0, limit);
}

// ── API publică ───────────────────────────────────────────────
app.get('/api/status', async (req, res) => {
  if (!rconReady) return res.json({ online: false, players: 0, max: 0, tps: null });
  try {
    const [listRaw, tpsRaw] = await Promise.all([
      rconCmd('list'),
      rconCmd('tps').catch(() => '')
    ]);
    const players = parsePlayerList(listRaw);
    const maxMatch = listRaw.match(/max of (\d+)/i);
    res.json({
      online: true,
      players: players.length,
      max: maxMatch ? parseInt(maxMatch[1]) : 0,
      playerNames: players,
      tps: parseTps(tpsRaw)
    });
  } catch (e) {
    res.json({ online: false, error: e.message });
  }
});

app.get('/api/top', (_req, res) => {
  try { res.json(getTopBalances()); }
  catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Leaderboard public ────────────────────────────────────────
app.get('/api/leaderboard', (_req, res) => {
  try {
    const balances = getTopBalances(10);
    // Read playtime from Skript variables (best-effort)
    const vars = parseSkriptVars();
    const playtime = [];
    for (const [k, v] of Object.entries(vars)) {
      if (k.startsWith('stats::playtime::')) {
        const uuid = k.replace('stats::playtime::', '');
        if (v > 0) playtime.push({ uuid, minutes: v });
      }
    }
    playtime.sort((a, b) => b.minutes - a.minutes);
    // Map uuid → name using Essentials userdata
    const userdata = path.join(DATA_DIR, 'plugins/Essentials/userdata');
    const uuidToName = {};
    if (fs.existsSync(userdata)) {
      for (const f of fs.readdirSync(userdata)) {
        if (!f.endsWith('.yml')) continue;
        try {
          const c = fs.readFileSync(path.join(userdata, f), 'utf8');
          const nm = c.match(/^last-account-name:\s*(.+)/m);
          if (nm) uuidToName[f.replace('.yml', '')] = nm[1].trim();
        } catch {}
      }
    }
    const playtimeTop = playtime.slice(0, 10).map(e => ({
      name: uuidToName[e.uuid] || e.uuid.slice(0, 8),
      minutes: e.minutes
    }));
    res.json({ balances, playtime: playtimeTop });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Public player profile ─────────────────────────────────────
app.get('/api/profile/:username', (req, res) => {
  const username = req.params.username;
  // Find UUID from Essentials userdata
  const userdata = path.join(DATA_DIR, 'plugins/Essentials/userdata');
  if (!fs.existsSync(userdata)) return res.status(404).json({ error: 'Not found' });
  let found = null;
  for (const f of fs.readdirSync(userdata)) {
    if (!f.endsWith('.yml')) continue;
    try {
      const c = fs.readFileSync(path.join(userdata, f), 'utf8');
      const nm = c.match(/^last-account-name:\s*(.+)/m);
      if (nm && nm[1].trim().toLowerCase() === username.toLowerCase()) {
        const moneyM = c.match(/^money:\s*'?([\d.]+)'?/m);
        found = {
          name: nm[1].trim(),
          uuid: f.replace('.yml', ''),
          balance: moneyM ? parseFloat(moneyM[1]) : 0
        };
        break;
      }
    } catch {}
  }
  if (!found) return res.status(404).json({ error: 'Jucatorul nu a fost gasit' });
  // Read Skript vars for this player
  const vars = parseSkriptVars();
  const uuid = found.uuid;
  const playtime = vars[`stats::playtime::${uuid}`] || 0;
  const rank = vars[`ranks::rank::${uuid}`] || 'Ghetar';
  const skills = {};
  for (const sk of ['Pamant', 'Foc', 'Viata', 'Apa', 'Vant']) {
    const xp = vars[`skills::${uuid}::${sk}`] || 0;
    skills[sk] = { xp, level: skillLevel(xp) };
  }
  const lpGroup = getLpGroup(uuid);
  res.json({
    name: found.name,
    uuid,
    balance: found.balance,
    playtime,
    rank,
    skills,
    group: lpGroup || 'jucator'
  });
});

// ── Announcements ─────────────────────────────────────────────
app.get('/api/announcements', (_req, res) => {
  const rows = db.prepare('SELECT * FROM announcements ORDER BY pinned DESC, created_at DESC LIMIT 10').all();
  res.json(rows);
});

app.post('/api/admin/announcements', auth, ownerOnly, async (req, res) => {
  const { title, body, pinned } = req.body;
  if (!title || !body) return res.status(400).json({ error: 'Titlu si continut obligatorii' });
  const id = db.prepare('INSERT INTO announcements (title,body,author,pinned) VALUES (?,?,?,?)').run(
    title.slice(0, 100), body.slice(0, 1000), req.user.username, pinned ? 1 : 0
  ).lastInsertRowid;
  try { await rconCmd(`broadcast &8[&b&lANUNT&8] &e${title.slice(0,60)} &8— &7mc.ice4legends.com`); } catch {}
  res.json({ ok: true, id });
});

app.delete('/api/admin/announcements/:id', auth, ownerOnly, (req, res) => {
  db.prepare('DELETE FROM announcements WHERE id=?').run(req.params.id);
  res.json({ ok: true });
});

// ── Announcements — player portal (owner only via player JWT) ──
app.post('/api/player/admin/announcements', (req, res, next) => {
  const token = req.cookies.player_token || req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Neautentificat' });
  try { req.player = jwt.verify(token, JWT_SECRET + '_player'); next(); } catch { res.status(401).json({ error: 'Token invalid' }); }
}, (req, res, next) => {
  if (req.player?.role !== 'owner') return res.status(403).json({ error: 'Acces interzis' });
  next();
}, async (req, res) => {
  const { title, body, pinned } = req.body;
  if (!title || !body) return res.status(400).json({ error: 'Titlu si continut obligatorii' });
  const id = db.prepare('INSERT INTO announcements (title,body,author,pinned) VALUES (?,?,?,?)').run(
    title.slice(0, 100), body.slice(0, 1000), req.player.username, pinned ? 1 : 0
  ).lastInsertRowid;
  try { await rconCmd(`broadcast &8[&b&lANUNT&8] &e${title.slice(0,60)} &8— &7mc.ice4legends.com`); } catch {}
  res.json({ ok: true, id });
});

app.delete('/api/player/admin/announcements/:id', (req, res, next) => {
  const token = req.cookies.player_token || req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Neautentificat' });
  try { req.player = jwt.verify(token, JWT_SECRET + '_player'); next(); } catch { res.status(401).json({ error: 'Token invalid' }); }
}, (req, res, next) => {
  if (req.player?.role !== 'owner') return res.status(403).json({ error: 'Acces interzis' });
  next();
}, (req, res) => {
  db.prepare('DELETE FROM announcements WHERE id=?').run(req.params.id);
  res.json({ ok: true });
});

// ── Auth ──────────────────────────────────────────────────────
app.post('/api/auth/login', (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'Date incomplete' });
  const user = db.prepare('SELECT * FROM users WHERE username=?').get(username);
  if (!user || !bcrypt.compareSync(password, user.password))
    return res.status(401).json({ error: 'Credențiale invalide' });
  const token = jwt.sign({ id: user.id, username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '24h' });
  res.cookie('token', token, { httpOnly: true, sameSite: 'lax', maxAge: 86400000 });
  res.json({ ok: true, role: user.role });
});

app.post('/api/auth/logout', (_req, res) => {
  res.clearCookie('token');
  res.json({ ok: true });
});

app.get('/api/auth/me', auth, (req, res) => {
  res.json({ username: req.user.username, role: req.user.role });
});

// ── Player Portal ─────────────────────────────────────────────

// Reads LuckPerms YAML user file to get the player's primary group
function getLpGroup(uuid) {
  try {
    const file = path.join(DATA_DIR, `plugins/LuckPerms/yaml-storage/users/${uuid}.yml`);
    if (!fs.existsSync(file)) return null;
    const content = fs.readFileSync(file, 'utf8');
    const m = content.match(/primaryGroup:\s*(\S+)/);
    return m ? m[1] : null;
  } catch { return null; }
}

// Maps LuckPerms group name → web role
function lpGroupToRole(group) {
  const map = { owner: 'owner', admin: 'owner', moderator: 'moderator', helper: 'helper' };
  return map[group] || 'player';
}

// Role hierarchy for permission checks
const ROLES = ['player', 'helper', 'moderator', 'admin', 'owner'];
function hasMinRole(role, min) {
  return ROLES.indexOf(role) >= ROLES.indexOf(min);
}

function playerAuth(req, res, next) {
  const token = req.cookies.player_token || req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Neautentificat' });
  try {
    req.player = jwt.verify(token, JWT_SECRET + '_player');
    next();
  } catch {
    res.status(401).json({ error: 'Token invalid' });
  }
}

function playerAdminAuth(minRole = 'moderator') {
  return (req, res, next) => {
    const role = req.player?.role || 'player';
    if (!hasMinRole(role, minRole)) return res.status(403).json({ error: 'Acces interzis' });
    next();
  };
}

function skillLevel(xp) {
  const lv = Math.floor((-90 + Math.sqrt(8100 + 40 * xp)) / 20);
  return Math.min(100, Math.max(0, isNaN(lv) ? 0 : lv));
}

// Parse Skript variables.csv — returns map of varName -> decoded value
let _varsCache = null;
let _varsCacheTime = 0;
function parseSkriptVars() {
  const now = Date.now();
  if (_varsCache && now - _varsCacheTime < 5000) return _varsCache;
  const file = path.join(DATA_DIR, 'plugins/Skript/variables.csv');
  const vars = {};
  try {
    const lines = fs.readFileSync(file, 'utf8').split('\n');
    for (const line of lines) {
      if (line.startsWith('#') || !line.trim()) continue;
      const idx1 = line.indexOf(', ');
      if (idx1 < 0) continue;
      const idx2 = line.indexOf(', ', idx1 + 2);
      if (idx2 < 0) continue;
      const name = line.slice(0, idx1);
      const type = line.slice(idx1 + 2, idx2);
      const val  = line.slice(idx2 + 2).trim();
      if (type === 'long' || type === 'integer') {
        vars[name] = parseInt(val, 16);
      } else if (type === 'double') {
        const buf = Buffer.from(val, 'hex');
        vars[name] = buf.readDoubleBE(0);
      } else if (type === 'string') {
        try {
          const len = parseInt(val.slice(2, 4), 16);
          vars[name] = Buffer.from(val.slice(4, 4 + len * 2), 'hex').toString('utf8');
        } catch {}
      } else if (type === 'boolean') {
        vars[name] = val === '01';
      }
    }
  } catch {}
  _varsCache = vars;
  _varsCacheTime = now;
  return vars;
}

// Get UUID for a Minecraft username via Essentials userdata
function getUuidByName(username) {
  const dir = path.join(DATA_DIR, 'plugins/Essentials/userdata');
  if (!fs.existsSync(dir)) return null;
  const target = username.toLowerCase();
  for (const file of fs.readdirSync(dir)) {
    if (!file.endsWith('.yml')) continue;
    try {
      const content = fs.readFileSync(path.join(dir, file), 'utf8');
      const nameMatch = content.match(/^last-account-name:\s*(.+)/m);
      if (nameMatch && nameMatch[1].trim().toLowerCase() === target) {
        return file.replace('.yml', '');
      }
    } catch {}
  }
  return null;
}

// Get balance for a UUID from Essentials userdata
function getBalance(uuid) {
  try {
    const file = path.join(DATA_DIR, 'plugins/Essentials/userdata', uuid + '.yml');
    if (!fs.existsSync(file)) return 0;
    const content = fs.readFileSync(file, 'utf8');
    const m = content.match(/^money:\s*'?([\d.]+)'?/m);
    return m ? parseFloat(m[1]) : 0;
  } catch { return 0; }
}

// Build stats object for a UUID
function buildStats(uuid, vars) {
  const SKILLS = ['Pamant', 'Foc', 'Viata', 'Apa', 'Vant'];
  const skills = {};
  const levels = {};
  for (const sk of SKILLS) {
    const xp = vars[`skills::${uuid}::${sk}`] || 0;
    skills[sk] = xp;
    levels[sk] = skillLevel(xp);
  }
  const balance = getBalance(uuid);
  // Get username from Essentials
  let name = uuid;
  try {
    const f = path.join(DATA_DIR, 'plugins/Essentials/userdata', uuid + '.yml');
    if (fs.existsSync(f)) {
      const m = fs.readFileSync(f, 'utf8').match(/^last-account-name:\s*(.+)/m);
      if (m) name = m[1].trim();
    }
  } catch {}
  return { uuid, name, balance, skills, levels };
}

// All known player UUIDs from Essentials userdata
function getAllPlayerUuids() {
  const dir = path.join(DATA_DIR, 'plugins/Essentials/userdata');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter(f => f.endsWith('.yml'))
    .map(f => f.replace('.yml', ''));
}

// POST /api/player/claim — register with in-game token via RCON (live) or variables.csv (fallback)
app.post('/api/player/claim', async (req, res) => {
  const { username, token, password } = req.body;
  if (!username || !token || !password)
    return res.status(400).json({ error: 'Date incomplete.' });
  if (password.length < 6)
    return res.status(400).json({ error: 'Parola prea scurtă (min. 6 caractere).' });

  const uuid = getUuidByName(username);
  if (!uuid)
    return res.status(400).json({ error: 'Jucătorul nu a fost găsit. Asigură-te că ai jucat cel puțin o dată pe server.' });

  let storedToken = null;
  let storedTs    = null;

  // Try RCON first — reads the live in-memory Skript variable immediately
  try {
    const raw = await rconCmd(`iclwebtoken ${uuid}`);
    // Expected response: "ICLWT:<uuid>:<token>:<ts>"
    const m = raw.match(/ICLWT:[^:]+:(\d+):(\d+)/);
    if (m) {
      storedToken = m[1];
      storedTs    = parseInt(m[2], 10);
    }
  } catch (_) {}

  // Fallback to variables.csv if RCON unavailable
  if (!storedToken) {
    const vars = parseSkriptVars();
    storedToken = vars[`weblink::token::${uuid}`];
    storedTs    = vars[`weblink::tokents::${uuid}`];
  }

  if (!storedToken)
    return res.status(400).json({ error: 'Niciun cod găsit. Rulează /registerweb în joc.' });
  if (String(storedToken) !== String(token))
    return res.status(400).json({ error: 'Cod greșit.' });
  if (storedTs && Math.floor(Date.now() / 1000) - storedTs > 600)
    return res.status(400).json({ error: 'Codul a expirat. Generează unul nou cu /registerweb.' });

  const hash = bcrypt.hashSync(password, 10);
  // Detect role from LuckPerms or existing DB record
  const lpGroup = getLpGroup(uuid);
  const detectedRole = lpGroup ? lpGroupToRole(lpGroup) : 'player';
  const existingRole = db.prepare('SELECT role FROM player_accounts WHERE uuid=?').get(uuid)?.role || 'player';
  const finalRole = hasMinRole(existingRole, detectedRole) ? existingRole : detectedRole;
  try {
    db.prepare('INSERT OR REPLACE INTO player_accounts (uuid,username,password,role) VALUES (?,?,?,?)')
      .run(uuid, username, hash, finalRole);
    const t = jwt.sign({ uuid, username, role: finalRole }, JWT_SECRET + '_player', { expiresIn: '7d' });
    res.cookie('player_token', t, { httpOnly: true, sameSite: 'lax', maxAge: 7 * 86400000 });
    res.json({ ok: true, role: finalRole });
  } catch {
    res.status(409).json({ error: 'Username deja înregistrat.' });
  }
});

// POST /api/player/login
app.post('/api/player/login', (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'Date incomplete.' });
  const account = db.prepare('SELECT * FROM player_accounts WHERE username=?').get(username);
  if (!account || !bcrypt.compareSync(password, account.password))
    return res.status(401).json({ error: 'Username sau parolă greșite.' });
  // Re-sync LuckPerms role on every login
  const lpGroup = getLpGroup(account.uuid);
  const detected = lpGroup ? lpGroupToRole(lpGroup) : account.role || 'player';
  const role = hasMinRole(account.role || 'player', detected) ? (account.role || 'player') : detected;
  if (role !== account.role) db.prepare('UPDATE player_accounts SET role=? WHERE uuid=?').run(role, account.uuid);
  const t = jwt.sign({ uuid: account.uuid, username: account.username, role }, JWT_SECRET + '_player', { expiresIn: '7d' });
  res.cookie('player_token', t, { httpOnly: true, sameSite: 'lax', maxAge: 7 * 86400000 });
  res.json({ ok: true, token: t, username: account.username, role });
});

// POST /api/player/logout
app.post('/api/player/logout', (_req, res) => {
  res.clearCookie('player_token');
  res.json({ ok: true });
});

// GET /api/player/me — role re-synced live from LuckPerms on every call
app.get('/api/player/me', playerAuth, (req, res) => {
  const vars = parseSkriptVars();
  const stats = buildStats(req.player.uuid, vars);
  // Always read LuckPerms YAML for live role (handles rank changes without re-login)
  const lpGroup  = getLpGroup(req.player.uuid);
  const lpRole   = lpGroup ? lpGroupToRole(lpGroup) : 'player';
  const dbRecord = db.prepare('SELECT role FROM player_accounts WHERE uuid=?').get(req.player.uuid);
  const dbRole   = dbRecord?.role || 'player';
  const jwtRole  = req.player.role || 'player';
  // Use the highest privilege across JWT, DB, and live LuckPerms
  const effectiveRole = [jwtRole, lpRole, dbRole].reduce((best, r) =>
    ROLES.indexOf(r) > ROLES.indexOf(best) ? r : best, 'player');
  // Persist if LP gave a higher role than DB has
  if (ROLES.indexOf(lpRole) > ROLES.indexOf(dbRole)) {
    db.prepare('UPDATE player_accounts SET role=? WHERE uuid=?').run(lpRole, req.player.uuid);
  }
  res.json({ username: req.player.username, uuid: req.player.uuid, role: effectiveRole, stats });
});

// ── Player Admin Endpoints ────────────────────────────────────

app.get('/api/player/admin/status', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  try {
    const [tpsRaw, listRaw, gcRaw] = await Promise.all([
      rconCmd('tps').catch(() => ''),
      rconCmd('list').catch(() => ''),
      rconCmd('gc').catch(() => '')
    ]);
    const stripColors = s => s.replace(/§[0-9a-fk-or]/gi, '');
    const tpsClean = stripColors(tpsRaw);
    const tpsNums = tpsClean.match(/[\d.]+/g) || [];
    const tps = tpsNums.length >= 3 ? tpsNums.slice(-3).map(parseFloat) : [0, 0, 0];
    const gcClean = stripColors(gcRaw);
    const memM    = gcClean.match(/Memorie libera[^:]*:\s*([\d,]+)\s*MB/i);
    const memMaxM = gcClean.match(/Memorie maxima[^:]*:\s*([\d,]+)\s*MB/i);
    const memFree = memM    ? parseInt(memM[1].replace(/,/g, ''))    : 0;
    const memMax  = memMaxM ? parseInt(memMaxM[1].replace(/,/g, '')) : 0;
    res.json({ tps, memFree, memMax, memUsed: memMax - memFree, players: parsePlayerList(listRaw) });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/player/admin/players', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  try { res.json(parsePlayerList(await rconCmd('list'))); }
  catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/player/admin/players/:name/kick', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  const { name } = req.params;
  const { reason } = req.body;
  try {
    await rconCmd(`kick ${name} ${reason || 'Dat afară de admin'}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'kick', name);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/player/admin/players/:name/ban', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  const { name } = req.params;
  const { reason } = req.body;
  try {
    await rconCmd(`ban ${name} ${reason || 'Banat de admin'}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'ban', name);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/player/admin/players/:name/unban', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  const { name } = req.params;
  try {
    await rconCmd(`pardon ${name}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'unban', name);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/player/admin/broadcast', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  const { message } = req.body;
  if (!message) return res.status(400).json({ error: 'Mesaj lipsă' });
  try {
    await rconCmd(`broadcast ${message}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'broadcast', message);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/player/admin/economy/give', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  const { player, amount } = req.body;
  if (!player || !amount) return res.status(400).json({ error: 'Date incomplete' });
  try {
    await rconCmd(`essentials:eco give ${player} ${amount}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'eco-give', `${player} ${amount}`);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/player/admin/economy/set', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  const { player, amount } = req.body;
  if (!player || amount == null) return res.status(400).json({ error: 'Date incomplete' });
  try {
    await rconCmd(`essentials:eco set ${player} ${amount}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'eco-set', `${player} ${amount}`);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/player/admin/whitelist/add', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  const { player } = req.body;
  try {
    await rconCmd(`whitelist add ${player}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'whitelist-add', player);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/player/admin/whitelist/remove', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  const { player } = req.body;
  try {
    await rconCmd(`whitelist remove ${player}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'whitelist-remove', player);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/player/admin/audit', playerAuth, playerAdminAuth('moderator'), (req, res) => {
  const logs = db.prepare('SELECT * FROM audit_log ORDER BY ts DESC LIMIT 50').all();
  res.json(logs);
});

app.post('/api/player/admin/command', playerAuth, playerAdminAuth('owner'), async (req, res) => {
  const { cmd } = req.body;
  if (!cmd) return res.status(400).json({ error: 'Comandă lipsă' });
  const blocked = ['stop', 'restart'];
  if (blocked.includes(cmd.split(' ')[0].toLowerCase()))
    return res.status(403).json({ error: 'Comandă blocată' });
  try {
    const result = await rconCmd(cmd);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'cmd', cmd);
    res.json({ result });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Owner: set a player's web role
app.post('/api/player/admin/setrole', playerAuth, playerAdminAuth('owner'), (req, res) => {
  const { username, role } = req.body;
  if (!username || !ROLES.includes(role)) return res.status(400).json({ error: 'Date invalide' });
  const rows = db.prepare('UPDATE player_accounts SET role=? WHERE username=?').run(role, username);
  if (rows.changes === 0) return res.status(404).json({ error: 'Jucător negăsit' });
  db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'setrole', `${username}=${role}`);
  res.json({ ok: true });
});

// GET /api/player/admin/accounts — owner only: list all web accounts
app.get('/api/player/admin/accounts', playerAuth, playerAdminAuth('owner'), (req, res) => {
  const rows = db.prepare('SELECT username, role FROM player_accounts ORDER BY role DESC, username ASC').all();
  res.json(rows);
});

// GET /api/player/stats/:username — public
app.get('/api/player/stats/:username', (req, res) => {
  const uuid = getUuidByName(req.params.username);
  if (!uuid) return res.json(null);
  const vars = parseSkriptVars();
  res.json(buildStats(uuid, vars));
});

// GET /api/player/leaderboard — public
app.get('/api/player/leaderboard', (_req, res) => {
  const vars = parseSkriptVars();
  const players = getAllPlayerUuids().map(uuid => buildStats(uuid, vars));
  players.sort((a, b) => (b.balance || 0) - (a.balance || 0));
  res.json(players);
});

// ── Event Feed ────────────────────────────────────────────────
const sseClients = new Set();

function pushEvent(type, actor, target, detail) {
  const ts = Math.floor(Date.now() / 1000);
  db.prepare('INSERT INTO events (type,actor,target,detail,ts) VALUES (?,?,?,?,?)').run(type, actor, target, detail, ts);
  db.prepare('DELETE FROM events WHERE id NOT IN (SELECT id FROM events ORDER BY id DESC LIMIT 200)').run();
  const payload = JSON.stringify({ type, actor, target, detail, ts });
  for (const res of sseClients) {
    try { res.write(`data: ${payload}\n\n`); } catch {}
  }
}

app.get('/api/events', (_req, res) => {
  const rows = db.prepare('SELECT * FROM events ORDER BY id DESC LIMIT 50').all();
  res.json(rows.reverse());
});

app.get('/api/events/stream', (req, res) => {
  res.set({ 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
  res.flushHeaders();
  res.write(':ok\n\n');
  sseClients.add(res);
  req.on('close', () => sseClients.delete(res));
});

// ── Bounty Board ───────────────────────────────────────────────
app.get('/api/bounties', (_req, res) => {
  const rows = db.prepare("SELECT * FROM bounties WHERE status='active' ORDER BY amount DESC").all();
  res.json(rows);
});

app.get('/api/bounties/history', (_req, res) => {
  const rows = db.prepare("SELECT * FROM bounties WHERE status='claimed' ORDER BY claimed_at DESC LIMIT 30").all();
  res.json(rows);
});

app.post('/api/bounties', playerAuth, async (req, res) => {
  const { target_name, amount } = req.body;
  if (!target_name || !amount) return res.status(400).json({ error: 'Date incomplete.' });
  const amt = parseInt(amount);
  if (amt < 100) return res.status(400).json({ error: 'Bounty minim: 100 coins.' });
  if (amt > 100000) return res.status(400).json({ error: 'Bounty maxim: 100000 coins.' });
  if (target_name.toLowerCase() === req.player.username.toLowerCase())
    return res.status(400).json({ error: 'Nu poți pune bounty pe tine însuți.' });

  const bal = getBalance(req.player.uuid);
  if (bal < amt) return res.status(400).json({ error: `Fonduri insuficiente. Balanța ta: ${Math.floor(bal)} coins.` });

  try {
    await rconCmd(`essentials:eco take ${req.player.username} ${amt}`);
  } catch (e) { return res.status(500).json({ error: 'Nu s-au putut deduce coins. Ești online pe server?' }); }

  db.prepare('INSERT INTO bounties (placer_uuid,placer_name,target_name,amount) VALUES (?,?,?,?)')
    .run(req.player.uuid, req.player.username, target_name, amt);
  pushEvent('BOUNTY', req.player.username, target_name, `${amt} coins`);

  // Sync to Skript so on-death handler can pay instantly
  try { await rconCmd(`icl_bounty_set ${target_name} ${amt}`); } catch {}
  // Notify target if online
  try { await rconCmd(`essentials:msg ${target_name} &c[☠ Bounty] &7Cineva a pus o recompensa de &6${amt} coins &7pe capul tau! Fii precaut!`); } catch {}

  res.json({ ok: true });
});

app.delete('/api/bounties/:id', playerAuth, playerAdminAuth('moderator'), async (req, res) => {
  const bounty = db.prepare("SELECT * FROM bounties WHERE id=? AND status='active'").get(req.params.id);
  if (!bounty) return res.status(404).json({ error: 'Bounty negăsit sau deja închis.' });
  db.prepare("UPDATE bounties SET status='cancelled' WHERE id=?").run(bounty.id);
  try { await rconCmd(`icl_bounty_clear ${bounty.target_name}`); } catch {}
  try { await rconCmd(`broadcast &8[&6☠ Bounty&8] &7Recompensa pe &c${bounty.target_name} &7a fost anulata de staff.`); } catch {}
  pushEvent('BOUNTY_CANCELLED', req.player.username, bounty.target_name, `${bounty.amount} coins`);
  db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'bounty-cancel', `${bounty.target_name} ${bounty.amount}`);
  res.json({ ok: true });
});

// ── Stock Market ───────────────────────────────────────────────
function calcStockPrice(uuid) {
  const vars = parseSkriptVars();
  const SKILLS = ['Pamant', 'Foc', 'Viata', 'Apa', 'Vant'];
  let totalLevels = 0;
  for (const sk of SKILLS) totalLevels += skillLevel(vars[`skills::${uuid}::${sk}`] || 0);
  const bal = getBalance(uuid);
  return Math.max(10, Math.round(100 + totalLevels * 4 + bal * 0.02));
}

function syncStocks() {
  const uuids = getAllPlayerUuids();
  for (const uuid of uuids) {
    const price = calcStockPrice(uuid);
    const name = (() => {
      try {
        const f = path.join(DATA_DIR, 'plugins/Essentials/userdata', uuid + '.yml');
        const m = fs.readFileSync(f, 'utf8').match(/^last-account-name:\s*(.+)/m);
        return m ? m[1].trim() : uuid;
      } catch { return uuid; }
    })();
    db.prepare('INSERT OR REPLACE INTO stocks (uuid,name,price,shares_out,last_updated) VALUES (?,?,?,COALESCE((SELECT shares_out FROM stocks WHERE uuid=?),1000),?)')
      .run(uuid, name, price, uuid, Math.floor(Date.now() / 1000));
  }
}

app.get('/api/stocks', (_req, res) => {
  syncStocks();
  const rows = db.prepare('SELECT * FROM stocks ORDER BY price DESC').all();
  res.json(rows);
});

app.get('/api/stocks/holdings', playerAuth, (req, res) => {
  const rows = db.prepare(`
    SELECT h.*, s.name as stock_name, s.price as current_price
    FROM holdings h JOIN stocks s ON h.stock_uuid = s.uuid
    WHERE h.investor_uuid = ?
  `).all(req.player.uuid);
  res.json(rows);
});

app.post('/api/stocks/buy', playerAuth, async (req, res) => {
  const { stock_uuid, shares } = req.body;
  if (!stock_uuid || !shares || shares < 1) return res.status(400).json({ error: 'Date invalide.' });
  if (stock_uuid === req.player.uuid) return res.status(400).json({ error: 'Nu poți cumpăra propriile acțiuni.' });

  syncStocks();
  const stock = db.prepare('SELECT * FROM stocks WHERE uuid=?').get(stock_uuid);
  if (!stock) return res.status(404).json({ error: 'Acțiune negăsită.' });

  const total = Math.round(stock.price * shares);
  const bal = getBalance(req.player.uuid);
  if (bal < total) return res.status(400).json({ error: `Fonduri insuficiente. Ai ${Math.floor(bal)} coins, cost: ${total}.` });

  const avail = stock.shares_out - (db.prepare('SELECT COALESCE(SUM(shares),0) as s FROM holdings WHERE stock_uuid=?').get(stock_uuid).s || 0);
  if (shares > avail) return res.status(400).json({ error: `Disponibile doar ${avail} acțiuni.` });

  try { await rconCmd(`essentials:eco take ${req.player.username} ${total}`); }
  catch { return res.status(500).json({ error: 'Deducere coins eșuată. Ești online?' }); }

  const existing = db.prepare('SELECT * FROM holdings WHERE investor_uuid=? AND stock_uuid=?').get(req.player.uuid, stock_uuid);
  if (existing) {
    const newAvg = (existing.avg_price * existing.shares + stock.price * shares) / (existing.shares + shares);
    db.prepare('UPDATE holdings SET shares=shares+?, avg_price=? WHERE id=?').run(shares, newAvg, existing.id);
  } else {
    db.prepare('INSERT INTO holdings (investor_uuid,stock_uuid,shares,avg_price) VALUES (?,?,?,?)').run(req.player.uuid, stock_uuid, shares, stock.price);
  }
  pushEvent('STOCK_BUY', req.player.username, stock.name, `${shares}x @ ${stock.price}`);
  res.json({ ok: true, total });
});

app.post('/api/stocks/sell', playerAuth, async (req, res) => {
  const { stock_uuid, shares } = req.body;
  if (!stock_uuid || !shares || shares < 1) return res.status(400).json({ error: 'Date invalide.' });

  syncStocks();
  const holding = db.prepare('SELECT * FROM holdings WHERE investor_uuid=? AND stock_uuid=?').get(req.player.uuid, stock_uuid);
  if (!holding || holding.shares < shares) return res.status(400).json({ error: 'Acțiuni insuficiente.' });

  const stock = db.prepare('SELECT * FROM stocks WHERE uuid=?').get(stock_uuid);
  const total = Math.round(stock.price * shares);

  try { await rconCmd(`essentials:eco give ${req.player.username} ${total}`); }
  catch { return res.status(500).json({ error: 'Adăugare coins eșuată. Ești online?' }); }

  if (holding.shares === shares) {
    db.prepare('DELETE FROM holdings WHERE id=?').run(holding.id);
  } else {
    db.prepare('UPDATE holdings SET shares=shares-? WHERE id=?').run(shares, holding.id);
  }
  pushEvent('STOCK_SELL', req.player.username, stock.name, `${shares}x @ ${stock.price}`);
  res.json({ ok: true, total });
});

// ── Time Capsule ───────────────────────────────────────────────
app.get('/api/capsules/mine', playerAuth, (req, res) => {
  const sent = db.prepare('SELECT * FROM time_capsules WHERE from_uuid=? ORDER BY created_at DESC').all(req.player.uuid);
  res.json(sent);
});

app.post('/api/capsules', playerAuth, (req, res) => {
  const { to_name, message, delay_days } = req.body;
  if (!to_name || !message) return res.status(400).json({ error: 'Date incomplete.' });
  if (message.length > 500) return res.status(400).json({ error: 'Mesaj prea lung (max 500 caractere).' });
  const days = [3, 7, 14, 30].includes(parseInt(delay_days)) ? parseInt(delay_days) : 7;
  const deliver_at = Math.floor(Date.now() / 1000) + days * 86400;
  db.prepare('INSERT INTO time_capsules (from_uuid,from_name,to_name,message,deliver_at) VALUES (?,?,?,?,?)')
    .run(req.player.uuid, req.player.username, to_name, message, deliver_at);
  pushEvent('CAPSULE', req.player.username, to_name, `se deschide în ${days} zile`);
  res.json({ ok: true, deliver_at });
});

// Deliver due capsules — called every 5 min by cron
async function deliverCapsules() {
  const now = Math.floor(Date.now() / 1000);
  const due = db.prepare('SELECT * FROM time_capsules WHERE delivered=0 AND deliver_at <= ?').all(now);
  for (const c of due) {
    const msg = c.message.replace(/'/g, '').replace(/"/g, '').replace(/\\/g, '').slice(0, 400);
    const from = c.from_name.replace(/[^a-zA-Z0-9_]/g, '');
    const bookNbt = `{pages:['{"text":"${msg}"}'],author:"${from}",title:"Capsula Timpului"}`;
    try {
      await rconCmd(`give ${c.to_name} minecraft:written_book${bookNbt}`);
      db.prepare('UPDATE time_capsules SET delivered=1 WHERE id=?').run(c.id);
      pushEvent('CAPSULE_DELIVERED', c.from_name, c.to_name, `${c.message.slice(0, 40)}...`);
    } catch {}
  }
}
setInterval(deliverCapsules, 5 * 60 * 1000);

// ── Territory Wars ─────────────────────────────────────────────
app.get('/api/wars', (_req, res) => {
  const rows = db.prepare("SELECT * FROM wars WHERE status IN ('pending','active') ORDER BY declared_at DESC").all();
  res.json(rows);
});

app.get('/api/wars/history', (_req, res) => {
  const rows = db.prepare("SELECT * FROM wars WHERE status='ended' ORDER BY declared_at DESC LIMIT 20").all();
  res.json(rows);
});

app.post('/api/wars/declare', playerAuth, async (req, res) => {
  const { target_name, stake } = req.body;
  if (!target_name) return res.status(400).json({ error: 'Numește ținta.' });
  const st = Math.max(0, Math.min(10000, parseInt(stake) || 0));
  if (target_name.toLowerCase() === req.player.username.toLowerCase())
    return res.status(400).json({ error: 'Nu te poți război cu tine însuți.' });

  const existing = db.prepare("SELECT id FROM wars WHERE (challenger_name=? OR target_name=?) AND status IN ('pending','active')").get(req.player.username, req.player.username);
  if (existing) return res.status(400).json({ error: 'Ai deja un război activ sau în așteptare.' });

  if (st > 0) {
    const bal = getBalance(req.player.uuid);
    if (bal < st) return res.status(400).json({ error: `Fonduri insuficiente pentru miză (${Math.floor(bal)} coins disponibili).` });
    try { await rconCmd(`essentials:eco take ${req.player.username} ${st}`); } catch { return res.status(500).json({ error: 'Deducere miză eșuată. Ești online?' }); }
  }

  const target_uuid = getUuidByName(target_name);
  db.prepare('INSERT INTO wars (challenger_uuid,challenger_name,target_name,target_uuid,stake) VALUES (?,?,?,?,?)')
    .run(req.player.uuid, req.player.username, target_name, target_uuid || null, st);

  try { await rconCmd(`broadcast &8[&4Razboi&8] &c${req.player.username} &7a declarat razboi impotriva &c${target_name}&7! Miza: &6${st} coins&7. Accepta pe mc.ice4legends.com`); } catch {}
  pushEvent('WAR_DECLARED', req.player.username, target_name, `miză ${st} coins`);
  res.json({ ok: true });
});

app.post('/api/wars/:id/accept', playerAuth, async (req, res) => {
  const war = db.prepare('SELECT * FROM wars WHERE id=?').get(req.params.id);
  if (!war) return res.status(404).json({ error: 'Război negăsit.' });
  if (war.target_name.toLowerCase() !== req.player.username.toLowerCase())
    return res.status(403).json({ error: 'Nu ești ținta acestui război.' });
  if (war.status !== 'pending') return res.status(400).json({ error: 'Războiul nu mai e în așteptare.' });

  if (war.stake > 0) {
    const bal = getBalance(req.player.uuid);
    if (bal < war.stake) return res.status(400).json({ error: `Fonduri insuficiente pentru miză egală (${war.stake} coins).` });
    try { await rconCmd(`essentials:eco take ${req.player.username} ${war.stake}`); } catch { return res.status(500).json({ error: 'Deducere miză eșuată. Ești online?' }); }
  }

  const now = Math.floor(Date.now() / 1000);
  db.prepare('UPDATE wars SET status=?,target_uuid=?,accepted_at=?,ends_at=? WHERE id=?')
    .run('active', req.player.uuid, now, now + 86400, war.id);

  try { await rconCmd(`broadcast &8[&4Razboi&8] &c${req.player.username} &7a acceptat razboiul cu &c${war.challenger_name}&7! 24h de lupte incep acum!`); } catch {}
  pushEvent('WAR_STARTED', war.challenger_name, req.player.username, `miză ${war.stake} coins`);
  res.json({ ok: true });
});

app.post('/api/wars/:id/decline', playerAuth, async (req, res) => {
  const war = db.prepare('SELECT * FROM wars WHERE id=?').get(req.params.id);
  if (!war || war.target_name.toLowerCase() !== req.player.username.toLowerCase() || war.status !== 'pending')
    return res.status(400).json({ error: 'Acțiune invalidă.' });
  if (war.stake > 0) {
    try { await rconCmd(`essentials:eco give ${war.challenger_name} ${war.stake}`); } catch {}
  }
  db.prepare("UPDATE wars SET status='ended',winner_name=? WHERE id=?").run('REFUZAT', war.id);
  pushEvent('WAR_DECLINED', req.player.username, war.challenger_name, '');
  try { await rconCmd(`broadcast &8[&4Razboi&8] &c${req.player.username} &7a refuzat razboiul declarat de &c${war.challenger_name}&7.`); } catch {}
  res.json({ ok: true });
});

// Check ended wars + pay winner
async function resolveWars() {
  const now = Math.floor(Date.now() / 1000);
  const ended = db.prepare("SELECT * FROM wars WHERE status='active' AND ends_at <= ?").all(now);
  for (const w of ended) {
    let winner = null, loser = null;
    if (w.challenger_kills > w.target_kills) { winner = w.challenger_name; loser = w.target_name; }
    else if (w.target_kills > w.challenger_kills) { winner = w.target_name; loser = w.challenger_name; }
    const prize = w.stake * 2;
    if (winner && prize > 0) {
      try { await rconCmd(`essentials:eco give ${winner} ${prize}`); } catch {}
    }
    db.prepare("UPDATE wars SET status='ended',winner_name=? WHERE id=?").run(winner || 'EGALITATE', w.id);
    const detail = winner ? `${winner} câștigă ${prize} coins` : 'Egalitate — mizele returnate';
    if (!winner && w.stake > 0) {
      try { await rconCmd(`essentials:eco give ${w.challenger_name} ${w.stake}`); } catch {}
      try { await rconCmd(`essentials:eco give ${w.target_name} ${w.stake}`); } catch {}
    }
    try { await rconCmd(`broadcast &8[&4Razboi&8] &7Razboiul &c${w.challenger_name} &7vs &c${w.target_name} &7s-a incheiat! ${winner ? `&6${winner} &7castiga!` : '&7Egalitate!'}`); } catch {}
    pushEvent('WAR_ENDED', w.challenger_name, w.target_name, detail);
  }
}
setInterval(resolveWars, 60 * 1000);

// ── Admin: server ─────────────────────────────────────────────
app.post('/api/admin/command', auth, async (req, res) => {
  const { cmd } = req.body;
  if (!cmd) return res.status(400).json({ error: 'Comandă lipsă' });
  // Blocăm comenzi periculoase
  const blocked = ['stop', 'restart'];
  if (blocked.includes(cmd.split(' ')[0].toLowerCase()))
    return res.status(403).json({ error: 'Comandă blocată' });
  try {
    const result = await rconCmd(cmd);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'cmd', cmd);
    res.json({ result });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/broadcast', auth, async (req, res) => {
  const { message } = req.body;
  if (!message) return res.status(400).json({ error: 'Mesaj lipsă' });
  try {
    await rconCmd(`broadcast ${message}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'broadcast', message);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Admin: jucători ───────────────────────────────────────────
app.get('/api/admin/players', auth, async (req, res) => {
  try {
    const raw = await rconCmd('list');
    res.json(parsePlayerList(raw));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/players/:name/kick', auth, async (req, res) => {
  const { name } = req.params;
  const { reason } = req.body;
  try {
    await rconCmd(`kick ${name} ${reason || 'Dat afară de admin'}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'kick', name);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/players/:name/ban', auth, async (req, res) => {
  const { name } = req.params;
  const { reason } = req.body;
  try {
    await rconCmd(`ban ${name} ${reason || 'Banat de admin'}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'ban', name);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/players/:name/unban', auth, async (req, res) => {
  const { name } = req.params;
  try {
    await rconCmd(`pardon ${name}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'unban', name);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/players/:name/op', auth, ownerOnly, async (req, res) => {
  const { name } = req.params;
  try {
    await rconCmd(`op ${name}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'op', name);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/players/:name/teleport', auth, async (req, res) => {
  const { name } = req.params;
  const { target } = req.body;
  try {
    await rconCmd(`tp ${name} ${target || name}`);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/players/:name/give', auth, async (req, res) => {
  const { name } = req.params;
  const { item, amount } = req.body;
  if (!item) return res.status(400).json({ error: 'Item lipsă' });
  try {
    await rconCmd(`give ${name} ${item} ${amount || 1}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'give', `${name} ${item}x${amount||1}`);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Admin: economie ───────────────────────────────────────────
app.get('/api/admin/economy/top', auth, (_req, res) => {
  try { res.json(getTopBalances(10)); }
  catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/economy/give', auth, async (req, res) => {
  const { player, amount } = req.body;
  if (!player || !amount) return res.status(400).json({ error: 'Date incomplete' });
  try {
    await rconCmd(`essentials:eco give ${player} ${amount}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'eco-give', `${player} ${amount}`);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/economy/set', auth, async (req, res) => {
  const { player, amount } = req.body;
  if (!player || amount == null) return res.status(400).json({ error: 'Date incomplete' });
  try {
    await rconCmd(`essentials:eco set ${player} ${amount}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'eco-set', `${player} ${amount}`);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Admin: whitelist ──────────────────────────────────────────
app.post('/api/admin/whitelist/add', auth, async (req, res) => {
  const { player } = req.body;
  try {
    await rconCmd(`whitelist add ${player}`);
    db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.user.username, 'whitelist-add', player);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/admin/whitelist/remove', auth, async (req, res) => {
  const { player } = req.body;
  try {
    await rconCmd(`whitelist remove ${player}`);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Admin: utilizatori panel ──────────────────────────────────
app.get('/api/admin/users', auth, ownerOnly, (_req, res) => {
  const users = db.prepare('SELECT id,username,role,created_at FROM users').all();
  res.json(users);
});

app.post('/api/admin/users', auth, ownerOnly, (req, res) => {
  const { username, password, role } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'Date incomplete' });
  const hash = bcrypt.hashSync(password, 10);
  try {
    db.prepare('INSERT INTO users (username,password,role) VALUES (?,?,?)').run(username, hash, role || 'moderator');
    res.json({ ok: true });
  } catch { res.status(409).json({ error: 'Utilizator existent' }); }
});

app.delete('/api/admin/users/:id', auth, ownerOnly, (req, res) => {
  if (parseInt(req.params.id) === req.user.id) return res.status(400).json({ error: 'Nu poți șterge propriul cont' });
  db.prepare('DELETE FROM users WHERE id=?').run(req.params.id);
  res.json({ ok: true });
});

app.patch('/api/admin/users/:id/password', auth, ownerOnly, (req, res) => {
  const { password } = req.body;
  if (!password) return res.status(400).json({ error: 'Parola lipsă' });
  const hash = bcrypt.hashSync(password, 10);
  db.prepare('UPDATE users SET password=? WHERE id=?').run(hash, req.params.id);
  res.json({ ok: true });
});

// ── Admin: audit log ──────────────────────────────────────────
app.get('/api/admin/audit', auth, (_req, res) => {
  const rows = db.prepare('SELECT * FROM audit_log ORDER BY ts DESC LIMIT 100').all();
  res.json(rows);
});

// ── WebSocket: consolă live ───────────────────────────────────
const wss = new WebSocket.Server({ server, path: '/ws/console' });

wss.on('connection', (ws, req) => {
  // Verificare token din query string
  const url = new URL(req.url, `http://localhost`);
  const token = url.searchParams.get('token');
  let wsUser;
  try {
    // Accept both player tokens (JWT_SECRET + '_player') and legacy admin tokens
    try { wsUser = jwt.verify(token, JWT_SECRET + '_player'); }
    catch { wsUser = jwt.verify(token, JWT_SECRET); }
  } catch {
    ws.close(4001, 'Neautentificat');
    return;
  }
  if (!hasMinRole(wsUser?.role || 'player', 'moderator')) {
    ws.close(4003, 'Acces interzis');
    return;
  }

  ws.send(JSON.stringify({ type: 'info', text: '[panel] Consolă conectată. Citesc log-ul serverului...' }));

  // Tail latest.log
  let logFd = null;
  let position = 0;

  function openLog() {
    try {
      const stat = fs.statSync(MC_LOG_PATH);
      position = stat.size; // start de la sfârșitul fișierului
      logFd = fs.watch(MC_LOG_PATH, () => readNew());
    } catch (e) {
      ws.send(JSON.stringify({ type: 'warn', text: `[panel] Log indisponibil: ${e.message}` }));
      setTimeout(openLog, 5000);
    }
  }

  function readNew() {
    try {
      const stat = fs.statSync(MC_LOG_PATH);
      if (stat.size < position) position = 0; // rotire log
      if (stat.size === position) return;
      const fd = fs.openSync(MC_LOG_PATH, 'r');
      const buf = Buffer.alloc(stat.size - position);
      fs.readSync(fd, buf, 0, buf.length, position);
      fs.closeSync(fd);
      position = stat.size;
      const lines = buf.toString('utf8').split('\n').filter(Boolean);
      for (const line of lines) {
        if (ws.readyState === WebSocket.OPEN)
          ws.send(JSON.stringify({ type: 'log', text: line }));
      }
    } catch {}
  }

  openLog();

  // Comandă de la client → RCON
  ws.on('message', async (data) => {
    try {
      const { cmd } = JSON.parse(data);
      if (!cmd) return;
      const blocked = ['stop'];
      if (blocked.includes(cmd.split(' ')[0].toLowerCase())) {
        ws.send(JSON.stringify({ type: 'warn', text: '[panel] Comandă blocată.' }));
        return;
      }
      const result = await rconCmd(cmd);
      ws.send(JSON.stringify({ type: 'result', text: `> ${cmd}\n${result}` }));
    } catch (e) {
      ws.send(JSON.stringify({ type: 'error', text: e.message }));
    }
  });

  ws.on('close', () => { if (logFd) { try { logFd.close(); } catch {} } });
});

// ── Global log tailer for structured events ───────────────────
(function startGlobalLogTail() {
  let pos = 0;
  function tryOpen() {
    try {
      const stat = fs.statSync(MC_LOG_PATH);
      pos = stat.size;
      fs.watch(MC_LOG_PATH, readGlobal);
    } catch { setTimeout(tryOpen, 10000); }
  }
  function readGlobal() {
    try {
      const stat = fs.statSync(MC_LOG_PATH);
      if (stat.size < pos) pos = 0;
      if (stat.size === pos) return;
      const fd = fs.openSync(MC_LOG_PATH, 'r');
      const buf = Buffer.alloc(stat.size - pos);
      fs.readSync(fd, buf, 0, buf.length, pos);
      fs.closeSync(fd);
      pos = stat.size;
      for (const line of buf.toString('utf8').split('\n')) {
        processLogLine(line.trim());
      }
    } catch {}
  }
  tryOpen();
})();

async function processLogLine(line) {
  // Structured kill events: [ICELEGENDS_KILL] victim_name victim_uuid killer_name killer_uuid
  const killMatch = line.match(/\[ICELEGENDS_KILL\]\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);
  if (killMatch) {
    const [, victimName, victimUuid, killerName, killerUuid] = killMatch;
    pushEvent('KILL', killerName, victimName, '');
    // War kill tracking
    const war = db.prepare("SELECT * FROM wars WHERE status='active' AND ((challenger_name=? AND target_name=?) OR (challenger_name=? AND target_name=?))").get(killerName, victimName, victimName, killerName);
    if (war) {
      if (war.challenger_name === killerName) {
        db.prepare('UPDATE wars SET challenger_kills=challenger_kills+1 WHERE id=?').run(war.id);
      } else {
        db.prepare('UPDATE wars SET target_kills=target_kills+1 WHERE id=?').run(war.id);
      }
    }
    return;
  }
  // Bounty claimed by Skript: [ICELEGENDS_BOUNTY_CLAIMED] victimName killerName amount
  const bClaimMatch = line.match(/\[ICELEGENDS_BOUNTY_CLAIMED\]\s+(\S+)\s+(\S+)\s+(\S+)/);
  if (bClaimMatch) {
    const [, victimName, killerName, amount] = bClaimMatch;
    db.prepare("UPDATE bounties SET status='claimed',claimed_by=?,claimed_at=? WHERE target_name=? AND status='active'")
      .run(killerName, Math.floor(Date.now() / 1000), victimName);
    pushEvent('BOUNTY_CLAIMED', killerName, victimName, `${amount} coins`);
    return;
  }
  // Boss kill broadcast: contains [Sefi] and "a fost invins"
  if (line.includes('[Sefi]') && line.includes('invins')) {
    const m = line.match(/\[Sefi\].*?(\w+)\s+a\s+eliminat\s+(.+?)!/i);
    if (m) pushEvent('BOSS_KILL', m[1], m[2], '');
    else pushEvent('BOSS_KILL', 'Unknown', 'Boss', '');
    return;
  }
  // Quest completion
  if (line.includes('[Contracte]') && line.includes('completat')) {
    const m = line.match(/\[Contracte\]\s+(\w+)/i);
    if (m) pushEvent('QUEST', m[1], '', '');
  }
}

// ════════════════════════════════════════════════════════════
// PHASE 2 — Profiles, Missions, Shop, Achievements
// PHASE 3 — Clans
// PHASE 4 — Analytics, Appeals, Broadcasts
// ════════════════════════════════════════════════════════════

// ── New DB Tables ─────────────────────────────────────────────
db.exec(`
  CREATE TABLE IF NOT EXISTS clans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    tag TEXT UNIQUE NOT NULL,
    owner_uuid TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    description TEXT DEFAULT '',
    created_at INTEGER DEFAULT (unixepoch()),
    wins INTEGER DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS clan_members (
    uuid TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    clan_id INTEGER NOT NULL,
    role TEXT DEFAULT 'member',
    joined_at INTEGER DEFAULT (unixepoch())
  );
  CREATE TABLE IF NOT EXISTS server_analytics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts INTEGER DEFAULT (unixepoch()),
    tps REAL,
    mem_used INTEGER,
    mem_max INTEGER,
    players_online INTEGER
  );
  CREATE TABLE IF NOT EXISTS ban_appeals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    reason TEXT NOT NULL,
    submitted_at INTEGER DEFAULT (unixepoch()),
    status TEXT DEFAULT 'pending',
    reviewed_by TEXT,
    reviewed_at INTEGER,
    staff_note TEXT
  );
  CREATE TABLE IF NOT EXISTS scheduled_broadcasts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message TEXT NOT NULL,
    fire_at INTEGER NOT NULL,
    created_by TEXT NOT NULL,
    sent INTEGER DEFAULT 0,
    created_at INTEGER DEFAULT (unixepoch())
  );
`);

// ── Shop Catalog ──────────────────────────────────────────────
const SHOP_META = {
  oak_log:           { emoji:'🪵', name:'Bustean Stejar',     cat:'Materiale' },
  birch_log:         { emoji:'🪵', name:'Bustean Mesteacăn',  cat:'Materiale' },
  spruce_log:        { emoji:'🪵', name:'Bustean Molid',      cat:'Materiale' },
  stone:             { emoji:'🪨', name:'Piatră',             cat:'Materiale' },
  cobblestone:       { emoji:'🪨', name:'Caldarâm',           cat:'Materiale' },
  iron_ingot:        { emoji:'⚙',  name:'Lingou Fier',        cat:'Metale'    },
  gold_ingot:        { emoji:'🥇', name:'Lingou Aur',         cat:'Metale'    },
  diamond:           { emoji:'💎', name:'Diamant',            cat:'Prețioase' },
  coal:              { emoji:'⬛', name:'Cărbune',             cat:'Materiale' },
  bread:             { emoji:'🍞', name:'Pâine',              cat:'Mâncare'   },
  carrot:            { emoji:'🥕', name:'Morcov',             cat:'Mâncare'   },
  cooked_beef:       { emoji:'🥩', name:'Carne Fiartă',       cat:'Mâncare'   },
  cooked_chicken:    { emoji:'🍗', name:'Pui Fiert',          cat:'Mâncare'   },
  apple:             { emoji:'🍎', name:'Măr',                cat:'Mâncare'   },
  leather:           { emoji:'🐄', name:'Piele',              cat:'Materiale' },
  bone:              { emoji:'🦴', name:'Os',                 cat:'Mob Drops' },
  string:            { emoji:'🕸', name:'Ață',                cat:'Mob Drops' },
  blaze_rod:         { emoji:'🔥', name:'Blaze Rod',          cat:'Mob Drops' },
  slime_ball:        { emoji:'🟢', name:'Bilă Slime',         cat:'Mob Drops' },
  ender_pearl:       { emoji:'🟣', name:'Perlă Ender',        cat:'Mob Drops' },
  wheat_seeds:       { emoji:'🌾', name:'Semințe Grâu',       cat:'Agricultură'},
  bone_meal:         { emoji:'⚪', name:'Făină de Oase',       cat:'Agricultură'},
  sugar_cane:        { emoji:'🌿', name:'Trestie Zahăr',      cat:'Agricultură'},
  cactus:            { emoji:'🌵', name:'Cactus',             cat:'Agricultură'},
  elytra:            { emoji:'🦋', name:'Elytra',             cat:'Rare'      },
  totem_of_undying:  { emoji:'🏺', name:'Totem',              cat:'Rare'      },
  shulker_shell:     { emoji:'📦', name:'Shulker Shell',      cat:'Rare'      },
  name_tag:          { emoji:'🏷', name:'Etichetă Nume',      cat:'Rare'      },
};

function getShopCatalog() {
  const vars = parseSkriptVars();
  return Object.entries(SHOP_META).map(([id, meta]) => ({
    id, ...meta,
    buy:  vars[`shop::buy::${id}`]  || null,
    sell: vars[`shop::sell::${id}`] || null,
    qty:  vars[`shop::qty::${id}`]  || null,
  })).filter(i => i.buy || i.sell);
}

// ── Achievements ──────────────────────────────────────────────
const ACHIEVEMENTS = [
  { id:'first_coins',    icon:'💰', name:'Primii Coins',           desc:'Adună primii 100 coins',              check:(s,_,__)=>s.balance>=100 },
  { id:'rich',           icon:'💎', name:'Bogat',                   desc:'Adună 10,000 coins',                  check:(s,_,__)=>s.balance>=10000 },
  { id:'elite',          icon:'👑', name:'Elite',                   desc:'Adună 100,000 coins',                 check:(s,_,__)=>s.balance>=100000 },
  { id:'skill_novice',   icon:'⭐', name:'Novice',                  desc:'Atinge nivelul 10 la orice abilitate',check:(s,_,__)=>Object.values(s.levels||{}).some(l=>l>=10) },
  { id:'skill_expert',   icon:'🌟', name:'Expert',                  desc:'Atinge nivelul 50 la orice abilitate',check:(s,_,__)=>Object.values(s.levels||{}).some(l=>l>=50) },
  { id:'skill_master',   icon:'💫', name:'Master',                  desc:'Atinge nivelul 100 la orice abilitate',check:(s,_,__)=>Object.values(s.levels||{}).some(l=>l>=100) },
  { id:'bounty_hunter',  icon:'☠',  name:'Vânător de Recompense',   desc:'Pune primul bounty',                  check:(_,db,u)=>!!db.prepare('SELECT id FROM bounties WHERE placer_uuid=?').get(u) },
  { id:'stock_investor', icon:'📈', name:'Investitor',              desc:'Cumpără prima acțiune',               check:(_,db,u)=>!!db.prepare('SELECT id FROM holdings WHERE investor_uuid=? AND shares>0').get(u) },
  { id:'time_sender',    icon:'⏳', name:'Mesager al Timpului',     desc:'Trimite prima capsulă temporală',     check:(_,db,u)=>!!db.prepare('SELECT id FROM time_capsules WHERE from_uuid=?').get(u) },
  { id:'warrior',        icon:'⚔',  name:'Războinic',               desc:'Participă la primul război',          check:(_,db,u)=>!!db.prepare('SELECT id FROM wars WHERE challenger_uuid=? OR target_uuid=?').get(u,u) },
  { id:'clan_founder',   icon:'🏰', name:'Fondator de Clan',        desc:'Creează primul clan',                 check:(_,db,u)=>!!db.prepare('SELECT id FROM clans WHERE owner_uuid=?').get(u) },
  { id:'diplomat',       icon:'🤝', name:'Diplomat',                desc:'Alătură-te unui clan',               check:(_,db,u)=>!!db.prepare('SELECT uuid FROM clan_members WHERE uuid=?').get(u) },
];

function computeAchievements(uuid) {
  const vars = parseSkriptVars();
  const stats = buildStats(uuid, vars);
  return ACHIEVEMENTS.map(a => {
    let unlocked = false;
    try { unlocked = a.check(stats, db, uuid); } catch {}
    return { id: a.id, icon: a.icon, name: a.name, desc: a.desc, unlocked };
  });
}

// ── Missions helper (RCON-first, CSV fallback) ───────────────
async function getTodayMissions() {
  if (rconReady) {
    try {
      const raw = await rconCmd('icl_missions_today');
      const lines = raw.split('\n').map(l => l.replace(/§[0-9a-fk-or]/gi, '').trim()).filter(Boolean);
      let session = 0;
      const missions = [];
      for (const line of lines) {
        if (line.startsWith('SESSION:')) session = parseInt(line.slice(8)) || 0;
        if (line.startsWith('SLOT:')) {
          const [,s,idx,type,desc,amount,reward,diff] = line.split(':');
          missions.push({ idx: parseInt(idx)||0, type, desc, amount: parseInt(amount)||0, reward: parseInt(reward)||0, diff: diff||'Comun' });
        }
      }
      if (missions.length) return { session, missions };
    } catch {}
  }
  // CSV fallback
  const vars = parseSkriptVars();
  const session  = vars['contract::session'] || 0;
  const slots    = [1,2,3].map(i => vars[`contract::slot::${i}`] || 0);
  const missions = slots.filter(Boolean).map(idx => ({
    idx,
    type:   vars[`cpool::${idx}::type`]   || '',
    desc:   vars[`cpool::${idx}::desc`]   || '',
    amount: vars[`cpool::${idx}::amount`] || 0,
    reward: vars[`cpool::${idx}::reward`] || 0,
    diff:   vars[`cpool::${idx}::diff`]   || 'Comun',
  }));
  return { session, missions };
}

async function getPlayerMission(uuid) {
  if (rconReady) {
    try {
      const raw = await rconCmd(`icl_mission_me ${uuid}`);
      const line = raw.replace(/§[0-9a-fk-or]/gi, '').trim();
      if (line === 'MISSION_ME:none') return null;
      if (line.startsWith('MISSION_ME:')) {
        const [,idx,progress,done] = line.split(':');
        const vars = parseSkriptVars();
        const i = parseInt(idx)||0;
        return {
          idx: i,
          type:     vars[`cpool::${i}::type`]   || '',
          desc:     vars[`cpool::${i}::desc`]   || '',
          goal:     vars[`cpool::${i}::amount`] || 0,
          reward:   vars[`cpool::${i}::reward`] || 0,
          diff:     vars[`cpool::${i}::diff`]   || 'Comun',
          progress: parseInt(progress)||0,
          done:     done === 'true',
        };
      }
    } catch {}
  }
  // CSV fallback
  const vars    = parseSkriptVars();
  const session = vars['contract::session'] || 0;
  const pSess   = vars[`contract::player::${uuid}::session`];
  if (pSess !== session) return null;
  const idx     = vars[`contract::player::${uuid}::pool_idx`] || 0;
  return {
    idx,
    type:     vars[`cpool::${idx}::type`]   || '',
    desc:     vars[`cpool::${idx}::desc`]   || '',
    goal:     vars[`cpool::${idx}::amount`] || 0,
    reward:   vars[`cpool::${idx}::reward`] || 0,
    diff:     vars[`cpool::${idx}::diff`]   || 'Comun',
    progress: vars[`contract::player::${uuid}::progress`] || 0,
    done:     vars[`contract::player::${uuid}::done`]     || false,
  };
}

// ── Phase 2: Profile ──────────────────────────────────────────
app.get('/api/player/profile/:username', (req, res) => {
  const username = req.params.username;
  const uuid = getUuidByName(username);
  if (!uuid) return res.status(404).json({ error: 'Jucător negăsit' });
  const vars  = parseSkriptVars();
  const stats = buildStats(uuid, vars);
  const achievements = computeAchievements(uuid);
  const clan  = db.prepare('SELECT c.name,c.tag,cm.role FROM clan_members cm JOIN clans c ON c.id=cm.clan_id WHERE cm.uuid=?').get(uuid);
  const recentWars = db.prepare('SELECT * FROM wars WHERE challenger_uuid=? OR target_uuid=? ORDER BY declared_at DESC LIMIT 5').all(uuid, uuid);
  const acc = db.prepare('SELECT created_at FROM player_accounts WHERE username=? COLLATE NOCASE').get(username);
  // Social: include recent posts + friendship status if caller is authenticated
  let social = { is_friend: false, posts: [] };
  try {
    const token = req.cookies?.player_token;
    if (token) {
      const caller = require('jsonwebtoken').verify(token, process.env.JWT_SECRET + '_player');
      const isFriend = areFriends(caller.username, username) || caller.username.toLowerCase() === username.toLowerCase();
      const posts = isFriend ? db.prepare(`
        SELECT p.id, p.content, p.created_at,
          (SELECT COUNT(*) FROM post_likes WHERE post_id=p.id) as likes
        FROM feed_posts p WHERE p.author_name=? ORDER BY p.created_at DESC LIMIT 20
      `).all(username) : [];
      social = { is_friend: isFriend, posts };
    }
  } catch {}
  res.json({ ...stats, achievements, clan: clan || null, recentWars, member_since: acc?.created_at || null, ...social });
});

// ── Phase 2: Missions ─────────────────────────────────────────
app.get('/api/missions', async (_req, res) => res.json(await getTodayMissions()));

app.get('/api/player/missions/me', playerAuth, async (req, res) => {
  const [mission, today] = await Promise.all([getPlayerMission(req.player.uuid), getTodayMissions()]);
  res.json({ today, active: mission });
});

app.post('/api/player/missions/accept', playerAuth, async (req, res) => {
  const slot = parseInt(req.body?.slot);
  if (!slot || slot < 1 || slot > 3) return res.status(400).json({ error: 'Slot invalid. Alege 1, 2 sau 3.' });
  const existing = await getPlayerMission(req.player.uuid);
  if (existing) return res.status(409).json({ error: 'Ai deja un contract activ azi.' });
  try {
    const raw = await rconCmd(`icl_accept_contract ${req.player.uuid} ${slot}`);
    const line = raw.replace(/§[0-9a-fk-or]/gi, '').trim();
    if (line.startsWith('ACCEPT_ERR:already_accepted')) return res.status(409).json({ error: 'Ai deja un contract activ azi.' });
    if (line.startsWith('ACCEPT_ERR:no_session'))      return res.status(503).json({ error: 'Contractele zilei nu sunt inca incarcate.' });
    if (line.startsWith('ACCEPT_ERR:invalid_slot'))    return res.status(400).json({ error: 'Slot invalid.' });
    if (line.startsWith('ACCEPT_OK:')) {
      const [,idx,desc,reward] = line.split(':');
      pushEvent('QUEST', req.player.username, '', `Contract acceptat: ${desc} (+${reward} coins)`);
      return res.json({ ok: true, idx: parseInt(idx)||0, desc, reward: parseInt(reward)||0 });
    }
    return res.status(503).json({ error: 'Raspuns neasteptat de la server.' });
  } catch (e) {
    return res.status(503).json({ error: 'Serverul nu este disponibil.' });
  }
});

// ── Phase 2: Shop ─────────────────────────────────────────────
app.get('/api/shop', (_req, res) => res.json(getShopCatalog()));

app.post('/api/shop/buy', playerAuth, async (req, res) => {
  const { itemId, qty } = req.body;
  const amount = Math.max(1, Math.min(64, parseInt(qty) || 1));
  const meta = SHOP_META[itemId];
  if (!meta) return res.status(400).json({ error: 'Item inexistent' });
  const catalog = getShopCatalog();
  const item = catalog.find(i => i.id === itemId);
  if (!item || item.buy == null) return res.status(400).json({ error: 'Item nu poate fi cumpărat' });
  const totalCost = item.buy * amount;
  const username = req.player.username;
  const uuid = getUuidByName(username);
  if (!uuid) return res.status(404).json({ error: 'Cont negăsit' });
  const vars = parseSkriptVars();
  const stats = buildStats(uuid, vars);
  if ((stats.balance || 0) < totalCost)
    return res.status(400).json({ error: `Insuficienți coins. Ai ${Math.floor(stats.balance || 0).toLocaleString('ro-RO')} / ${totalCost.toLocaleString('ro-RO')} necesari.` });
  try {
    await rconCmd(`essentials:eco take ${username} ${totalCost}`);
    try {
      await rconCmd(`give ${username} ${itemId} ${amount}`);
    } catch {
      await rconCmd(`essentials:eco give ${username} ${totalCost}`);
      return res.status(503).json({ error: 'Trebuie să fii online în joc pentru a cumpăra din portal.' });
    }
    res.json({ ok: true, spent: totalCost, item: meta.name, qty: amount });
  } catch {
    res.status(503).json({ error: 'Serverul nu este disponibil momentan.' });
  }
});

// ── Phase 2: Achievements ─────────────────────────────────────
app.get('/api/player/achievements', playerAuth, (req, res) => {
  res.json(computeAchievements(req.player.uuid));
});

// ── Phase 3: Clans ────────────────────────────────────────────
app.get('/api/clans', (_req, res) => {
  const clans = db.prepare(`
    SELECT c.*, COUNT(cm.uuid) as members
    FROM clans c LEFT JOIN clan_members cm ON cm.clan_id=c.id
    GROUP BY c.id ORDER BY members DESC, c.created_at ASC`).all();
  res.json(clans);
});

app.get('/api/clans/:id', (req, res) => {
  const clan = db.prepare('SELECT * FROM clans WHERE id=?').get(req.params.id);
  if (!clan) return res.status(404).json({ error: 'Clan negăsit' });
  const members = db.prepare('SELECT uuid,username,role,joined_at FROM clan_members WHERE clan_id=? ORDER BY role DESC, joined_at ASC').all(req.params.id);
  res.json({ ...clan, members });
});

app.get('/api/player/clan', playerAuth, (req, res) => {
  const cm = db.prepare('SELECT c.* FROM clan_members cm JOIN clans c ON c.id=cm.clan_id WHERE cm.uuid=?').get(req.player.uuid);
  if (!cm) return res.json(null);
  const members = db.prepare('SELECT uuid,username,role,joined_at FROM clan_members WHERE clan_id=? ORDER BY role DESC').all(cm.id);
  res.json({ ...cm, members });
});

app.post('/api/clans', playerAuth, async (req, res) => {
  const { name, tag, description } = req.body;
  if (!name || !tag) return res.status(400).json({ error: 'Nume și tag obligatorii' });
  if (name.length < 3 || name.length > 30) return res.status(400).json({ error: 'Nume: 3-30 caractere' });
  if (tag.length < 2 || tag.length > 5) return res.status(400).json({ error: 'Tag: 2-5 caractere' });
  const existing = db.prepare('SELECT uuid FROM clan_members WHERE uuid=?').get(req.player.uuid);
  if (existing) return res.status(409).json({ error: 'Ești deja într-un clan' });
  try {
    const info = db.prepare('INSERT INTO clans (name,tag,owner_uuid,owner_name,description) VALUES (?,?,?,?,?)').run(name.trim(), tag.toUpperCase(), req.player.uuid, req.player.username, description||'');
    db.prepare('INSERT INTO clan_members (uuid,username,clan_id,role) VALUES (?,?,?,?)').run(req.player.uuid, req.player.username, info.lastInsertRowid, 'leader');
    pushEvent('CLAN_CREATE', req.player.username, name, tag);
    try { await rconCmd(`broadcast &8[&6Clan&8] &b${req.player.username} &7a creat clanul &6${name} &8[&e${tag.toUpperCase()}&8]&7!`); } catch {}
    res.json({ ok: true, id: info.lastInsertRowid });
  } catch (e) {
    if (e.message.includes('UNIQUE')) return res.status(409).json({ error: 'Clan cu același nume sau tag există deja' });
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/clans/:id/join', playerAuth, async (req, res) => {
  const clan = db.prepare('SELECT * FROM clans WHERE id=?').get(req.params.id);
  if (!clan) return res.status(404).json({ error: 'Clan negăsit' });
  if (db.prepare('SELECT uuid FROM clan_members WHERE uuid=?').get(req.player.uuid))
    return res.status(409).json({ error: 'Ești deja într-un clan' });
  db.prepare('INSERT INTO clan_members (uuid,username,clan_id) VALUES (?,?,?)').run(req.player.uuid, req.player.username, clan.id);
  try { await rconCmd(`broadcast &8[&6Clan&8] &b${req.player.username} &7s-a alaturat clanului &6${clan.name} &8[&e${clan.tag}&8]&7!`); } catch {}
  res.json({ ok: true });
});

app.post('/api/clans/:id/leave', playerAuth, async (req, res) => {
  const cm = db.prepare('SELECT * FROM clan_members WHERE uuid=? AND clan_id=?').get(req.player.uuid, req.params.id);
  if (!cm) return res.status(404).json({ error: 'Nu ești în acest clan' });
  const clan = db.prepare('SELECT * FROM clans WHERE id=?').get(req.params.id);
  if (clan.owner_uuid === req.player.uuid) {
    const others = db.prepare('SELECT uuid FROM clan_members WHERE clan_id=? AND uuid!=?').all(req.params.id, req.player.uuid);
    if (others.length) return res.status(400).json({ error: 'Transferă leadershipul înainte de a pleca' });
    db.prepare('DELETE FROM clan_members WHERE clan_id=?').run(req.params.id);
    db.prepare('DELETE FROM clans WHERE id=?').run(req.params.id);
    try { await rconCmd(`broadcast &8[&6Clan&8] &7Clanul &6${clan.name} &7a fost desfiintat de liderul sau.`); } catch {}
    return res.json({ ok: true, dissolved: true });
  }
  db.prepare('DELETE FROM clan_members WHERE uuid=?').run(req.player.uuid);
  try { await rconCmd(`broadcast &8[&6Clan&8] &b${req.player.username} &7a parasit clanul &6${clan.name}&7.`); } catch {}
  res.json({ ok: true });
});

// ── Phase 4: Server Analytics ─────────────────────────────────
app.get('/api/analytics', (_req, res) => {
  const rows = db.prepare('SELECT * FROM server_analytics ORDER BY ts DESC LIMIT 288').all();
  res.json(rows.reverse());
});

async function collectAnalytics() {
  if (!rconReady) return;
  try {
    const [tpsRaw, listRaw, gcRaw] = await Promise.all([
      rconCmd('tps').catch(() => ''),
      rconCmd('list').catch(() => ''),
      rconCmd('gc').catch(() => '')
    ]);
    const strip = s => s.replace(/§[0-9a-fk-or]/gi, '');
    const nums = strip(tpsRaw).match(/[\d.]+/g) || [];
    const tps = nums.length >= 3 ? parseFloat(nums[nums.length - 3]) : 0;
    const gcClean  = strip(gcRaw);
    const memM     = gcClean.match(/Memorie libera[^:]*:\s*([\d,]+)\s*MB/i);
    const memMaxM  = gcClean.match(/Memorie maxima[^:]*:\s*([\d,]+)\s*MB/i);
    const memFree  = memM    ? parseInt(memM[1].replace(/,/g,''))    : 0;
    const memMax   = memMaxM ? parseInt(memMaxM[1].replace(/,/g,'')) : 0;
    const players  = parsePlayerList(listRaw).length;
    db.prepare('INSERT INTO server_analytics (tps,mem_used,mem_max,players_online) VALUES (?,?,?,?)').run(tps, memMax-memFree, memMax, players);
    db.prepare('DELETE FROM server_analytics WHERE id NOT IN (SELECT id FROM server_analytics ORDER BY id DESC LIMIT 2016)').run();
  } catch {}
}
setInterval(collectAnalytics, 5 * 60 * 1000);
collectAnalytics();

// ── Phase 4: Ban Appeals ──────────────────────────────────────
app.post('/api/appeals', (req, res) => {
  const { username, reason } = req.body;
  if (!username || !reason) return res.status(400).json({ error: 'Completează toate câmpurile' });
  if (reason.length < 20) return res.status(400).json({ error: 'Motivul trebuie să aibă minim 20 caractere' });
  db.prepare('INSERT INTO ban_appeals (username,reason) VALUES (?,?)').run(username.trim(), reason.trim());
  res.json({ ok: true });
});

app.get('/api/appeals/status/:username', (req, res) => {
  const appeal = db.prepare(
    'SELECT id,status,staff_note,submitted_at,reviewed_at FROM ban_appeals WHERE username=? ORDER BY submitted_at DESC LIMIT 1'
  ).get(req.params.username);
  if (!appeal) return res.json({ found: false });
  res.json({ found: true, ...appeal });
});

app.get('/api/player/admin/appeals', playerAuth, playerAdminAuth('moderator'), (_req, res) => {
  res.json(db.prepare('SELECT * FROM ban_appeals ORDER BY submitted_at DESC LIMIT 50').all());
});

app.put('/api/player/admin/appeals/:id', playerAuth, playerAdminAuth('moderator'), (req, res) => {
  const { status, staff_note } = req.body;
  if (!['approved','rejected','pending'].includes(status)) return res.status(400).json({ error: 'Status invalid' });
  db.prepare('UPDATE ban_appeals SET status=?,reviewed_by=?,reviewed_at=unixepoch(),staff_note=? WHERE id=?')
    .run(status, req.player.username, staff_note||'', req.params.id);
  if (status === 'approved') {
    const appeal = db.prepare('SELECT username FROM ban_appeals WHERE id=?').get(req.params.id);
    if (appeal) rconCmd(`essentials:unban ${appeal.username}`).catch(() => rconCmd(`pardon ${appeal.username}`).catch(()=>{}));
  }
  db.prepare('INSERT INTO audit_log (admin,action,detail) VALUES (?,?,?)').run(req.player.username, 'appeal-'+status, req.params.id);
  res.json({ ok: true });
});

// ── Phase 4: Scheduled Broadcasts ────────────────────────────
app.get('/api/player/admin/broadcasts', playerAuth, playerAdminAuth('moderator'), (_req, res) => {
  res.json(db.prepare('SELECT * FROM scheduled_broadcasts ORDER BY fire_at ASC').all());
});

app.post('/api/player/admin/broadcasts', playerAuth, playerAdminAuth('moderator'), (req, res) => {
  const { message, fire_at } = req.body;
  if (!message || !fire_at) return res.status(400).json({ error: 'Date incomplete' });
  db.prepare('INSERT INTO scheduled_broadcasts (message,fire_at,created_by) VALUES (?,?,?)').run(message, parseInt(fire_at), req.player.username);
  res.json({ ok: true });
});

app.delete('/api/player/admin/broadcasts/:id', playerAuth, playerAdminAuth('moderator'), (req, res) => {
  db.prepare('DELETE FROM scheduled_broadcasts WHERE id=? AND sent=0').run(req.params.id);
  res.json({ ok: true });
});

async function checkScheduledBroadcasts() {
  const now  = Math.floor(Date.now() / 1000);
  const due  = db.prepare('SELECT * FROM scheduled_broadcasts WHERE sent=0 AND fire_at<=?').all(now);
  for (const b of due) {
    try { await rconCmd(`broadcast ${b.message}`); } catch {}
    db.prepare('UPDATE scheduled_broadcasts SET sent=1 WHERE id=?').run(b.id);
    pushEvent('BROADCAST', b.created_by, '', b.message);
  }
}
setInterval(checkScheduledBroadcasts, 60 * 1000);

// ════════════════════════════════════════════════════════════
// PHASE 5 — Friends, Feed, Staff Applications
// ════════════════════════════════════════════════════════════

db.exec(`
  CREATE TABLE IF NOT EXISTS friends (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_name TEXT NOT NULL,
    to_name   TEXT NOT NULL,
    status    TEXT DEFAULT 'pending',
    created_at INTEGER DEFAULT (unixepoch()),
    UNIQUE(from_name, to_name)
  );
  CREATE TABLE IF NOT EXISTS feed_posts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    author_name TEXT NOT NULL,
    content     TEXT NOT NULL CHECK(length(content) <= 280),
    type        TEXT DEFAULT 'post',
    created_at  INTEGER DEFAULT (unixepoch())
  );
  CREATE TABLE IF NOT EXISTS post_likes (
    post_id     INTEGER NOT NULL,
    player_name TEXT NOT NULL,
    PRIMARY KEY (post_id, player_name)
  );
  CREATE TABLE IF NOT EXISTS staff_applications (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    username    TEXT NOT NULL,
    age         INTEGER,
    position    TEXT NOT NULL,
    about       TEXT NOT NULL,
    experience  TEXT NOT NULL,
    discord     TEXT NOT NULL,
    status      TEXT DEFAULT 'pending',
    reviewed_by TEXT,
    staff_note  TEXT,
    created_at  INTEGER DEFAULT (unixepoch())
  );
`);

// ── Helpers ───────────────────────────────────────────────────
function getFriendNames(playerName) {
  const rows = db.prepare(`
    SELECT CASE WHEN from_name=? THEN to_name ELSE from_name END as name
    FROM friends WHERE status='accepted' AND (from_name=? OR to_name=?)
  `).all(playerName, playerName, playerName);
  return rows.map(r => r.name);
}

function areFriends(a, b) {
  return !!db.prepare(`SELECT 1 FROM friends WHERE status='accepted' AND
    ((from_name=? AND to_name=?) OR (from_name=? AND to_name=?))`).get(a,b,b,a);
}

// ── Friends API ───────────────────────────────────────────────

// GET /api/player/friends — my accepted friends + pending requests
app.get('/api/player/friends', playerAuth, (req, res) => {
  const me = req.player.username;
  const accepted = db.prepare(`
    SELECT id,
      CASE WHEN from_name=? THEN to_name ELSE from_name END as name,
      created_at
    FROM friends WHERE status='accepted' AND (from_name=? OR to_name=?)
    ORDER BY created_at DESC
  `).all(me, me, me);
  const incoming = db.prepare(`
    SELECT id, from_name as name, created_at FROM friends
    WHERE to_name=? AND status='pending' ORDER BY created_at DESC
  `).all(me);
  const outgoing = db.prepare(`
    SELECT id, to_name as name, created_at FROM friends
    WHERE from_name=? AND status='pending' ORDER BY created_at DESC
  `).all(me);
  res.json({ accepted, incoming, outgoing });
});

// POST /api/player/friends/add
app.post('/api/player/friends/add', playerAuth, (req, res) => {
  const me = req.player.username;
  const { target } = req.body;
  if (!target || target === me) return res.status(400).json({ error: 'Invalid target' });
  const acc = db.prepare("SELECT username FROM player_accounts WHERE username=? COLLATE NOCASE").get(target);
  if (!acc) return res.status(404).json({ error: 'Jucătorul nu există' });
  const exists = db.prepare(`SELECT * FROM friends WHERE
    (from_name=? AND to_name=?) OR (from_name=? AND to_name=?)`).get(me, acc.username, acc.username, me);
  if (exists) return res.status(409).json({ error: 'Cerere existentă sau deja prieteni' });
  const r = db.prepare("INSERT INTO friends (from_name, to_name) VALUES (?,?)").run(me, acc.username);
  res.json({ id: r.lastInsertRowid, to: acc.username, status: 'pending' });
});

// POST /api/player/friends/accept/:id
app.post('/api/player/friends/accept/:id', playerAuth, (req, res) => {
  const me = req.player.username;
  const req2 = db.prepare("SELECT * FROM friends WHERE id=? AND to_name=? AND status='pending'").get(req.params.id, me);
  if (!req2) return res.status(404).json({ error: 'Cerere negăsită' });
  db.prepare("UPDATE friends SET status='accepted' WHERE id=?").run(req2.id);
  res.json({ ok: true });
});

// DELETE /api/player/friends/:name — remove friend or decline request
app.delete('/api/player/friends/:name', playerAuth, (req, res) => {
  const me = req.player.username;
  const other = req.params.name;
  db.prepare(`DELETE FROM friends WHERE
    (from_name=? AND to_name=?) OR (from_name=? AND to_name=?)`).run(me, other, other, me);
  res.json({ ok: true });
});

// ── Feed API ──────────────────────────────────────────────────

// GET /api/player/feed — own posts + friends' posts, newest first
app.get('/api/player/feed', playerAuth, (req, res) => {
  const me = req.player.username;
  const friends = getFriendNames(me);
  const names = [me, ...friends];
  const placeholders = names.map(() => '?').join(',');
  const posts = db.prepare(`
    SELECT p.id, p.author_name, p.content, p.type, p.created_at,
      (SELECT COUNT(*) FROM post_likes WHERE post_id=p.id) as likes,
      (SELECT COUNT(*) FROM post_likes WHERE post_id=p.id AND player_name=?) as liked_by_me
    FROM feed_posts p
    WHERE p.author_name IN (${placeholders})
    ORDER BY p.created_at DESC LIMIT 50
  `).all(me, ...names);
  res.json(posts);
});

// POST /api/player/feed/post — create post
app.post('/api/player/feed/post', playerAuth, (req, res) => {
  const me = req.player.username;
  const { content } = req.body;
  if (!content || content.trim().length === 0) return res.status(400).json({ error: 'Post gol' });
  if (content.length > 280) return res.status(400).json({ error: 'Max 280 caractere' });
  const r = db.prepare("INSERT INTO feed_posts (author_name, content) VALUES (?,?)").run(me, content.trim());
  res.json({ id: r.lastInsertRowid, author_name: me, content: content.trim(), created_at: Math.floor(Date.now()/1000), likes: 0, liked_by_me: 0 });
});

// POST /api/player/feed/like/:id — toggle like
app.post('/api/player/feed/like/:id', playerAuth, (req, res) => {
  const me = req.player.username;
  const postId = parseInt(req.params.id);
  const already = db.prepare("SELECT 1 FROM post_likes WHERE post_id=? AND player_name=?").get(postId, me);
  if (already) {
    db.prepare("DELETE FROM post_likes WHERE post_id=? AND player_name=?").run(postId, me);
    res.json({ liked: false });
  } else {
    db.prepare("INSERT OR IGNORE INTO post_likes (post_id, player_name) VALUES (?,?)").run(postId, me);
    res.json({ liked: true });
  }
});

// DELETE /api/player/feed/:id — delete own post
app.delete('/api/player/feed/:id', playerAuth, (req, res) => {
  const me = req.player.username;
  db.prepare("DELETE FROM feed_posts WHERE id=? AND author_name=?").run(parseInt(req.params.id), me);
  db.prepare("DELETE FROM post_likes WHERE post_id=?").run(parseInt(req.params.id));
  res.json({ ok: true });
});


// ── Staff Applications — public ───────────────────────────────

// POST /api/apply
app.post('/api/apply', (req, res) => {
  const { username, age, position, about, experience, discord } = req.body;
  if (!username || !position || !about || !experience || !discord)
    return res.status(400).json({ error: 'Completează toate câmpurile obligatorii' });
  if (!['helper','moderator','admin'].includes(position))
    return res.status(400).json({ error: 'Poziție invalidă' });
  if (about.length < 30) return res.status(400).json({ error: 'Secțiunea "Despre tine" e prea scurtă (min 30 caractere)' });
  const recent = db.prepare("SELECT id FROM staff_applications WHERE username=? AND created_at > unixepoch()-2592000").get(username);
  if (recent) return res.status(429).json({ error: 'Ai aplicat deja în ultima lună' });
  db.prepare("INSERT INTO staff_applications (username,age,position,about,experience,discord) VALUES (?,?,?,?,?,?)")
    .run(username, parseInt(age)||0, position, about, experience, discord);
  res.json({ ok: true, message: 'Aplicația a fost trimisă! Te vom contacta pe Discord.' });
});

// ── Staff Applications — admin ────────────────────────────────

app.get('/api/admin/applications', auth, ownerOnly, (req, res) => {
  const apps = db.prepare("SELECT * FROM staff_applications ORDER BY created_at DESC").all();
  res.json(apps);
});

app.patch('/api/admin/applications/:id', auth, ownerOnly, async (req, res) => {
  const { status, staff_note } = req.body;
  if (!['pending','accepted','declined'].includes(status))
    return res.status(400).json({ error: 'Status invalid' });
  const app2 = db.prepare("SELECT username,position FROM staff_applications WHERE id=?").get(req.params.id);
  db.prepare("UPDATE staff_applications SET status=?,reviewed_by=?,staff_note=? WHERE id=?")
    .run(status, req.user.username, staff_note||'', req.params.id);
  if (app2) {
    if (status === 'accepted') {
      try { await rconCmd(`broadcast &8[&a&lSTAFF&8] &b${app2.username} &7a fost acceptat ca &a${app2.position} &7pe IceLegends!`); } catch {}
      try { await rconCmd(`tell ${app2.username} &a[IceLegends] Aplicatia ta de ${app2.position} a fost ACCEPTATA! Bun venit in echipa!`); } catch {}
    } else if (status === 'declined') {
      try { await rconCmd(`tell ${app2.username} &c[IceLegends] Aplicatia ta de ${app2.position} a fost respinsa. Poti aplica din nou dupa 30 zile.`); } catch {}
    }
  }
  res.json({ ok: true });
});

// ── Start ─────────────────────────────────────────────────────
server.listen(PORT, () => console.log(`[panel] Running on :${PORT}`));
