import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:ishinydex/core/network/app_failure.dart';
import 'package:web/web.dart' as web;

/// Arquivo escolhido: nome e conteúdo.
typedef PickedFile = ({String name, Uint8List bytes});

/// Abre o seletor de arquivos do sistema; `null` se a pessoa desistir.
/// Arquivo ilegível → [DataFailure].
///
/// O `<input type=file>` fica na página até a escolha chegar: o Safari do
/// iOS não avisa a escolha (evento `change`) a um input fora da página, e
/// é o que o `file_picker` faz (tira o input logo depois do clique). Este
/// arquivo só roda no navegador; fica fora da cobertura dos testes (VM).
Future<PickedFile?> pickFileInPage({required String accept}) {
  final completer = Completer<PickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  // Invisível, mas na página (sem display:none, que alguns navegadores
  // tratam como fora dela).
  input.style.cssText =
      'position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;'
      'pointer-events:none';

  void finish(PickedFile? file, [Object? error]) {
    input.remove();
    if (completer.isCompleted) return;
    error == null ? completer.complete(file) : completer.completeError(error);
  }

  Future<void> read(web.File file) async {
    try {
      final buffer = await file.arrayBuffer().toDart;
      finish((name: file.name, bytes: buffer.toDart.asUint8List()));
    } on Object {
      finish(null, DataFailure(Problem.unreadableFile(file.name)));
    }
  }

  input
    ..addEventListener(
      'change',
      (web.Event _) {
        final file = input.files?.item(0);
        file == null ? finish(null) : unawaited(read(file));
      }.toJS,
    )
    ..addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  web.document.body!.append(input);
  input.click();
  return completer.future;
}

/// Sai do app para [url], na mesma janela (no iPhone e no iPad, o login do
/// Dropbox volta para o app instalado só assim; ishinydex#53).
void openUrl(String url) => web.window.location.assign(url);

/// Abre [url] numa aba nova, sem sair do app (o post da caçada).
void openInNewTab(String url) => web.window.open(url, '_blank');

/// Chama [onReady] quando há uma versão nova do app pronta (#228): o
/// `index.html` dispara `ishinydex-update-ready` quando o service worker
/// novo assume. Se o aviso chegou antes do app ouvir, chama logo.
void onAppUpdateReady(void Function() onReady) {
  if (web.window.getProperty<JSBoolean?>('ishinydexUpdateReady'.toJS)?.toDart ??
      false) {
    onReady();
    return;
  }
  web.window.addEventListener(
    'ishinydex-update-ready',
    ((web.Event _) => onReady()).toJS,
  );
}

/// Recarrega a página: abre a versão nova do app.
void reloadPage() => web.window.location.reload();

/// Troca o endereço na barra sem recarregar (tira o `?code=` da volta do
/// login, para um recarregamento não tentar usá-lo de novo).
void replaceUrl(String url) => web.window.history.replaceState(null, '', url);
