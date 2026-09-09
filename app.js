(() => {
  'use strict';

  const MODULES = [
    { id: 'welcome', title: 'Mulai di sini' },
    { id: 'setup', title: 'Registrasi & setup' },
    { id: 'workspace', title: 'Siapkan workspace' },
    { id: 'requirements', title: 'Requirements' },
    { id: 'design', title: 'Design' },
    { id: 'tasks', title: 'Implementation tasks' },
    { id: 'implementation', title: 'Build aplikasi' },
    { id: 'validation', title: 'Validasi' },
    { id: 'finish', title: 'Credit review' }
  ];

  const STORAGE_KEY = 'kiro-builder-lab-v1';
  const CREDIT_GUARDRAIL = 50;
  const CREDIT_PHASES = ['start', 'requirements', 'design', 'tasks', 'implementation', 'validation'];
  const RESULT_FIELDS = ['time', 'balance', 'prompts', 'tasks'];
  const mobileMedia = window.matchMedia('(max-width: 820px)');

  const defaultState = {
    completed: [],
    credits: { start: '50' },
    tests: [],
    results: {},
    theme: null
  };

  const elements = {};
  let state = loadState();
  let activeModuleId = getModuleFromHash() || MODULES[0].id;
  let toastTimer;

  function isPlainObject(value) {
    return value !== null && typeof value === 'object' && !Array.isArray(value);
  }

  function normalizeNonNegativeValue(value) {
    if (value === '') return '';
    if (typeof value !== 'string' && typeof value !== 'number') return null;
    const parsed = Number(value);
    return Number.isFinite(parsed) && parsed >= 0 ? String(value) : null;
  }

  function loadState() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
      if (!isPlainObject(saved)) return structuredCloneSafe(defaultState);

      const savedCredits = isPlainObject(saved.credits) ? saved.credits : {};
      const savedResults = isPlainObject(saved.results) ? saved.results : {};
      const credits = { ...defaultState.credits };
      const results = {};

      CREDIT_PHASES.forEach((phase) => {
        if (!Object.hasOwn(savedCredits, phase)) return;
        const normalized = normalizeNonNegativeValue(savedCredits[phase]);
        if (normalized !== null) credits[phase] = normalized;
      });

      RESULT_FIELDS.forEach((field) => {
        if (!Object.hasOwn(savedResults, field)) return;
        const normalized = normalizeNonNegativeValue(savedResults[field]);
        if (normalized !== null) results[field] = normalized;
      });

      const completed = Array.isArray(saved.completed)
        ? [...new Set(saved.completed.filter((id) => MODULES.some((module) => module.id === id)))]
        : [];
      const tests = Array.isArray(saved.tests)
        ? [...new Set(saved.tests.filter((index) => Number.isInteger(index) && index >= 0 && index < 6))]
        : [];
      const theme = saved.theme === 'light' || saved.theme === 'dark' ? saved.theme : null;

      return { completed, credits, tests, results, theme };
    } catch {
      return structuredCloneSafe(defaultState);
    }
  }

  function structuredCloneSafe(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function saveState() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch {
      showToast('Progress tidak dapat disimpan oleh browser ini.');
    }
  }

  function cacheElements() {
    elements.modules = [...document.querySelectorAll('[data-module]')];
    elements.navLinks = [...document.querySelectorAll('[data-module-link]')];
    elements.completionChecks = [...document.querySelectorAll('[data-module-complete]')];
    elements.testChecks = [...document.querySelectorAll('[data-test-check]')];
    elements.creditFields = [...document.querySelectorAll('[data-credit-field]')];
    elements.progressBar = document.querySelector('#progress-bar');
    elements.progressLabel = document.querySelector('#progress-label');
    elements.progressDetail = document.querySelector('#progress-detail');
    elements.breadcrumb = document.querySelector('#breadcrumb-current');
    elements.previous = document.querySelector('#prev-module');
    elements.next = document.querySelector('#next-module');
    elements.menuToggle = document.querySelector('#menu-toggle');
    elements.sidebar = document.querySelector('#workshop-sidebar');
    elements.sidebarBackdrop = document.querySelector('#sidebar-backdrop');
    elements.themeToggle = document.querySelector('#theme-toggle');
    elements.themeIcon = document.querySelector('.theme-icon');
    elements.creditPanel = document.querySelector('#credit-tracker');
    elements.creditUsed = document.querySelector('#credits-used');
    elements.creditBar = document.querySelector('#credit-meter-bar');
    elements.creditStatus = document.querySelector('#credit-status');
    elements.toast = document.querySelector('#toast');
  }

  function getModuleFromHash() {
    const id = window.location.hash.slice(1);
    return MODULES.some((module) => module.id === id) ? id : null;
  }

  function prefersReducedMotion() {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }

  function showModule(id, options = {}) {
    const requestedIndex = MODULES.findIndex((module) => module.id === id);
    const index = requestedIndex >= 0 ? requestedIndex : 0;
    const module = MODULES[index];
    const activeArticle = elements.modules.find((article) => article.dataset.module === module.id);
    activeModuleId = module.id;

    elements.modules.forEach((article) => {
      const isActive = article === activeArticle;
      article.classList.toggle('is-active', isActive);
      article.setAttribute('aria-hidden', String(!isActive));
    });

    elements.navLinks.forEach((link) => {
      const isActive = link.dataset.moduleLink === module.id;
      link.classList.toggle('is-active', isActive);
      if (isActive) link.setAttribute('aria-current', 'step');
      else link.removeAttribute('aria-current');
    });

    elements.breadcrumb.textContent = module.title;
    elements.previous.disabled = index === 0;
    elements.next.disabled = index === MODULES.length - 1;
    elements.next.innerHTML = index === MODULES.length - 1
      ? 'Workshop selesai <span aria-hidden="true">✓</span>'
      : 'Berikutnya <span aria-hidden="true">→</span>';

    if (options.updateHash !== false && window.location.hash !== `#${module.id}`) {
      history.pushState(null, '', `#${module.id}`);
    }

    closeSidebar({ restoreFocus: false });
    if (options.focus !== false) {
      const heading = activeArticle?.querySelector('h1');
      if (heading) {
        heading.setAttribute('tabindex', '-1');
        heading.focus({ preventScroll: true });
      }
    }
    if (options.scroll !== false) {
      window.scrollTo({ top: 0, behavior: prefersReducedMotion() ? 'auto' : 'smooth' });
    }
  }

  function navigateBy(offset) {
    const currentIndex = MODULES.findIndex((module) => module.id === activeModuleId);
    const target = MODULES[currentIndex + offset];
    if (target) showModule(target.id);
  }

  function restoreProgress() {
    elements.completionChecks.forEach((checkbox) => {
      checkbox.checked = state.completed.includes(checkbox.dataset.moduleComplete);
    });

    elements.testChecks.forEach((checkbox, index) => {
      checkbox.checked = state.tests.includes(index);
    });

    elements.creditFields.forEach((field) => {
      const savedValue = state.credits[field.dataset.creditField];
      if (savedValue !== undefined) field.value = savedValue;
    });

    RESULT_FIELDS.forEach((name) => {
      const field = document.querySelector(`#result-${name}`);
      if (field && state.results[name] !== undefined) field.value = state.results[name];
    });

    updateProgress();
    updateCreditTracker();
  }

  function updateProgress() {
    const validCompleted = MODULES.filter((module) => state.completed.includes(module.id));
    const percentage = Math.round((validCompleted.length / MODULES.length) * 100);

    elements.progressBar.style.width = `${percentage}%`;
    elements.progressBar.parentElement.setAttribute('aria-valuenow', String(percentage));
    elements.progressLabel.textContent = `${percentage}%`;
    elements.progressDetail.textContent = `${validCompleted.length} dari ${MODULES.length} modul selesai`;

    elements.navLinks.forEach((link) => {
      link.classList.toggle('is-complete', state.completed.includes(link.dataset.moduleLink));
    });
  }

  function updateCreditTracker() {
    const start = parseCredit(state.credits.start);
    let latest = start;
    let latestPhase = 'start';
    let previous = start;

    if (start === null) {
      setCreditDisplay(0, 'Masukkan saldo awal yang terlihat di dashboard Kiro.', 'neutral');
      return;
    }

    for (const phase of CREDIT_PHASES.slice(1)) {
      const value = parseCredit(state.credits[phase]);
      if (value === null) continue;

      if (value > start) {
        setCreditDisplay(0, `Saldo setelah ${phase} lebih besar dari saldo awal. Periksa input atau kemungkinan reset/bonus.`, 'warning');
        return;
      }

      if (previous !== null && value > previous) {
        const usedBeforeError = Math.max(0, start - previous);
        setCreditDisplay(usedBeforeError, `Urutan saldo tidak valid: saldo setelah ${phase} meningkat. Periksa kembali input antar-fase.`, 'warning');
        return;
      }

      latest = value;
      latestPhase = phase;
      previous = value;
    }

    const used = Math.max(0, start - (latest ?? start));
    const phaseLabel = latestPhase === 'start' ? 'sebelum lab' : `setelah ${latestPhase}`;

    if (used >= CREDIT_GUARDRAIL) {
      setCreditDisplay(used, `Stop: penggunaan mencapai guardrail ${CREDIT_GUARDRAIL} credits (${phaseLabel}).`, 'danger');
    } else if (used >= 40) {
      setCreditDisplay(used, `Warning: tersisa ${(CREDIT_GUARDRAIL - used).toFixed(2)} dari budget eksperimen. Hindari refinement tambahan.`, 'warning');
    } else if (used >= 20) {
      setCreditDisplay(used, `Perhatikan budget: ${(CREDIT_GUARDRAIL - used).toFixed(2)} credits tersisa dari guardrail.`, 'attention');
    } else {
      setCreditDisplay(used, `Aman: ${(CREDIT_GUARDRAIL - used).toFixed(2)} credits tersisa dari guardrail eksperimen.`, 'safe');
    }
  }

  function parseCredit(value) {
    if (value === '' || value === undefined || value === null) return null;
    const parsed = Number(value);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
  }

  function setCreditDisplay(used, message, status) {
    const percentage = Math.min(100, Math.max(0, (used / CREDIT_GUARDRAIL) * 100));

    elements.creditPanel.dataset.status = status;
    elements.creditUsed.textContent = used.toFixed(2);
    elements.creditBar.style.width = `${percentage}%`;
    elements.creditBar.parentElement.setAttribute('aria-valuenow', used.toFixed(2));
    elements.creditStatus.textContent = message;
  }

  function applyTheme(theme) {
    const selected = theme || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    document.documentElement.dataset.theme = selected;
    elements.themeIcon.textContent = selected === 'dark' ? '☀' : '☾';
    elements.themeToggle.setAttribute('aria-label', selected === 'dark' ? 'Gunakan tema terang' : 'Gunakan tema gelap');
  }

  function toggleTheme() {
    const current = document.documentElement.dataset.theme;
    state.theme = current === 'dark' ? 'light' : 'dark';
    applyTheme(state.theme);
    saveState();
  }

  async function copyText(targetId, button) {
    const target = document.getElementById(targetId);
    if (!target) return;
    const text = target.innerText;

    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
      } else {
        fallbackCopy(text);
      }
      const originalText = button.textContent;
      button.textContent = 'Copied!';
      button.disabled = true;
      showToast('Teks disalin ke clipboard.');
      window.setTimeout(() => {
        button.textContent = originalText;
        button.disabled = false;
      }, 1400);
    } catch {
      showToast('Tidak dapat menyalin otomatis. Pilih teks lalu salin manual.');
    }
  }

  function fallbackCopy(text) {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    const copied = document.execCommand('copy');
    textarea.remove();
    if (!copied) throw new Error('Copy command failed');
  }

  function showToast(message) {
    window.clearTimeout(toastTimer);
    elements.toast.textContent = message;
    elements.toast.classList.add('is-visible');
    toastTimer = window.setTimeout(() => elements.toast.classList.remove('is-visible'), 2200);
  }

  function syncSidebarAccessibility() {
    const isOpen = document.body.classList.contains('sidebar-open');
    const shouldHide = mobileMedia.matches && !isOpen;
    if (shouldHide && elements.sidebar.contains(document.activeElement)) {
      elements.menuToggle.focus();
    }
    elements.sidebar.toggleAttribute('inert', shouldHide);
    elements.sidebar.setAttribute('aria-hidden', String(shouldHide));
  }

  function openSidebar() {
    document.body.classList.add('sidebar-open');
    elements.menuToggle.setAttribute('aria-expanded', 'true');
    elements.menuToggle.setAttribute('aria-label', 'Tutup navigasi modul');
    elements.sidebarBackdrop.hidden = false;
    syncSidebarAccessibility();
    const activeLink = elements.navLinks.find((link) => link.classList.contains('is-active'));
    if (activeLink) activeLink.focus();
  }

  function closeSidebar({ restoreFocus = false } = {}) {
    const wasOpen = document.body.classList.contains('sidebar-open');
    document.body.classList.remove('sidebar-open');
    elements.menuToggle.setAttribute('aria-expanded', 'false');
    elements.menuToggle.setAttribute('aria-label', 'Buka navigasi modul');
    elements.sidebarBackdrop.hidden = true;
    if (wasOpen && restoreFocus && mobileMedia.matches) elements.menuToggle.focus();
    syncSidebarAccessibility();
  }

  function trapSidebarFocus(event) {
    if (event.key !== 'Tab' || !mobileMedia.matches || !document.body.classList.contains('sidebar-open')) return;

    const focusable = [
      elements.menuToggle,
      ...elements.sidebar.querySelectorAll('a[href], button:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])')
    ];
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    const active = document.activeElement;

    if (!focusable.includes(active)) {
      event.preventDefault();
      first.focus();
    } else if (event.shiftKey && active === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && active === last) {
      event.preventDefault();
      first.focus();
    }
  }

  function resetWorkshop() {
    const confirmed = window.confirm('Reset seluruh progress, credit tracker, checklist, dan hasil lab?');
    if (!confirmed) return;

    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      showToast('Penyimpanan browser tidak dapat direset.');
      return;
    }

    history.replaceState(null, '', '#welcome');
    window.location.reload();
  }

  function bindEvents() {
    document.querySelectorAll('[data-nav-link]').forEach((link) => {
      link.addEventListener('click', (event) => {
        const id = link.getAttribute('href').slice(1);
        if (!MODULES.some((module) => module.id === id)) return;
        event.preventDefault();
        showModule(id);
      });
    });

    elements.previous.addEventListener('click', () => navigateBy(-1));
    elements.next.addEventListener('click', () => navigateBy(1));

    elements.completionChecks.forEach((checkbox) => {
      checkbox.addEventListener('change', () => {
        const id = checkbox.dataset.moduleComplete;
        state.completed = checkbox.checked
          ? [...new Set([...state.completed, id])]
          : state.completed.filter((moduleId) => moduleId !== id);
        saveState();
        updateProgress();
        showToast(checkbox.checked ? 'Modul ditandai selesai.' : 'Status modul dibuka kembali.');
      });
    });

    elements.testChecks.forEach((checkbox, index) => {
      checkbox.addEventListener('change', () => {
        state.tests = checkbox.checked
          ? [...new Set([...state.tests, index])]
          : state.tests.filter((savedIndex) => savedIndex !== index);
        saveState();
      });
    });

    elements.creditFields.forEach((field) => {
      field.addEventListener('input', () => {
        state.credits[field.dataset.creditField] = field.value;
        saveState();
        updateCreditTracker();
      });
    });

    RESULT_FIELDS.forEach((name) => {
      const field = document.querySelector(`#result-${name}`);
      if (!field) return;
      field.addEventListener('input', () => {
        state.results[name] = field.value;
        saveState();
      });
    });

    document.querySelectorAll('[data-copy-target]').forEach((button) => {
      button.addEventListener('click', () => copyText(button.dataset.copyTarget, button));
    });

    elements.menuToggle.addEventListener('click', () => {
      document.body.classList.contains('sidebar-open')
        ? closeSidebar({ restoreFocus: true })
        : openSidebar();
    });
    elements.sidebarBackdrop.addEventListener('click', () => closeSidebar({ restoreFocus: true }));
    elements.themeToggle.addEventListener('click', toggleTheme);
    document.querySelector('#reset-progress').addEventListener('click', resetWorkshop);

    window.addEventListener('popstate', () => {
      const moduleId = getModuleFromHash();
      if (moduleId) showModule(moduleId, { updateHash: false });
    });
    mobileMedia.addEventListener('change', () => {
      if (!mobileMedia.matches) document.body.classList.remove('sidebar-open');
      syncSidebarAccessibility();
    });
    window.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        closeSidebar({ restoreFocus: true });
        return;
      }
      trapSidebarFocus(event);
      if (event.defaultPrevented) return;
      const activeElement = document.activeElement;
      const activeTag = activeElement?.tagName || '';
      const isInteractive = /INPUT|TEXTAREA|SELECT|BUTTON|A/.test(activeTag) || activeElement?.isContentEditable;
      if (event.altKey || event.ctrlKey || event.metaKey || isInteractive) return;
      if (event.key === 'ArrowLeft') navigateBy(-1);
      if (event.key === 'ArrowRight') navigateBy(1);
    });
  }

  function initialize() {
    cacheElements();
    applyTheme(state.theme);
    restoreProgress();
    bindEvents();
    syncSidebarAccessibility();
    showModule(activeModuleId, { updateHash: false, scroll: false, focus: false });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize);
  } else {
    initialize();
  }

  window.KiroWorkshop = { MODULES, STORAGE_KEY, CREDIT_GUARDRAIL };
})();
