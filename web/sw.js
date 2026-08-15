// GRJ Service Worker v20260815
// Offline-first caching for zero-latency WASM execution
const CACHE_NAME = 'grj-cache-v20260815';

const PRECACHE_ASSETS = [
  '/',
  '/manifest.json',
  '/flutter_bootstrap.js',
  '/icons/GRJ-192.png',
  '/icons/GRJ-512.png',
  '/icons/GRJ-maskable-192.png',
  '/icons/GRJ-maskable-512.png',
  '/icons/logo-gold.svg',
];

// Cache on install
self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function (cache) {
      return cache.addAll(PRECACHE_ASSETS).catch(function () {});
    }).then(function () {
      return self.skipWaiting();
    })
  );
});

// Remove old caches on activate
self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (cacheNames) {
      return Promise.all(
        cacheNames.map(function (name) {
          if (name !== CACHE_NAME) {
            return caches.delete(name);
          }
        })
      );
    }).then(function () {
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', function (event) {
  var request = event.request;

  // Only handle GET; skip non-same-origin
  if (request.method !== 'GET') return;
  try {
    var reqUrl = new URL(request.url);
    if (reqUrl.origin !== self.location.origin) return;
    // Skip API calls and dynamic routes
    if (reqUrl.pathname.startsWith('/api/')) return;
  } catch (_) { return; }

  // Navigation (HTML): network-first so updates propagate immediately
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(function () {
        return caches.match('/').then(function (cached) {
          return cached || caches.match(request);
        });
      })
    );
    return;
  }

  // WASM / JS / fonts / images: cache-first for zero-latency re-loads
  var url = request.url;
  if (/\.(wasm|js|dart\.js|ttf|woff2?|png|svg|ico|gif|jpg|jpeg|css)(\?|$)/.test(url)) {
    event.respondWith(
      caches.match(request).then(function (cached) {
        if (cached) return cached;
        return fetch(request).then(function (response) {
          if (response && response.status === 200) {
            var clone = response.clone();
            caches.open(CACHE_NAME).then(function (cache) {
              cache.put(request, clone);
            });
          }
          return response;
        }).catch(function () { return cached; });
      })
    );
    return;
  }

  // Everything else: network only
});
