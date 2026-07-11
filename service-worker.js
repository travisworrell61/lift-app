/* LIFT service worker
   Strategy: network-first with cache fallback, fetched with {cache:'reload'}.
   - Online: ALWAYS revalidates with the server, so your pushed changes show up on the
     next open. Plain network-first wasn't enough: GitHub Pages sends max-age=600 on the
     HTML, so WKWebView / the HTTP cache would hand the SW a stale page for up to 10 min
     after a push. {cache:'reload'} bypasses that cache and goes to origin.
   - Offline: serves the last cached version so the app still opens at the gym.
   NOTE: if you add new files to the app, add them to CORE below. */

const CACHE = 'lift-v5';   // bump purges old caches on activate
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
  const url = new URL(e.request.url);
  if (url.origin !== self.location.origin) return;   // cross-origin (Vercel API) → let the network handle it
  // Cache key ignores the query string, so the ?t= cache-busters on the JSON fetches map to ONE
  // stable entry (not a new one per launch that never matches offline and grows forever).
  const cacheKey = new Request(url.origin + url.pathname);
  e.respondWith(
    // {cache:'reload'} forces a network revalidation, ignoring the HTTP cache — so a push
    // is visible on the next online open instead of waiting out GitHub Pages' max-age=600.
    fetch(e.request, { cache: 'reload' })
      .then((res) => {
        if (res && res.ok) {   // only cache successful responses — a transient 404/503 must not poison the shell
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(cacheKey, copy)).catch(() => {});
        }
        return res;
      })
      .catch(() => caches.match(cacheKey).then((r) => {
        if (r) return r;
        // Offline miss with nothing cached: only fall back to the app shell for a NAVIGATION.
        // (Answering a failed .json/.png with index.html is what silently broke the library offline.)
        if (e.request.mode === 'navigate') return caches.match('./index.html');
        return new Response('', { status: 504, statusText: 'offline' });
      }))
  );
});
