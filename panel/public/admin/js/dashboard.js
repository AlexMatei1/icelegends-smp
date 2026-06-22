'use strict';

let currentUser = null;
let ws = null;
let wsToken = null;

// ── Auth check ────────────────────────────────────────────────
(async () => {
  try {
    const r = await fetch('/api/auth/me');
    if (!r.ok) { window.location.href = '/admin/login.html'; return; }
    const d = await r.json();
    currentUser = d;
    document.getElementById('me-name').textContent = d.username;
    if (d.role === 'owner') {
      document.querySelectorAll('.owner-only').forEach(el => el.style.display = 'flex');
    }
    // Extrage token din cookie (pentru WS)
    wsToken = document.cookie.match(/token=([^;]+)/)?.[1];
    initDashboard();
    initConsole();
  } catch {
    window.location.href = '/admin/login.html';
  }
})();

// ── Navigation ────────────────────────────────────────────────
function showPage(name) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  document.getElementById(`page-${name}`)?.classList.add('active');
  document.querySelectorAll('.nav-item').forEach(n => {
    if (n.textContent.toLowerCase().includes(name.slice(0,4))) n.classList.add('active');
  });
  // Lazy load pages
  if (name === 'players') loadPlayers();
  if (name === 'economy') loadEconomy();
  if (name === 'audit')   loadAudit();
  if (name === 'users')   loadUsers();
}

// ── Toast ─────────────────────────────────────────────────────
function toast(msg, type = 'ok') {
  const t = document.getElementById('toast');
  t.textContent = msg; t.className = `show ${type}`;
  setTimeout(() => t.classList.remove('show'), 3000);
}

// ── API helpers ───────────────────────────────────────────────
async function api(method, url, body) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  const r = await fetch(url, opts);
  return r.json();
}

// ── Dashboard ─────────────────────────────────────────────────
async function initDashboard() {
  const d = await api('GET', '/api/status');
  document.getElementById('d-status').textContent  = d.online ? 'ONLINE' : 'OFFLINE';
  document.getElementById('d-status').className    = `card-val ${d.online ? 'green' : 'red'}`;
  document.getElementById('d-players').textContent = d.players ?? '—';
  document.getElementById('d-tps').textContent     = d.tps?.toFixed(1) ?? '—';
  document.getElementById('d-max').textContent     = d.max ?? '—';
}
setInterval(initDashboard, 30000);

async function quickCmd(cmd) {
  const res = await api('POST', '/api/admin/command', { cmd });
  const el = document.getElementById('quick-result');
  el.style.display = 'block';
  el.textContent = res.result || res.error || '(fără răspuns)';
}

// ── Consolă live (WebSocket) ──────────────────────────────────
function initConsole() {
  if (!wsToken) return;
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  ws = new WebSocket(`${proto}://${location.host}/ws/console?token=${wsToken}`);

  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    appendConsole(msg.text, msg.type);
  };

  ws.onclose = () => {
    appendConsole('[panel] WebSocket deconectat. Reîncerc în 5s...', 'warn');
    setTimeout(initConsole, 5000);
  };

  ws.onerror = () => appendConsole('[panel] Eroare WebSocket.', 'error');
}

function appendConsole(text, type = 'log') {
  const box = document.getElementById('console-out');
  if (!box) return;
  const line = document.createElement('div');
  line.className = type;
  line.textContent = text;
  box.appendChild(line);
  // Limitează la 500 linii
  while (box.childElementCount > 500) box.removeChild(box.firstChild);
  box.scrollTop = box.scrollHeight;
}

function sendCmd() {
  const input = document.getElementById('console-in');
  const cmd = input.value.trim();
  if (!cmd || !ws || ws.readyState !== WebSocket.OPEN) return;
  ws.send(JSON.stringify({ cmd }));
  input.value = '';
}

// ── Jucători ──────────────────────────────────────────────────
async function loadPlayers() {
  const players = await api('GET', '/api/admin/players');
  const tbody = document.getElementById('players-tbody');
  if (!Array.isArray(players) || players.length === 0) {
    tbody.innerHTML = '<tr><td colspan="2" style="color:var(--text-muted)">Niciun jucător online.</td></tr>';
    return;
  }
  tbody.innerHTML = players.map(name => `
    <tr>
      <td style="display:flex;align-items:center;gap:0.6rem">
        <img src="https://crafatar.com/avatars/${name}?size=24&overlay" style="width:24px;height:24px;border-radius:3px;image-rendering:pixelated" onerror="this.style.display='none'">
        <strong>${name}</strong>
      </td>
      <td>
        <button class="action-btn ab-kick" onclick="kickPlayer('${name}')">Kick</button>
        <button class="action-btn ab-ban"  onclick="banPlayer('${name}')">Ban</button>
        <button class="action-btn ab-tp"   onclick="tpToPlayer('${name}')">TP</button>
      </td>
    </tr>`).join('');
}

async function kickPlayer(name) {
  const reason = prompt(`Motivul kick-ului pentru ${name}:`);
  if (reason === null) return;
  const d = await api('POST', `/api/admin/players/${name}/kick`, { reason });
  d.ok ? toast(`${name} a fost dat afară.`) : toast(d.error, 'err');
  loadPlayers();
}

async function banPlayer(name) {
  const reason = prompt(`Motivul ban-ului pentru ${name}:`);
  if (reason === null) return;
  const d = await api('POST', `/api/admin/players/${name}/ban`, { reason });
  d.ok ? toast(`${name} a fost banat.`) : toast(d.error, 'err');
  loadPlayers();
}

async function tpToPlayer(name) {
  const d = await api('POST', `/api/admin/players/${name}/teleport`, { target: currentUser.username });
  d.ok ? toast(`Teleportat la ${name}.`) : toast(d.error, 'err');
}

