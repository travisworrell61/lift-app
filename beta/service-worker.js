/* LIFT service worker (r4)
   Strategy: network-first with cache fallback, fetched with {cache:'reload'}.
   - Online: revalidates with the server so pushed changes show on the next open
     ({cache:'reload'} beats GitHub Pages' max-age=600).
   - Weak signal: if the network has not answered in NET_MS the CACHED copy is served at once, so
     the app paints from cache instead of sitting on a blank screen. The network fetch keeps going
     and refreshes the cache for next time.
   - Offline: serves the last cached version.
   - The cache name includes this worker's SCOPE, and activation deletes only older caches of THIS scope:
     the beta app (/lift-app/beta/) and the live app (/lift-app/) can never delete each other's cache.
   NOTE: if you add new files to the app, add them to CORE below. */

const SCOPE = new URL(self.registration.scope).pathname;     // '/lift-app/' (live) or '/lift-app/beta/' (beta)
const SUFFIX = '@' + SCOPE;
const CACHE = 'lift-r4' + SUFFIX;                             // bump r4 -> r5 to purge this scope's old cache
const NET_MS = 3000;
const CORE = [
  './',
  './index.html',
  './demo-logs.json',
  './demo-notes.json',
  './exercise-library.json',
  './equipment-catalog.json',
  './program.js',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './icon-180.png'
];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE).then((c) =>
      Promise.all(CORE.map((u) => c.add(new Request(u, { cache: 'reload' })).catch(() => {})))
    )
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      // only THIS scope's older caches (key ends with '@<scope>'); 'lift-v5' and the other app's caches are untouched
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE && k.endsWith(SUFFIX)).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

function fromCache(req, key) {
  return caches.open(CACHE).then((c) => c.match(key)).then((r) => {
    if (r) return r;
    if (req.mode === 'navigate') return caches.open(CACHE).then((c) => c.match(new Request(new URL('./index.html', self.registration.scope).href)));
    return null;
  });
}

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (url.origin !== self.location.origin) return;   // cross-origin (Vercel API) -> let the network handle it
  if (url.searchParams.has('b')) return;             // the new-version probe (?b=) must see the REAL network, never a cached copy (M2)
  // Cache key ignores the query string, so ?t= cache-busters map to ONE stable entry.
  const cacheKey = new Request(url.origin + url.pathname);
  e.respondWith(new Promise((resolve) => {
    let settled = false;
    const done = (r) => { if (!settled) { settled = true; resolve(r); } };
    const net = fetch(e.request, { cache: 'reload' }).then((res) => {
      if (res && res.ok) {   // only cache successful responses
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(cacheKey, copy)).catch(() => {});
      }
      return res;
    });
    const timer = setTimeout(() => { fromCache(e.request, cacheKey).then((r) => { if (r) done(r); }).catch(() => {}); }, NET_MS);
    net.then((res) => { clearTimeout(timer); done(res); },
      () => {
        clearTimeout(timer);
        fromCache(e.request, cacheKey)
          .then((r) => done(r || new Response('', { status: 504, statusText: 'offline' })))
          .catch(() => done(new Response('', { status: 504, statusText: 'offline' })));
      });
  }));
});
