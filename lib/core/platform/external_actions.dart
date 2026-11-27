import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ishinydex/core/web/browser.dart' as browser;
import 'package:ishinydex/core/web/share_outcome.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// O que o app faz fora dele, em cada plataforma (#428, #429). No PWA, o
// navegador (`browser.dart`); no app nativo, o sistema. As funções do
// navegador lançam `UnsupportedError` fora dele: antes desta escolha, o
// toque não fazia nada no nativo.

/// Compartilha um arquivo pela folha do sistema; [origin] é de onde a folha
/// sai no iPad (lá ela é um balão, e sem a origem o iOS a recusa).
typedef FileSharer = Future<ShareOutcome> Function(
  Uint8List bytes, {
  required String name,
  required String type,
  Rect? origin,
});

/// Abre [url] fora do app (o `launchUrl`, trocável nos testes).
typedef ExternalLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// Mostra a folha de compartilhamento nativa (o `SharePlus.share`,
/// trocável nos testes).
typedef NativeShare = Future<ShareResult> Function(ShareParams params);

/// Abre um link externo: no PWA, numa aba nova; no nativo, no navegador do
/// sistema (#429).
void Function(String url) linkOpener({
  bool web = kIsWeb,
  ExternalLauncher launch = launchUrl,
}) {
  if (web) return browser.openInNewTab;
  return (url) => unawaited(
    launch(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((Object _) => false),
  );
}

/// Compartilha um arquivo: no PWA, pelo Web Share do navegador; no nativo,
/// pela folha do iOS (#428).
FileSharer fileSharer({bool web = kIsWeb, NativeShare? share}) {
  if (web) {
    return (bytes, {required name, required type, origin}) =>
        browser.shareFile(bytes, name: name, type: type);
  }
  return (bytes, {required name, required type, origin}) => shareNatively(
    bytes,
    name: name,
    type: type,
    origin: origin,
    share: share,
  );
}

/// A folha de compartilhamento do sistema com o arquivo. O iOS diz se a
/// pessoa escolheu um destino ([ShareOutcome.shared]) ou fechou a folha
/// ([ShareOutcome.cancelled]); um erro vira [ShareOutcome.failed].
Future<ShareOutcome> shareNatively(
  Uint8List bytes, {
  required String name,
  required String type,
  Rect? origin,
  NativeShare? share,
}) async {
  try {
    final result = await (share ?? SharePlus.instance.share)(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: type, name: name)],
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      ),
    );
    return result.status == ShareResultStatus.success
        ? ShareOutcome.shared
        : ShareOutcome.cancelled;
  } on Object {
    return ShareOutcome.failed;
  }
}
