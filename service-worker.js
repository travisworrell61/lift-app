/* LIFT service worker
   Strategy: network-first with cache fallback, fetched with {cache:'reload'}.
   - Online: ALWAYS revalidates with the server, so your pushed changes show up on the
     next open. Plain network-first wasn't enough: GitHub Pages sends max-age=600 on the
     HTML, so WKWebView / the HTTP cache would hand the SW a stale page for up to 10 min
     after a push. {cache:'reload'} bypasses that cache and goes to origin.
   - Offline: serves the last cached version so the app still opens at the gym.
   NOTE: if you add new files to the app, add them to CORE below. */

const CACHE = 'lift-v4';   // bump purges old caches on activate
const CORE = [
  './',
  './index.html',
  './program.js',
  './exercise-library.json',
  './equipment-catalog.json',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './icon-180.png'
];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  // Prime the cache with FRESH copies (cache:'reload' bypasses the HTTP cache on install too).
  e.waitUntil(
    caches.open(CACHE).then((c) =>
      Promise.all(CORE.map((u) => c.add(new Request(u, { cache: 'reload' })).catch(() => {})))
    )
  );
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
    // {cache:'reload'} forces a network revalidation, ignoring the HTTP cache — so a push
    // is visible on the next online open instead of waiting out GitHub Pages' max-age=600.
    fetch(e.request, { cache: 'reload' })
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(e.request).then((r) => r || caches.match('./index.html')))
  );
});
