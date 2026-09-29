{{flutter_js}}
{{flutter_build_config}}

// Cache-busting do deploy (issue #5).
//
// O Flutter gera sempre os mesmos nomes (main.dart.js, assets/...), então o
// navegador reusaria uma versão antiga em cache. No build Docker,
// __BUILD_VERSION__ vira um hash do build, e o app passa a ser carregado de
// v/<hash>/: o endereço muda a cada versão e o nginx pode fazer cache longo.
// Este arquivo é sempre revalidado (no-cache), então aponta para a versão
// nova assim que ela sobe. Fora do Docker (flutter run, CI) o marcador não é
// trocado e o app carrega como no template padrão.
const buildVersion = '__BUILD_VERSION__';

if (buildVersion.startsWith('__')) {
  // Sem versão: exatamente a chamada do template padrão do Flutter. Passar
  // um `config`, mesmo vazio, trava o app no modo debug (flutter run/drive).
  _flutter.loader.load();
} else {
  const base = `v/${buildVersion}/`;
  _flutter.loader.load({
    config: { entrypointBaseUrl: base, assetBase: base },
  });
}
