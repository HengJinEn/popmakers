// POP MAKERS: browser-only interactions. There is no backend or email storage.
document.body.classList.remove('no-js');
const KIT_FORM_URL = 'https://docs.google.com/forms/d/1InZ53ym9HusaL0M9XLohxLxFonYur33ykRySjzgHA8E/';
const MODEL_VIEWER_URL = 'https://unpkg.com/@google/model-viewer@4.3.1/dist/model-viewer.min.js';

// Each active GLB contains one mesh. Switch complete files rather than relying
// on mesh names, which vary between exports.
// Update this catalog if your export filenames or connector names change.
const connectors = [
  { name: '180 Connector', file: '180 Connector.glb', poster: '180.png', description: 'Keep your big idea in line.', build: 'Imagine: long frames' },
  { name: '90 Connector', file: '90 Connector.glb', poster: '90.png', description: 'Give your idea a new angle.', build: 'Imagine: square corners' },
  { name: '360 Connector', file: '360 Connector.glb', poster: '360.png', description: 'Take your ideas in every direction.', build: 'Imagine: cross-shaped frames' },
  { name: '180 · 3 Point', file: '180 Connector 3 Point.glb', poster: '180-3.png', description: 'Add a branch. Grow your build.', build: 'Imagine: branching structures' },
  { name: '180 · 8 Point', file: '180 Connector 8 Point.glb', poster: '180-8.png', description: 'More connections. More “what if?”', build: 'Imagine: complex frameworks' },
  { name: 'Prism Connector', file: 'Prism Connector.glb', poster: 'prism.png', description: 'Give your next idea a new shape.', build: 'Imagine: 3D structures' },
];
const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
const heroModel = document.querySelector('#hero-model');
const showcaseModel = document.querySelector('#showcase-model');
const showcasePoster = document.querySelector('#showcase-poster');
const spinButton = document.querySelector('#spin-button');
const status = document.querySelector('#viewer-status');
const viewerStates = new Map();
let selectedIndex = 0;
let showcaseStarted = false;
let rotationRequested = !motionPreference.matches;
let componentPromise;

document.querySelectorAll('[data-kit-link]').forEach(link => { link.href = KIT_FORM_URL; });
document.querySelector('#current-year').textContent = new Date().getFullYear();

// Mobile menu stays usable with keyboard, closes on Escape and anchor selection.
const menuButton = document.querySelector('.menu-toggle');
const menu = document.querySelector('#nav-links');
function closeMenu(returnFocus = false) {
  menu.classList.remove('is-open');
  menuButton.setAttribute('aria-expanded', 'false');
  menuButton.setAttribute('aria-label', 'Open navigation');
  if (returnFocus) menuButton.focus();
}
menuButton.addEventListener('click', () => {
  const open = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(open));
  menuButton.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
  menu.classList.toggle('is-open', open);
});
menu.addEventListener('click', event => { if (event.target.closest('a')) closeMenu(); });
document.addEventListener('keydown', event => { if (event.key === 'Escape') closeMenu(menu.classList.contains('is-open')); });
document.addEventListener('click', event => { if (!event.target.closest('.nav')) closeMenu(); });
window.matchMedia('(min-width: 701px)').addEventListener('change', event => { if (event.matches) closeMenu(); });

// IntersectionObserver is enhancement-only: text remains readable without JS.
if ('IntersectionObserver' in window && !motionPreference.matches) {
  const revealObserver = new IntersectionObserver(entries => entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.remove('is-pending');
      entry.target.classList.add('is-visible');
      revealObserver.unobserve(entry.target);
    }
  }), { threshold: 0.06, rootMargin: '0px 0px -20px 0px' });
  document.querySelectorAll('.reveal').forEach(element => { element.classList.add('is-pending'); revealObserver.observe(element); });
}

// Honest preview: native validation, no fetch, localStorage, cookies or email persistence.
document.querySelector('#signup-form').addEventListener('submit', event => {
  event.preventDefault();
  const form = event.currentTarget;
  if (!form.reportValidity()) return;
  document.querySelector('#signup-status').textContent = 'That address looks good! This is a preview, so you haven’t been signed up. Use “Get the Kit” to register your interest.';
});
document.querySelector('#signup-email').addEventListener('input', () => { document.querySelector('#signup-status').textContent = ''; });
document.querySelectorAll('#signup-form input, #signup-form button').forEach(element => { element.disabled = false; });