// ── Economie ──────────────────────────────────────────────────
async function loadEconomy() {
  const data = await api('GET', '/api/admin/economy/top');
  const tbody = document.getElementById('eco-tbody');
  if (!Array.isArray(data) || data.length === 0) {
    tbody.innerHTML = '<tr><td colspan="3" style="color:var(--text-muted)">Fără date.</td></tr>';
    return;
  }
  tbody.innerHTML = data.map((p, i) => `
    <tr>
      <td style="color:var(--text-muted)">#${i+1}</td>
      <td><strong>${p.name}</strong></td>
      <td style="color:var(--accent);font-family:monospace">${p.balance.toLocaleString('ro-RO')} coins</td>
    </tr>`).join('');
}

async function ecoGive() {
  const player = document.getElementById('eco-player').value.trim();
  const amount = document.getElementById('eco-amount').value;
  if (!player || !amount) return toast('Completează jucătorul și suma!', 'err');
  const d = await api('POST', '/api/admin/economy/give', { player, amount });
  d.ok ? toast(`+${amount} coins → ${player}`) : toast(d.error, 'err');
  loadEconomy();
}

async function ecoSet() {
  const player = document.getElementById('eco-player').value.trim();
  const amount = document.getElementById('eco-amount').value;
  if (!player || !amount) return toast('Completează jucătorul și suma!', 'err');
  const d = await api('POST', '/api/admin/economy/set', { player, amount });
  d.ok ? toast(`Balance ${player} = ${amount} coins`) : toast(d.error, 'err');
  loadEconomy();
}

// ── Whitelist ─────────────────────────────────────────────────
async function whitelistAdd() {
  const player = document.getElementById('wl-player').value.trim();
  if (!player) return toast('Introdu un nume!', 'err');
  const d = await api('POST', '/api/admin/whitelist/add', { player });
  const el = document.getElementById('wl-result');
  if (d.ok) { toast(`${player} adăugat pe whitelist.`); el.textContent = `✓ ${player} adăugat.`; el.style.color = 'var(--online)'; }
  else { toast(d.error, 'err'); el.textContent = d.error; el.style.color = 'var(--danger)'; }
}

async function whitelistRemove() {
  const player = document.getElementById('wl-player').value.trim();
  if (!player) return toast('Introdu un nume!', 'err');
  const d = await api('POST', '/api/admin/whitelist/remove', { player });
  const el = document.getElementById('wl-result');
  if (d.ok) { toast(`${player} eliminat din whitelist.`); el.textContent = `✓ ${player} eliminat.`; el.style.color = 'var(--online)'; }
  else { toast(d.error, 'err'); el.textContent = d.error; el.style.color = 'var(--danger)'; }
}

// ── Broadcast ─────────────────────────────────────────────────
async function doBroadcast() {
  const msg = document.getElementById('bc-msg').value.trim();
  if (!msg) return toast('Mesajul e gol!', 'err');
  const d = await api('POST', '/api/admin/broadcast', { message: msg });
  if (d.ok) { toast('Mesaj trimis!'); document.getElementById('bc-msg').value = ''; }
  else toast(d.error, 'err');
}

// ── Audit log ─────────────────────────────────────────────────
async function loadAudit() {
  const rows = await api('GET', '/api/admin/audit');
  const tbody = document.getElementById('audit-tbody');
  if (!Array.isArray(rows) || rows.length === 0) {
    tbody.innerHTML = '<tr><td colspan="4" style="color:var(--text-muted)">Niciun audit log.</td></tr>';
    return;
  }
  tbody.innerHTML = rows.map(r => `
    <tr>
      <td style="color:var(--text-muted);font-size:0.8rem">${new Date(r.ts*1000).toLocaleString('ro-RO')}</td>
      <td><strong>${r.admin}</strong></td>
      <td><span class="badge badge-mod">${r.action}</span></td>
      <td style="font-family:monospace;font-size:0.82rem">${r.detail || '—'}</td>
    </tr>`).join('');
}

// ── Utilizatori (owner only) ──────────────────────────────────
async function loadUsers() {
  if (currentUser?.role !== 'owner') return;
  const users = await api('GET', '/api/admin/users');
  const tbody = document.getElementById('users-tbody');
  tbody.innerHTML = users.map(u => `
    <tr>
      <td><strong>${u.username}</strong></td>
      <td><span class="badge ${u.role==='owner'?'badge-owner':'badge-mod'}">${u.role}</span></td>
      <td style="font-size:0.8rem;color:var(--text-muted)">${new Date(u.created_at*1000).toLocaleDateString('ro-RO')}</td>
      <td>${u.username !== currentUser.username ? `<button class="action-btn ab-del" onclick="deleteUser(${u.id},'${u.username}')">Șterge</button>` : '—'}</td>
    </tr>`).join('');
}

async function addUser() {
  const username = document.getElementById('new-username').value.trim();
  const password = document.getElementById('new-password').value;
  const role     = document.getElementById('new-role').value;
  if (!username || !password) return toast('Completează username și parola!', 'err');
  const d = await api('POST', '/api/admin/users', { username, password, role });
  d.ok ? toast(`User ${username} creat.`) : toast(d.error, 'err');
  loadUsers();
}

async function deleteUser(id, name) {
  if (!confirm(`Ștergi userul "${name}"?`)) return;
  const d = await api('DELETE', `/api/admin/users/${id}`);
  d.ok ? toast(`User ${name} șters.`) : toast(d.error, 'err');
  loadUsers();
}

// ── Logout ────────────────────────────────────────────────────
async function logout() {
  await api('POST', '/api/auth/logout');
  window.location.href = '/admin/login.html';
}
