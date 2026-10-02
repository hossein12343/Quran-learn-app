// Hand-written offline cache — no build step, no package, just the
// standard Service Worker API (same "native platform API over a
// pub.dev dependency" posture as the rest of this app). Flutter's own
// generated flutter_service_worker.js stopped doing real caching a
// while back (current Flutter versions ship it purely as a one-time
// "unregister whatever old service worker is here" cleanup step), so
// this is what makes a repeat visit fast and work offline. Registered
// from web/flutter_bootstrap.js as a fully separate service worker —
// Flutter's own SW registration is deliberately left out of that file so
// the two never compete for the same scope.

// Replaced with a hash of the build by tools/build_web.py. Each build gets
// its own cache, so files from two builds are never mixed; a new build
// changes this file, which is how the browser notices there's an update.
const BUILD = '28ddef625516';
const STAMPED = !BUILD.startsWith('__');
const APP_CACHE = 'ql-app-' + BUILD;
// Only this worker's own caches are ever cleared — never others, such as
// offline_audio.dart's 'quran-audio-v1' (recitation downloaded for
// offline use), which the old version of this file used to wipe on every
// update.
const OWN_PREFIX = 'ql-';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((k) => k.startsWith(OWN_PREFIX) && k !== APP_CACHE)
            .map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

// Saving runs alongside handing the response to the page. waitUntil keeps
// the worker alive until the copy is saved: without it the browser may stop
// an idle-looking worker partway through a large file (the 5 MB graphics
// engine), which would lose the copy.
function store(event, req, res) {
  if (res && res.status === 200 && res.type === 'basic') {
    const copy = res.clone();
    event.waitUntil(
      caches
        .open(APP_CACHE)
        .then((cache) => cache.put(req, copy))
        .catch(() => {}),
    );
  }
  return res;
}

// Opening the app (a navigation) is answered from the saved copy too. It
// used to ask the network first, with a 3 s limit — on a throttled
// connection every open then waited the full 3 s. It doesn't need to: a
// new release changes this worker, the browser checks for that on its own
// in the background, and the new worker brings a fresh copy.
async function navigate(event, req) {
  const cache = await caches.open(APP_CACHE);
  // Every app route (/, /home, /login, …) is the same page; the site's
  // own documents (privacy.html, eula.html) are saved under their own name.
  const path = new URL(req.url).pathname;
  const key = path.endsWith('.html') && !path.endsWith('/index.html')
    ? req
    : '/';
  const saved = await cache.match(key);
  if (saved) return saved;
  const res = await fetch(req, { cache: 'no-cache' });
  if (res && res.ok) {
    event.waitUntil(cache.put(key, res.clone()).catch(() => {}));
  }
  return res;
}

// Everything else — app code, the graphics engine, fonts, the Quran text —
// only changes with a new build, so within a build it comes straight from
// the saved copy. Asking the server first cost a round trip for every
// file on every open (about 7 in a row before the app could start).
async function fromCache(event, req) {
  const saved = await caches.match(req, { cacheName: APP_CACHE });
  if (saved) return saved;
  // Checked with the server (`no-cache`), never taken from the browser's
  // own HTTP cache unchecked: that could hold a file from the previous
  // build and save it into this build's copy.
  return store(event, req, await fetch(req, { cache: 'no-cache' }));
}

// The old behaviour, kept for a build that wasn't stamped: always correct,
// just slower.
async function networkFirst(event, req) {
  try {
    return store(event, req, await fetch(req));
  } catch (err) {
    const saved = await caches.match(req);
    if (saved) return saved;
    if (req.mode === 'navigate') {
      const shell = await caches.match('/');
      if (shell) return shell;
    }
    throw err;
  }
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // API calls (Supabase, api.quran.com, everyayah.com, …) are cross-origin
  // and never handled here.
  if (url.origin !== self.location.origin) return;
  // The worker itself must always come from the network, or it could
  // never update.
  if (url.pathname.endsWith('app_cache_sw.js')) return;

  if (!STAMPED) {
    event.respondWith(networkFirst(event, req));
  } else if (req.mode === 'navigate') {
    event.respondWith(navigate(event, req));
  } else {
    event.respondWith(fromCache(event, req));
  }
});
