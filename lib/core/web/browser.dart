/// O que o app faz direto na página do navegador, sem plugin. No navegador
/// vale o `browser_web.dart`; fora dele (os testes, na VM), o
/// `browser_stub.dart`.
library;

export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
