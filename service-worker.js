const CACHE_NAME = 'bangnet-admin-pwa-v1';
const APP_SHELL = [
  './',
  './index.html',
  './manager.html',
  './manifest.webmanifest',
  './pwa-icon.svg'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);

  // Jangan cache API Supabase, autentikasi, CDN, atau permintaan non-GET.
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;

  // HTML selalu mencoba versi terbaru terlebih dahulu; cache hanya sebagai cadangan offline.
  if (request.mode === 'navigate' || url.pathname.endsWith('.html') || url.pathname.endsWith('/')) {
    event.respondWith(
      fetch(request)
        .then(response => {
          if (response && response.ok) {
            const copy = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put(request, copy));
          }
          return response;
        })
        .catch(async () => {
          const cached = await caches.match(request);
          return cached || caches.match('./index.html');
        })
    );
    return;
  }

  // Cache-first hanya untuk aset lokal PWA; jangan menyimpan data transaksi.
  if (['.webmanifest', '.svg'].some(ext => url.pathname.endsWith(ext))) {
    event.respondWith(
      caches.match(request).then(cached => cached || fetch(request).then(response => {
        if (response && response.ok) {
          const copy = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(request, copy));
        }
        return response;
      }))
    );
  }
});
