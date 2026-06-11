/* LIFT service worker
   Strategy: network-first with cache fallback.
   - Online: always fetches the newest version (your pushed changes show up automatically).
   - Offline: serves the last cached version so the app still opens at the gym.
   NOTE: if you add new files to the app, add them to CORE below. */

const CACHE = 'lift-v2';   // bump purges old caches on activate
const CORE = [
  './',
  './index.html',
  './program.js',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './icon-180.png'
];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(CORE).catch(() => {})));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  // Same-origin only: API calls (Vercel / raw GitHub) carry unique cache-buster
  // params — caching them would grow the cache forever and serve nothing useful.
  if (new URL(e.request.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(e.request).then((r) => r || caches.match('./index.html')))
  );
});
