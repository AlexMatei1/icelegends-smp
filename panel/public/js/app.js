'use strict';

/* ── Canvas particle system (snowflakes + aurora) ──────────── */
function initCanvas() {
  const canvas = document.getElementById('hero-canvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  let W, H, particles = [], animId;

  function resize() {
    W = canvas.width  = canvas.offsetWidth;
    H = canvas.height = canvas.offsetHeight;
  }

  function Particle() {
    this.reset = function() {
      this.x    = Math.random() * W;
      this.y    = Math.random() * -H;
      this.size = Math.random() * 3 + 1;
      this.speed= Math.random() * 0.6 + 0.2;
      this.drift= (Math.random() - 0.5) * 0.3;
      this.alpha= Math.random() * 0.7 + 0.2;
      this.char = ['❄','❅','*','+','·'][Math.floor(Math.random()*5)];
      this.isText = Math.random() > 0.7;
    };
    this.reset();
    this.y = Math.random() * H; // start spread
  }

  function spawnParticles() {
    const count = Math.min(40, Math.floor(W / 30));
    particles = Array.from({length: count}, () => new Particle());
  }

  // Aurora gradient bands
  let auroraTime = 0;
  function drawAurora() {
    auroraTime += 0.004;
    const bands = [
      { color: 'rgba(105,240,174,', y: 0.25 },
      { color: 'rgba(179,136,255,', y: 0.45 },
      { color: 'rgba(64,196,255,',  y: 0.65 },
    ];
    bands.forEach((b, i) => {
      const waveY = H * b.y + Math.sin(auroraTime + i * 1.3) * 30;
      const grad = ctx.createLinearGradient(0, waveY - 60, 0, waveY + 60);
      grad.addColorStop(0,   b.color + '0)');
      grad.addColorStop(0.5, b.color + '0.04)');
      grad.addColorStop(1,   b.color + '0)');
      ctx.fillStyle = grad;
      ctx.fillRect(0, waveY - 60, W, 120);
    });
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    drawAurora();

    particles.forEach(p => {
      p.y += p.speed;
      p.x += p.drift;
      if (p.y > H + 20) p.reset();
      if (p.x < -10) p.x = W + 10;
      if (p.x > W + 10) p.x = -10;

      ctx.globalAlpha = p.alpha;
      if (p.isText) {
        ctx.fillStyle = '#a5d8ff';
        ctx.font = `${p.size * 5}px monospace`;
        ctx.fillText(p.char, p.x, p.y);
      } else {
        ctx.fillStyle = `rgba(165,216,255,${p.alpha})`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      }
    });
    ctx.globalAlpha = 1;
    animId = requestAnimationFrame(draw);
  }

  resize();
  spawnParticles();
  draw();

  const ro = new ResizeObserver(() => { resize(); spawnParticles(); });
  ro.observe(canvas.parentElement);
}

/* ── Status & players ─────────────────────────────────────── */
async function loadStatus() {
  try {
    const r = await fetch('/api/status');
    const d = await r.json();
    const online = d.online;
    const players = d.players ?? 0;
    const max     = d.max ?? 15;
    const tps     = d.tps;

    // Nav status
    const ns = document.getElementById('nav-status');
    const nsText = document.getElementById('nav-status-text');
    if (ns) {
      ns.className = 'nav-status ' + (online ? 'online' : 'offline');
      nsText.textContent = online ? `${players}/${max} online` : 'Offline';
    }

    // Hero stats
    const hp = document.getElementById('hero-players');
    const ht = document.getElementById('hero-tps');
    if (hp) hp.textContent = players;
    if (ht) {
      ht.textContent = tps != null ? tps.toFixed(1) : '—';
      ht.style.color = !tps ? '' : tps >= 19 ? 'var(--green)' : tps >= 15 ? 'var(--aurora-o)' : 'var(--danger)';
    }

    // Ticker
    const t1 = document.getElementById('ticker-players');
    const t2 = document.getElementById('ticker-players2');
    const tt1= document.getElementById('ticker-tps');
    const tt2= document.getElementById('ticker-tps2');
    if (t1) t1.textContent = `${players}/${max} jucători online`;
    if (t2) t2.textContent = `${players}/${max} jucători online`;
    if (tt1) tt1.textContent = tps != null ? tps.toFixed(1) : '—';
    if (tt2) tt2.textContent = tps != null ? tps.toFixed(1) : '—';

    // Online summary
    const os = document.getElementById('online-summary');
    if (os) {
      if (!online) os.textContent = 'Serverul este momentan offline.';
      else if (players === 0) os.textContent = 'Serverul este online — niciun jucător acum.';
      else os.textContent = `${players} ${players === 1 ? 'jucător' : 'jucători'} conectați din ${max} locuri`;
    }

    // Players list
    const list = document.getElementById('players-list');
    if (list) {
      if (!d.playerNames || d.playerNames.length === 0) {
        list.innerHTML = '<span class="no-content">Niciun jucător online acum.</span>';
      } else {
        list.innerHTML = d.playerNames.map(name => `
          <div class="player-card">
            <img src="https://crafatar.com/avatars/${encodeURIComponent(name)}?size=28&overlay" alt="${name}" loading="lazy" onerror="this.src='https://crafatar.com/avatars/steve?size=28'">
            <span>${name}</span>
          </div>`).join('');
      }
    }
  } catch (e) {
    const ns = document.getElementById('nav-status');
    if (ns) ns.className = 'nav-status offline';
  }
}

async function loadTop() {
  try {
    const r = await fetch('/api/top');
    const data = await r.json();
    const list = document.getElementById('top-list');
    if (!list) return;
    if (!data.length) {
      list.innerHTML = '<span class="no-content">Nu există date de economie încă.</span>';
      return;
    }
    const rankClass  = i => i === 0 ? 'gold' : i === 1 ? 'silver' : i === 2 ? 'bronze' : '';
    const rankSymbol = i => i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : `#${i+1}`;
    list.innerHTML = data.map((p, i) => `
      <div class="top-entry">
        <div class="top-rank ${rankClass(i)}">${rankSymbol(i)}</div>
        <img src="https://crafatar.com/avatars/${encodeURIComponent(p.name)}?size=28&overlay"
             style="width:28px;height:28px;image-rendering:pixelated;border-radius:2px"
             loading="lazy" onerror="this.style.display='none'">
        <div class="top-name">${p.name}</div>
        <div class="top-balance">${Number(p.balance).toLocaleString('ro-RO')} C</div>
      </div>`).join('');
  } catch {}
}

/* ── Copy IP ──────────────────────────────────────────────── */
function copyIP() {
  const ip = 'play.ice4legends.com';
  navigator.clipboard.writeText(ip).then(() => {
    ['copy-label','copy-label-2'].forEach(id => {
      const el = document.getElementById(id);
      if (el) { el.textContent = 'COPIAT!'; setTimeout(() => el.textContent = 'COPIAZA', 2000); }
    });
  });
}

/* ── Mobile menu ─────────────────────────────────────────── */
function closeMobileMenu() {
  document.getElementById('mobile-menu')?.classList.remove('open');
}
document.getElementById('nav-hamburger')?.addEventListener('click', () => {
  document.getElementById('mobile-menu')?.classList.toggle('open');
});

/* ── Nav scroll ──────────────────────────────────────────── */
function initNavScroll() {
  const nav = document.getElementById('main-nav');
  if (!nav) return;
  window.addEventListener('scroll', () => nav.classList.toggle('scrolled', window.scrollY > 60), { passive: true });
}

/* ── Scroll reveal ───────────────────────────────────────── */
function initScrollReveal() {
  const obs = new IntersectionObserver((entries) => {
    entries.forEach((e, i) => {
      if (e.isIntersecting) {
        setTimeout(() => e.target.classList.add('revealed'), i * 70);
        obs.unobserve(e.target);
      }
    });
  }, { threshold: 0.08, rootMargin: '0px 0px -30px 0px' });
  document.querySelectorAll('.reveal').forEach(el => obs.observe(el));
}

/* ── Init ────────────────────────────────────────────────── */
initCanvas();
loadStatus();
loadTop();
setInterval(loadStatus, 30000);
initNavScroll();
initScrollReveal();
