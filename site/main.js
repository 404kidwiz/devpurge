(() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  // Low-core machines skip parallax and the heavy SVG ink filters (see html.lite in CSS).
  const lite = (navigator.hardwareConcurrency || 8) <= 4;
  if (lite) document.documentElement.classList.add('lite');

  // Palette switcher (Zine, Citrus, Blacklight, Ember) saved to localStorage.
  const swatches = [...document.querySelectorAll('[data-set-palette]')];
  const applyPalette = (id) => {
    document.documentElement.dataset.palette = id;
    swatches.forEach((btn) => btn.setAttribute('aria-pressed', String(btn.dataset.setPalette === id)));
    try { localStorage.setItem('devpurge.palette', id); } catch {}
  };
  try {
    const saved = localStorage.getItem('devpurge.palette');
    if (saved && ['zine', 'citrus', 'blacklight', 'ember'].includes(saved)) {
      applyPalette(saved);
    }
  } catch {}
  swatches.forEach((btn) => btn.addEventListener('click', () => applyPalette(btn.dataset.setPalette)));

  // Seeded RNG so torn edges and barcode look the same on every load.
  const rng = (seed) => () => {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  // Ripped-paper edges: jitter every edge in px so depth stays constant at any size.
  document.querySelectorAll('.torn, .torn-bg').forEach((el, i) => {
    const r = rng(i * 97 + 13), d = el.classList.contains('chip') ? 7 : 9, n = 28, pts = [];
    for (let k = 0; k <= n; k++) pts.push(`${(k / n) * 100}% ${(r() * d).toFixed(1)}px`);
    for (let k = 1; k <= 8; k++) pts.push(`calc(100% - ${(r() * 5).toFixed(1)}px) ${(k / 9) * 100}%`);
    for (let k = n; k >= 0; k--) pts.push(`${(k / n) * 100}% calc(100% - ${(r() * d).toFixed(1)}px)`);
    for (let k = 8; k >= 1; k--) pts.push(`${(r() * 5).toFixed(1)}px ${(k / 9) * 100}%`);
    el.style.setProperty('--torn', `polygon(${pts.join(',')})`);
  });

  // Barcode bars.
  const bc = document.querySelector('[data-barcode]');
  if (bc) {
    const r = rng(7);
    for (let k = 0; k < 58; k++) {
      const bar = document.createElement('i');
      bar.style.width = `${[2, 2, 3, 5, 7][Math.floor(r() * 5)]}px`;
      bar.style.marginRight = `${[2, 3, 4, 6][Math.floor(r() * 4)]}px`;
      bc.appendChild(bar);
    }
  }

  // Scroll reveals.
  const reveal = (el) => el.classList.add('in');
  if (reduce || !('IntersectionObserver' in window)) {
    document.querySelectorAll('[data-reveal], .draw').forEach(reveal);
  } else {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        reveal(e.target);
        e.target.querySelectorAll?.('.draw').forEach(reveal);
        io.unobserve(e.target);
      });
    }, { threshold: 0.18, rootMargin: '0px 0px -6% 0px' });
    document.querySelectorAll('[data-reveal], .arrow, .handnote').forEach((el) => io.observe(el));
  }

  // Hero sticker counts up once.
  const count = document.querySelector('[data-count]');
  if (count && !reduce) {
    const target = parseFloat(count.dataset.count), t0 = performance.now() + 700;
    count.textContent = '0.0';
    const tick = (t) => {
      const p = Math.min(1, Math.max(0, (t - t0) / 1100));
      count.textContent = (target * (1 - Math.pow(1 - p, 4))).toFixed(1);
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }

  // Parallax, sticky nav state and receipt "printing" share one rAF loop.
  const nav = document.querySelector('[data-nav]');
  const layers = [...document.querySelectorAll('[data-speed]')];
  const receipt = document.querySelector('[data-print]');
  let queued = false, lastY = scrollY;
  const frame = () => {
    queued = false;
    const y = scrollY, vh = innerHeight;
    nav.classList.toggle('is-scrolled', y > 40);
    // Hide while reading downward, return on any upward scroll or focus.
    nav.classList.toggle('is-hidden', y > 240 && y > lastY + 2 && !nav.contains(document.activeElement));
    if (Math.abs(y - lastY) > 2) lastY = y;
    if (reduce || lite) return;
    layers.forEach((el) => {
      const box = el.parentElement.getBoundingClientRect();
      if (box.bottom < 0 || box.top > vh) return;
      const base = el.dataset.base ??= getComputedStyle(el).transform === 'none' ? '' : getComputedStyle(el).transform;
      el.style.transform = `${base === '' ? '' : base} translate3d(0, ${(box.top * parseFloat(el.dataset.speed)).toFixed(1)}px, 0)`;
    });
    if (receipt && !receipt.dataset.done) {
      const b = receipt.getBoundingClientRect();
      const p = Math.min(1, Math.max(0, (vh - b.top) / (b.height * 0.9)));
      // Prints in as it scrolls up; stays printed once complete.
      if (p >= 1) receipt.dataset.done = '1';
      receipt.style.setProperty('--print', p >= 1 ? 'none' : `inset(0 0 ${((1 - p) * 100).toFixed(1)}% 0)`);
    }
  };
  const onScroll = () => { if (!queued) { queued = true; requestAnimationFrame(frame); } };
  addEventListener('scroll', onScroll, { passive: true });
  addEventListener('resize', onScroll);
  frame();

  // Interactive review board: notes toggle, total recalculates.
  const total = document.querySelector('[data-total]');
  const notes = [...document.querySelectorAll('[data-board] .note[data-size]')];
  const trash = document.querySelector('[data-trash]');
  const selectAllBtn = document.querySelector('[data-select-all]');
  const clearAllBtn = document.querySelector('[data-clear-all]');
  const sum = () => {
    const gb = notes.filter((n) => n.getAttribute('aria-pressed') === 'true').reduce((a, n) => a + parseFloat(n.dataset.size), 0);
    total.textContent = `${gb.toFixed(1)} GB`;
    total.classList.remove('bump'); void total.offsetWidth; total.classList.add('bump');
    trash.setAttribute('aria-disabled', String(gb === 0));
  };
  notes.forEach((n) => n.addEventListener('click', () => {
    n.setAttribute('aria-pressed', String(n.getAttribute('aria-pressed') !== 'true'));
    sum();
  }));
  selectAllBtn?.addEventListener('click', () => {
    notes.forEach((n) => n.setAttribute('aria-pressed', 'true'));
    sum();
  });
  clearAllBtn?.addEventListener('click', () => {
    notes.forEach((n) => n.setAttribute('aria-pressed', 'false'));
    sum();
  });

  // The demo never touches files; say so instead of pretending.
  const toast = document.querySelector('[data-toast]');
  let hide;
  trash?.addEventListener('click', () => {
    toast.textContent = trash.getAttribute('aria-disabled') === 'true'
      ? 'Pick at least one note first.'
      : `Demo only: ${total.textContent} would go to Trash. Nothing on this Mac changed.`;
    toast.classList.add('is-on');
    clearTimeout(hide); hide = setTimeout(() => toast.classList.remove('is-on'), 3200);
  });

  // Interactive CLI Command Builder & Copy Stamp.
  const cliModes = [...document.querySelectorAll('[data-cli-cmd]')];
  const cliOutput = document.querySelector('[data-cli-output]');
  const cliDesc = document.querySelector('[data-cli-desc]');
  const cliCopy = document.querySelector('[data-cli-copy]');
  const cliStamp = document.querySelector('[data-cli-stamp]');
  let stampTimer;
  cliModes.forEach((btn) => {
    btn.addEventListener('click', () => {
      cliModes.forEach((b) => b.setAttribute('aria-selected', String(b === btn)));
      if (cliOutput) cliOutput.textContent = btn.dataset.cliCmd;
      if (cliDesc) cliDesc.textContent = btn.dataset.cliNote;
    });
  });
  cliCopy?.addEventListener('click', async () => {
    const cmd = cliOutput?.textContent || 'python3 -m devpurge --dry-run';
    try {
      await navigator.clipboard.writeText(cmd);
    } catch {
      const ta = document.createElement('textarea');
      ta.value = cmd;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); } catch {}
      ta.remove();
    }
    cliStamp?.classList.remove('is-stamped');
    void cliStamp?.offsetWidth;
    cliStamp?.classList.add('is-stamped');
    if (cliCopy) cliCopy.textContent = 'Copied!';
    clearTimeout(stampTimer);
    stampTimer = setTimeout(() => {
      cliStamp?.classList.remove('is-stamped');
      if (cliCopy) cliCopy.textContent = 'Copy';
    }, 1800);
  });
})();
