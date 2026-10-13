// Service worker do iShinyDex (etapa 5 de ishinydex#48): o app abre e
// funciona sem internet depois de um uso online. O do Flutter não guarda
// cache offline; este guarda cada arquivo na primeira vez que é usado, sem
// lista fixa de arquivos.
//
// - Versionados (v/<hash>/, canvaskit/): cache primeiro. Nunca mudam: um
//   build novo tem outro hash.
// - Resto do próprio site (index.html, flutter_bootstrap.js, manifesto,
//   ícones, catalog/catalog.json): rede primeiro, com o cache de reserva.
// - Sprites (raw do PokeAPI/sprites, com CORS): cache primeiro, num cache
//   que sobrevive às versões do app.
// - Nunca passa pelo cache: o que não é GET (o Dropbox, por exemplo).
'use strict';

// Trocado pelo hash do build (tool/build_pages.sh do repositório
// principal), como no flutter_bootstrap.js.
const VERSION = '__BUILD_VERSION__';
const APP_CACHE = `ishinydex-app-${VERSION}`;
const SPRITES_CACHE = 'ishinydex-sprites';
const SPRITES_HOST = 'raw.githubusercontent.com';

self.addEventListener('install', (event) => {
  // O essencial para abrir offline já na primeira vez. Sem skipWaiting():
  // ao abrir a página, o navegador procura um sw.js novo sozinho, e um
  // worker que assumisse logo derrubaria os downloads do boot no iOS (o app
  // ficava no splash na primeira abertura de cada versão, #228). O novo
  // espera a página pedir ('skip-waiting'), depois do primeiro quadro.
  event.waitUntil(
    caches
      .open(APP_CACHE)
      .then((cache) => cache.addAll(['./', 'flutter_bootstrap.js', 'manifest.json']))
      .catch(() => undefined),
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'skip-waiting') self.skipWaiting();
  // A página compara com a versão dela para saber se há versão nova (#228).
  if (event.data === 'version') {
    event.source?.postMessage({ type: 'version', version: VERSION });
  }
});

self.addEventListener('activate', (event) => {
  // Fica com a versão atual e a anterior: se a pessoa ficar offline logo
  // depois de uma atualização, a versão anterior continua abrindo.
  event.waitUntil(
    caches
      .keys()
      .then((names) => {
        const apps = names.filter((n) => n.startsWith('ishinydex-app-') && n !== APP_CACHE);
        return Promise.all(apps.slice(0, -1).map((n) => caches.delete(n)));
      })
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);

  if (url.host === SPRITES_HOST) {
    event.respondWith(cacheFirst(SPRITES_CACHE, request));
    return;
  }
  if (url.origin !== self.location.origin) return;

  // canvaskit/ (o motor) só é do próprio site com o --no-web-resources-cdn
  // do build do Pages; sem ele, viria do www.gstatic.com, fora do cache, e o
  // app não abriria offline.
  if (/\/(v\/[0-9a-f]+|canvaskit)\//.test(url.pathname)) {
    event.respondWith(cacheFirst(APP_CACHE, request));
  } else {
    event.respondWith(networkFirst(APP_CACHE, request));
  }
});

async function cacheFirst(name, request) {
  const cache = await caches.open(name);
  const hit = await cache.match(request);
  if (hit) return hit;
  // Guardado por outra versão do worker: na primeira abertura de uma versão
  // nova, quem ainda controla a página é o worker anterior, e os arquivos da
  // versão nova vão para o cache dele. Copia para o cache atual, que é o que
  // fica quando o anterior for apagado.
  const old = await caches.match(request);
  if (old) {
    cache.put(request, old.clone());
    return old;
  }
  const response = await fetch(request);
  if (response.ok) cache.put(request, response.clone());
  return response;
}

async function networkFirst(name, request) {
  const cache = await caches.open(name);
  try {
    const response = await fetch(request);
    if (response.ok) cache.put(request, response.clone());
    return response;
  } catch (error) {
    // Offline: a última versão guardada, de qualquer versão do app.
    const hit = (await cache.match(request)) || (await caches.match(request));
    if (hit) return hit;
    throw error;
  }
}