function modelURL(connector) { return `assets/models/${encodeURIComponent(connector.file)}`; }
function posterURL(connector) { return `assets/posters/${connector.poster}`; }
function setState(model, state) {
  const info = viewerStates.get(model);
  info.shell.dataset.state = state;
  info.shell.querySelector('.viewer-error').hidden = state !== 'error';
  if (model === showcaseModel) {
    spinButton.disabled = state !== 'ready';
    if (state === 'error') status.textContent = `${connectors[selectedIndex].name} static preview. The interactive model couldn’t load.`;
  }
}

function ensureComponent() {
  if (!componentPromise) {
    componentPromise = new Promise((resolve, reject) => {
      if (customElements.get('model-viewer')) { resolve(); return; }
      const script = document.createElement('script');
      script.type = 'module';
      script.src = MODEL_VIEWER_URL;
      const timeout = setTimeout(() => { script.remove(); componentPromise = undefined; reject(new Error('3D viewer timed out')); }, 20000);
      script.addEventListener('load', async () => {
        clearTimeout(timeout);
        // A successful fetch should register the web component immediately.
        if (!customElements.get('model-viewer')) { componentPromise = undefined; reject(new Error('3D component unavailable')); return; }
        await customElements.whenDefined('model-viewer');
        resolve();
      }, { once: true });
      script.addEventListener('error', () => { clearTimeout(timeout); script.remove(); componentPromise = undefined; reject(new Error('3D script unavailable')); }, { once: true });
      document.head.append(script);
    });
  }
  return componentPromise;
}

function updateRotation() {
  viewerStates.forEach((info, model) => {
    const requested = model === heroModel ? !motionPreference.matches : rotationRequested && !motionPreference.matches;
    model.toggleAttribute('auto-rotate', requested && info.visible && !document.hidden && info.shell.dataset.state === 'ready');
  });
  const spinning = rotationRequested && !motionPreference.matches;
  spinButton.setAttribute('aria-pressed', String(spinning));
  spinButton.innerHTML = spinning ? 'Pause spin <span aria-hidden="true">Ⅱ</span>' : 'Spin it! <span aria-hidden="true">↻</span>';
}

async function loadConnector(model, connector) {
  const info = viewerStates.get(model);
  const requestId = ++info.requestId;
  info.connector = connector;
  clearTimeout(info.timeout);
  setState(model, 'loading');
  model.removeAttribute('auto-rotate');
  info.shell.querySelector('.model-poster').src = posterURL(connector);
  model.setAttribute('alt', `Interactive ${connector.name} connector. Drag to rotate; scroll or pinch to zoom.`);
  try {
    await ensureComponent();
    if (info.requestId !== requestId) return;
    // Camera framing uses the mesh bounds. CAD units are not treated as meters.
    model.setAttribute('camera-target', 'auto auto auto');
    model.setAttribute('camera-orbit', '35deg 65deg auto');
    const source = modelURL(connector);
    // Clear a failed same-source request for one task, then reload it. A timer
    // also works in background tabs, where animation frames may be suspended.
    if (info.retrying && model.getAttribute('src') === source) {
      model.removeAttribute('src');
      await new Promise(resolve => setTimeout(resolve, 0));
      if (info.requestId !== requestId) return;
    }
    model.setAttribute('src', source);
    info.retrying = false;
    info.timeout = setTimeout(() => { if (info.requestId === requestId) setState(model, 'error'); }, 25000);
  } catch (error) {
    if (info.requestId === requestId) setState(model, 'error');
    console.warn('POP MAKERS: using the static connector preview.', error.message);
  }
}

for (const model of [heroModel, showcaseModel]) {
  const shell = model.closest('.viewer-shell');
  viewerStates.set(model, { shell, visible: model === heroModel, requestId: 0, connector: null, timeout: null, retrying: false });
  model.addEventListener('load', () => {
    const info = viewerStates.get(model);
    if (model.getAttribute('src') !== modelURL(info.connector)) return;
    clearTimeout(info.timeout);
    setState(model, 'ready');
    updateRotation();
    if (model === showcaseModel) status.textContent = `${info.connector.name} loaded. Drag to rotate, scroll or pinch to zoom.`;
  });
  model.addEventListener('error', () => { const info = viewerStates.get(model); clearTimeout(info.timeout); setState(model, 'error'); });
  shell.querySelector('.retry-button').addEventListener('click', () => { const info = viewerStates.get(model); info.retrying = true; loadConnector(model, info.connector); });
}

