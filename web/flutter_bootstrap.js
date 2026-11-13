{{flutter_js}}
{{flutter_build_config}}

// Cache-busting do deploy (issue #5).
//
// O Flutter gera sempre os mesmos nomes (main.dart.js, assets/...), então o
// navegador reusaria uma versão antiga em cache. No build do GitHub Pages
// (tool/build_pages.sh do repositório principal), __BUILD_VERSION__ vira um
// hash do build, e o app passa a ser carregado de v/<hash>/: o endereço muda
// a cada versão. Fora dele (flutter run, CI) o marcador não é trocado e o
// app carrega como no template padrão.
const buildVersion = '__BUILD_VERSION__';

if (buildVersion.startsWith('__')) {
  // Sem versão: exatamente a chamada do template padrão do Flutter. Passar
  // um `config`, mesmo vazio, trava o app no modo debug (flutter run/drive).
  _flutter.loader.load();
} else {
  const base = `v/${buildVersion}/`;
  _flutter.loader.load({
    config: {
      entrypointBaseUrl: base,
      assetBase: base,
      // O motor (canvaskit/, skwasm) também vem de v/<hash>/ (#404): fora
      // dele, o endereço era o mesmo em toda versão, e o service worker da
      // versão anterior devolvia o motor antigo do cache. Com o Flutter
      // novo, o main.dart.wasm não casava com ele e o app parava no splash.
      canvasKitBaseUrl: `${base}canvaskit/`,
      // WebAssembly também no Safari (26.2+, inclusive no iPhone) desde o
      // Flutter 3.50 (#402); o padrão só liga no Chrome/Edge (blink). Em
      // navegador sem suporte, o carregador usa o build em JavaScript.
      wasmAllowList: { blink: true, webkit: true },
      // O GitHub Pages não manda os headers COOP/COEP, então o Wasm roda numa
      // thread só; sem isto, o console avisa a cada abertura.
      suppressMultithreadingWarning: true,
    },
  });
}
