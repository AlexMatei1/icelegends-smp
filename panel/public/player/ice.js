// IceLegends Ice Theme — shared snow initializer
function initSnow() {
  const el = document.getElementById('snow');
  if (!el) return;
  const glyphs = ['❄','❅','❆','·','*'];
  for (let i = 0; i < 30; i++) {
    const f = document.createElement('div');
    f.className = 'sf';
    f.textContent = glyphs[Math.floor(Math.random() * glyphs.length)];
    f.style.left = (Math.random() * 100) + '%';
    f.style.fontSize = (8 + Math.random() * 14) + 'px';
    f.style.animationDuration = (9 + Math.random() * 16) + 's';
    f.style.animationDelay = '-' + (Math.random() * 24) + 's';
    el.appendChild(f);
  }
}

// Minecraft item texture for each nav destination
const MC_ITEMS = {
  '/player/dashboard':  { img:'/img/mc/diamond.png',        label:'Dashboard'   },
  '/player/feed':       { img:'/img/mc/spyglass.png',       label:'Feed'        },
  '/player/bounties':   { img:'/img/mc/crossbow.png',       label:'Bounties'    },
  '/player/stocks':     { img:'/img/mc/gold_ingot.png',     label:'Stocks'      },
  '/player/capsule':    { img:'/img/mc/ender_pearl.png',    label:'Capsule'     },
  '/player/wars':       { img:'/img/mc/diamond_sword.png',  label:'Wars'        },
  '/player/missions':   { img:'/img/mc/arrow.png',          label:'Misiuni'     },
  '/player/shop':       { img:'/img/mc/emerald.png',        label:'Shop'        },
  '/player/clans':      { img:'/img/mc/iron_chestplate.png',label:'Clanuri'     },
  '/player/vote':       { img:'/img/mc/paper.png',          label:'Vot'         },
  '/player/appeal':      { img:'/img/mc/book.png',           label:'Contestație' },
  '/player/leaderboard':{ img:'/img/mc/gold_ingot.png',     label:'Clasament'   },
  '/player/admin':      { img:'/img/mc/dragon_egg.png',     label:'Admin'       },
};

function makeMcNavImg(src) {
  const img = document.createElement('img');
  img.src = src;
  img.alt = '';
  img.className = 'nav-mc-item';
  img.onerror = () => { img.style.display = 'none'; };
  return img;
}

// Replace emoji text in existing nav-link elements with MC item sprites
function upgradeMcIcons() {
  document.querySelectorAll('.nav-link').forEach(a => {
    const href = a.getAttribute('href');
    const meta = MC_ITEMS[href];
    if (!meta || a.querySelector('.nav-mc-item')) return;
    a.innerHTML = '';
    a.appendChild(makeMcNavImg(meta.img));
    a.appendChild(document.createTextNode(meta.label));
  });
}

// Inject nav links for pages that don't hardcode them
function injectStaticNav() {
  const navLinks = document.querySelector('.nav-links');
  if (!navLinks) return;
  const cur = location.pathname;
  const inject = [
    '/player/feed', '/player/missions', '/player/shop',
    '/player/clans', '/player/vote', '/player/appeal', '/player/leaderboard',
  ];
  const insertAfter = navLinks.querySelector('[href="/player/dashboard"]') || navLinks.firstChild;
  let ref = insertAfter ? insertAfter.nextSibling : null;
  for (const href of inject) {
    if (navLinks.querySelector(`[href="${href}"]`)) continue;
    const meta = MC_ITEMS[href];
    if (!meta) continue;
    const a = document.createElement('a');
    a.href = href;
    a.className = 'nav-link' + (cur.startsWith(href) ? ' active' : '');
    a.appendChild(makeMcNavImg(meta.img));
    a.appendChild(document.createTextNode(meta.label));
    navLinks.insertBefore(a, ref);
  }
}

