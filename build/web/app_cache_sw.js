// Hand-written offline cache — no build step, no package, just the
// standard Service Worker API (same "native platform API over a
// pub.dev dependency" posture as the rest of this app). Flutter's own
// generated flutter_service_worker.js stopped doing real caching a
// while back (current Flutter versions ship it purely as a one-time
// "unregister whatever old service worker is here" cleanup step), so
// this is the only thing actually making a repeat visit work with a
// flaky or absent connection. Registered from web/flutter_bootstrap.js
// as a fully separate service worker — Flutter's own SW registration
// is deliberately left out of that file so the two never compete for
// the same scope.
const CACHE_NAME = 'ql-cache-v1';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

// Network-first, falling back to cache: every successful same-origin
// GET response is cached as a side effect, and a failed fetch (offline,
// or a flaky connection) is served from whatever's already cached — a
// navigation request with no exact cache entry falls back to the
// cached app shell (index.html) instead, since this is a client-routed
// single-page app and any path should still boot the app offline. API
// calls (api.quran.com, everyayah.com, Supabase) are cross-origin and
// never reach this handler at all — they either need to be live or
// already have their own caching (see offline_audio.dart's Cache
// Storage wrapper for recitation audio).
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, copy));
        }
        return res;
      })
      .catch(async () => {
        const cached = await caches.match(req);
        if (cached) return cached;
        if (req.mode === 'navigate') {
          const shell = await caches.match('index.html');
          if (shell) return shell;
        }
        return Response.error();
      }),
  );
});
