(() => {
  const motionPreference = matchMedia('(prefers-reduced-motion: reduce)');
  let reduce = motionPreference.matches;
  // Low-core machines skip parallax and the heavy SVG ink filters (see html.lite in CSS).
  const lite = (navigator.hardwareConcurrency || 8) <= 4;
  if (lite) document.documentElement.classList.add('lite');

  // Palette switcher (Zine, Citrus, Blacklight, Ember) saved to localStorage.
  const swatches = [...document.querySelectorAll('[data-set-palette]')];
  const paletteMenu = document.querySelector('[data-palette-menu]');
  const paletteToggle = paletteMenu?.querySelector('.palette__toggle');
  const palettePop = paletteMenu?.querySelector('.palette__pop');
  const applyPalette = (id) => {
    document.documentElement.dataset.palette = id;
    swatches.forEach((btn) => {
      const on = btn.dataset.setPalette === id;
      btn.setAttribute('aria-pressed', String(on));
      // The toggle shows the active palette's ring.
      if (on && paletteToggle) paletteToggle.firstElementChild.style.cssText = btn.firstElementChild.style.cssText;
    });
    // App screenshots are rendered per palette, so the demo matches the page.
    document.querySelectorAll('[data-shot]').forEach((img) => {
      img.src = `assets/app/${id}-${img.dataset.shot}.webp`;
    });
    try { localStorage.setItem('devpurge.palette', id); } catch {}
  };
  const setPaletteOpen = (open) => {
    if (!paletteToggle) return;
    paletteToggle.setAttribute('aria-expanded', String(open));
    palettePop.hidden = !open;
  };
  paletteToggle?.addEventListener('click', () => setPaletteOpen(palettePop.hidden));
  document.addEventListener('click', (e) => { if (paletteMenu && !paletteMenu.contains(e.target)) setPaletteOpen(false); });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && palettePop && !palettePop.hidden) { setPaletteOpen(false); paletteToggle.focus(); }
  });
  try {
    const saved = localStorage.getItem('devpurge.palette');
    if (saved && ['zine', 'citrus', 'blacklight', 'ember'].includes(saved)) {
      applyPalette(saved);
    }
  } catch {}
  if (!paletteToggle?.firstElementChild.style.cssText) applyPalette(document.documentElement.dataset.palette || 'zine');
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
      if (reduce) { count.textContent = target.toFixed(1); return; }
      const p = Math.min(1, Math.max(0, (t - t0) / 1100));
      count.textContent = (target * (1 - Math.pow(1 - p, 4))).toFixed(1);
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }

  // Parallax, sticky nav state and receipt "printing" share one rAF loop.
  const nav = document.querySelector('[data-nav]');
  const layers = [...document.querySelectorAll('[data-speed]')].filter((el) => !el.closest('.hero'));
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

  // Independent translate composes with torn-paper rotations and entrance transforms.
  // Only schedule frames while input changes or the layers are settling.
  const hero = document.querySelector('.hero');
  const finePointer = matchMedia('(hover: hover) and (pointer: fine)');
  const desktopHero = matchMedia('(min-width: 861px)');
  const heroLayers = [
    ['.dots', 18, -28], ['.burst', -12, 22], ['.tape', -10, -18],
    ['.scrap', 12, 24], ['.scribble', -8, -12], ['.headline .row', 3, -8],
    ['.laptop', 12, 32], ['.sticker', -9, -18], ['.arrow--hero', 6, 12],
  ].flatMap(([selector, depth, drift]) => [...(hero?.querySelectorAll(selector) || [])]
    .map((el) => ({ el, depth, drift })));
  let motionFrame = 0, targetX = 0, targetY = 0, currentX = 0, currentY = 0;
  let pointerX = null, pointerY = null, lastPaint = 0;
  const heroMotionAllowed = () => !reduce && !lite && desktopHero.matches && !document.hidden;
  const resetHero = () => {
    cancelAnimationFrame(motionFrame);
    motionFrame = targetX = targetY = currentX = currentY = lastPaint = 0;
    heroLayers.forEach(({ el }) => el.style.removeProperty('translate'));
  };
  const paintHero = (now = performance.now()) => {
    motionFrame = 0;
    if (!hero || !heroMotionAllowed()) { resetHero(); return; }
    const box = hero.getBoundingClientRect();
    if (box.bottom <= 0 || box.top >= innerHeight) { resetHero(); return; }
    // Target comes from the last cursor position against the current box,
    // so scrolling under a still mouse retargets without a pointermove.
    if (pointerX !== null) {
      const clamp = (value) => Math.max(-1, Math.min(1, value));
      targetX = clamp((pointerX - box.left) / box.width * 2 - 1);
      targetY = clamp((pointerY - box.top) / box.height * 2 - 1);
    }
    // Frame-time easing: same feel on 60Hz and 120Hz screens.
    const dt = lastPaint ? Math.min(64, now - lastPaint) : 16.667;
    lastPaint = now;
    const k = 1 - Math.pow(0.84, dt / 16.667);
    currentX += (targetX - currentX) * k;
    currentY += (targetY - currentY) * k;
    const progress = Math.min(1, Math.max(0, -box.top / box.height));
    heroLayers.forEach(({ el, depth, drift }) => {
      el.style.translate = `${(currentX * depth).toFixed(2)}px ${(currentY * depth + progress * drift).toFixed(2)}px`;
    });
    if (Math.abs(targetX - currentX) + Math.abs(targetY - currentY) > 0.001) {
      motionFrame = requestAnimationFrame(paintHero);
    } else {
      lastPaint = 0;
    }
  };
  const queueHero = () => {
    if (!motionFrame) motionFrame = requestAnimationFrame(paintHero);
  };
  const releasePointer = () => { pointerX = pointerY = null; targetX = targetY = 0; queueHero(); };
  hero?.addEventListener('pointermove', (event) => {
    if (!heroMotionAllowed() || !finePointer.matches || event.pointerType !== 'mouse') return;
    pointerX = event.clientX;
    pointerY = event.clientY;
    queueHero();
  }, { passive: true });
  hero?.addEventListener('pointerleave', releasePointer);
  hero?.addEventListener('pointercancel', releasePointer);
  addEventListener('blur', releasePointer);
  addEventListener('scroll', queueHero, { passive: true });
  addEventListener('resize', queueHero);
  document.addEventListener('visibilitychange', () => { resetHero(); queueHero(); });
  finePointer.addEventListener('change', releasePointer);
  desktopHero.addEventListener('change', () => { resetHero(); queueHero(); });
  motionPreference.addEventListener('change', () => {
    reduce = motionPreference.matches;
    resetHero();
    if (reduce) {
      document.querySelectorAll('[data-reveal], .draw').forEach(reveal);
      layers.forEach((el) => { el.style.transform = el.dataset.base || ''; });
      receipt?.style.setProperty('--print', 'none');
      if (count) count.textContent = count.dataset.count;
    }
    onScroll();
    queueHero();
  });
  queueHero();

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

  // Real-app walkthrough. Autoplays only while visible and untouched;
  // the progress bar's animationend drives each step so visual and timing agree.
  const demo = document.querySelector('.demo');
  const demoWindow = demo?.querySelector('.demo__window');
  const demoSteps = [...(demo?.querySelectorAll('.demo__step') || [])];
  const demoShots = ['dashboard', 'review', 'done'].map((shot) => demo?.querySelector(`[data-shot="${shot}"]`));
  let demoManual = false, demoVisible = false;
  const setDemoStep = (index, focus = false) => {
    demoSteps.forEach((btn, i) => {
      const on = i === index;
      btn.setAttribute('aria-selected', String(on));
      btn.tabIndex = on ? 0 : -1;
    });
    // Only the visible screenshot is exposed to assistive tech.
    demoShots.forEach((img, i) => (i === index ? img.removeAttribute('aria-hidden') : img.setAttribute('aria-hidden', 'true')));
    demoWindow.dataset.step = String(index + 1);
    demoWindow.setAttribute('aria-labelledby', demoSteps[index].id);
    if (focus) demoSteps[index].focus();
  };
  const currentDemoStep = () => demoSteps.findIndex((btn) => btn.getAttribute('aria-selected') === 'true');
  const syncDemoPlay = () => {
    demo?.classList.toggle('is-playing', demoVisible && !demoManual && !reduce && !document.hidden);
  };
  if (demo && demoWindow && demoSteps.length) {
    demoSteps.forEach((btn, i) => btn.addEventListener('click', () => {
      demoManual = true;
      setDemoStep(i);
      syncDemoPlay();
    }));
    demo.querySelector('.demo__steps').addEventListener('keydown', (event) => {
      const last = demoSteps.length - 1, at = currentDemoStep();
      const next = { ArrowRight: at + 1, ArrowDown: at + 1, ArrowLeft: at - 1, ArrowUp: at - 1, Home: 0, End: last }[event.key];
      if (next === undefined) return;
      event.preventDefault();
      demoManual = true;
      setDemoStep((next + demoSteps.length) % demoSteps.length, true);
      syncDemoPlay();
    });
    demo.addEventListener('animationend', (event) => {
      if (!event.target.classList.contains('demo__bar') || !demo.classList.contains('is-playing')) return;
      // One full pass, then rest on step 1 so the page isn't moving forever.
      const next = currentDemoStep() + 1;
      if (next >= demoSteps.length) demoManual = true;
      setDemoStep(next % demoSteps.length);
      syncDemoPlay();
    });
    // Steps stack vertically on desktop, in a row on phones.
    const demoWide = matchMedia('(min-width: 861px)');
    const syncOrientation = () => demo.querySelector('.demo__steps').setAttribute('aria-orientation', demoWide.matches ? 'vertical' : 'horizontal');
    demoWide.addEventListener('change', syncOrientation);
    syncOrientation();
    // Hover or keyboard focus pauses so nobody loses the frame they are reading.
    const pause = (on) => demo.classList.toggle('is-paused', on);
    demo.querySelector('.demo__body').addEventListener('pointerenter', () => pause(true));
    demo.querySelector('.demo__body').addEventListener('pointerleave', () => pause(false));
    demo.addEventListener('focusin', () => pause(true));
    demo.addEventListener('focusout', (event) => { if (!demo.contains(event.relatedTarget)) pause(false); });
    document.addEventListener('visibilitychange', syncDemoPlay);
    motionPreference.addEventListener('change', syncDemoPlay);
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(([entry]) => {
        demoVisible = entry.isIntersecting;
        syncDemoPlay();
      }, { threshold: 0.45 }).observe(demoWindow);
    }
  }
})();