function injectHomeBtn() {
  const navRight = document.querySelector('.nav-right');
  if (!navRight || navRight.querySelector('.home-btn')) return;
  const a = document.createElement('a');
  a.href = '/';
  a.className = 'home-btn';
  a.title = 'Înapoi la pagina principală';
  a.textContent = '← Acasă';
  a.style.cssText = 'font-size:.75rem;color:var(--muted);padding:5px 10px;border:1px solid var(--border);border-radius:8px;text-decoration:none;transition:all .2s;white-space:nowrap;';
  a.onmouseenter = () => { a.style.color = 'var(--ice)'; a.style.borderColor = 'var(--border-soft)'; };
  a.onmouseleave = () => { a.style.color = 'var(--muted)'; a.style.borderColor = 'var(--border)'; };
  navRight.insertBefore(a, navRight.firstChild);
}

async function injectUserNav() {
  try {
    const r = await fetch('/api/player/me', { credentials: 'include' });
    if (!r.ok) return;
    const d = await r.json();
    const name = d.username || d.name || '';
    const uuid = d.uuid || '';

    const navRight = document.querySelector('.nav-right');
    if (navRight && name) {
      let img = navRight.querySelector('.nav-mc-head');
      if (!img) {
        img = document.createElement('img');
        img.className = 'nav-mc-head';
        img.style.cssText = 'width:28px;height:28px;border-radius:4px;image-rendering:pixelated;vertical-align:middle';
        navRight.insertBefore(img, navRight.firstChild);
      }
      const lookup = uuid || name;
      img.src = `https://mc-heads.net/avatar/${encodeURIComponent(lookup)}/28`;
      img.alt = name;
      img.style.display = 'inline-block';
    }

    const nn = document.getElementById('navName');
    if (nn && !nn.textContent.trim()) nn.textContent = name;

    if (!['moderator','admin','owner'].includes(d.role || 'player')) return;
    const navLinks = document.querySelector('.nav-links');
    if (!navLinks || navLinks.querySelector('[href="/player/admin"]')) return;
    const meta = MC_ITEMS['/player/admin'];
    const a = document.createElement('a');
    a.href = '/player/admin';
    a.className = 'nav-link' + (location.pathname.includes('admin') ? ' active' : '');
    if (meta) {
      a.appendChild(makeMcNavImg(meta.img));
      a.appendChild(document.createTextNode(meta.label));
    } else {
      a.textContent = '⚙ Admin';
    }
    navLinks.appendChild(a);
  } catch {}
}

function injectFooter() {
  if (document.querySelector('.portal-footer')) return;
  const cur = location.pathname;
  const tabs = [
    ['/player/dashboard',  '/img/mc/diamond.png',       'Dashboard'],
    ['/player/feed',       '/img/mc/spyglass.png',      'Feed'],
    ['/player/bounties',   '/img/mc/crossbow.png',      'Bounties'],
    ['/player/leaderboard','/img/mc/gold_ingot.png',    'Clasament'],
    ['/player/missions',   '/img/mc/arrow.png',         'Misiuni'],
    ['/player/clans',      '/img/mc/iron_chestplate.png','Clanuri'],
    ['/player/vote',       '/img/mc/paper.png',         'Vot'],
    ['/player/appeal',     '/img/mc/book.png',          'Contestație'],
  ];
  const tabsHtml = tabs.map(([href, img, label]) =>
    `<a class="pf-tab${cur.startsWith(href) ? ' active' : ''}" href="${href}">` +
    `<img src="${img}" alt="" onerror="this.style.display='none'">${label}</a>`
  ).join('');
  const footer = document.createElement('footer');
  footer.className = 'portal-footer';
  footer.innerHTML = `
    <div class="portal-footer-inner">
      <div class="portal-footer-tabs">${tabsHtml}</div>
      <div class="portal-footer-bottom">
        <div class="portal-footer-brand">❄ <span>ICE</span>LEGENDS SMP</div>
        <a class="pf-home-btn" href="/">
          <svg viewBox="0 0 24 24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>
          Pagina Principală
        </a>
        <div class="portal-footer-copy">© ${new Date().getFullYear()} IceLegends SMP · Portal Jucători</div>
      </div>
    </div>`;
  document.body.appendChild(footer);
}

// Global logout — called by nav "Delogare" button on pages that don't define their own
async function logout() {
  await fetch('/api/player/logout', { method: 'POST', credentials: 'include' }).catch(() => {});
  window.location.href = '/player/login';
}

document.addEventListener('DOMContentLoaded', () => {
  initSnow();
  injectStaticNav();
  upgradeMcIcons();
  injectHomeBtn();
  injectUserNav();
  injectFooter();
});