const cardsContainer = document.querySelector('#connector-cards');
connectors.forEach((connector, index) => {
  const card = document.createElement('button');
  card.type = 'button';
  card.className = 'connector-card';
  card.setAttribute('aria-pressed', String(index === 0));
  card.setAttribute('aria-controls', 'showcase-model');
  card.innerHTML = `<img src="${posterURL(connector)}" alt="" loading="lazy" width="700" height="700"><span><strong>${connector.name}</strong><span class="connector-description">${connector.description}</span><span class="connector-build">${connector.build}</span></span>`;
  card.addEventListener('click', () => {
    if (selectedIndex === index && viewerStates.get(showcaseModel).shell.dataset.state === 'ready') return;
    selectedIndex = index;
    cardsContainer.querySelectorAll('button').forEach((button, buttonIndex) => button.setAttribute('aria-pressed', String(buttonIndex === index)));
    document.querySelector('#connector-counter').textContent = `${String(index + 1).padStart(2, '0')} / 06`;
    showcasePoster.alt = `${connector.name} static preview`;
    status.textContent = `Loading ${connector.name}.`;
    showcaseStarted = true;
    loadConnector(showcaseModel, connector);
  });
  cardsContainer.append(card);
});

spinButton.addEventListener('click', () => {
  rotationRequested = !rotationRequested;
  // Explicit user control is allowed under reduced motion; automatic starting isn't.
  if (motionPreference.matches && rotationRequested) {
    showcaseModel.setAttribute('camera-orbit', `${(showcaseModel.getCameraOrbit().theta * 180 / Math.PI + 90) % 360}deg 65deg auto`);
    rotationRequested = false;
    status.textContent = 'Connector turned a quarter turn. Continuous motion is disabled by your reduced-motion preference.';
  }
  updateRotation();
});
spinButton.disabled = true;
updateRotation();
loadConnector(heroModel, connectors[2]);

if ('IntersectionObserver' in window) {
  const lazyObserver = new IntersectionObserver(entries => {
    if (entries.some(entry => entry.isIntersecting) && !showcaseStarted) {
      showcaseStarted = true;
      loadConnector(showcaseModel, connectors[selectedIndex]);
      lazyObserver.disconnect();
    }
  }, { rootMargin: '180px' });
  lazyObserver.observe(showcaseModel);
  const visibilityObserver = new IntersectionObserver(entries => entries.forEach(entry => {
    viewerStates.get(entry.target).visible = entry.isIntersecting;
    updateRotation();
  }));
  visibilityObserver.observe(heroModel);
  visibilityObserver.observe(showcaseModel);
} else { showcaseStarted = true; loadConnector(showcaseModel, connectors[0]); }
document.addEventListener('visibilitychange', updateRotation);
motionPreference.addEventListener('change', () => {
  rotationRequested = !motionPreference.matches;
  if (motionPreference.matches) document.querySelectorAll('.is-pending').forEach(element => element.classList.remove('is-pending'));
  updateRotation();
});

// Very small decorative parallax. No camera or layout movement.
const heroArt = document.querySelector('.hero-art');
heroArt.addEventListener('pointermove', event => {
  if (motionPreference.matches || event.pointerType === 'touch') return;
  const rect = heroArt.getBoundingClientRect();
  const x = (event.clientX - rect.left - rect.width / 2) / rect.width * 8;
  const y = (event.clientY - rect.top - rect.height / 2) / rect.height * 8;
  heroArt.querySelector('.hero-blob').style.translate = `${x}px ${y}px`;
});
heroArt.addEventListener('pointerleave', () => { heroArt.querySelector('.hero-blob').style.translate = '0 0'; });

// With JS disabled (or a module blocked), native navigation, FAQ, images, and
// the external interest links still work. Hide spinners once enhancement runs.
