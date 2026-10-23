import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/app.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/l10n/app_language.dart';
import 'package:ishinydex/core/web/offline_warmup.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/catalog/presentation/boot_failure_app.dart';

Future<void> main() async {
  // O shared_preferences (dados do modo local) usa canais da plataforma,
  // que só existem depois disto; antes do runApp, é preciso pedir.
  WidgetsFlutterBinding.ensureInitialized();
  // Catálogo e dados locais (modo local, ou demonstração com CATALOG_URL).
  final List<Override> overrides;
  var language = AppLanguage.system;
  try {
    // O idioma escolhido em Ajustes, para o primeiro quadro já sair nele.
    language = await const PrefsLanguageStorage().read();
    overrides = [
      initialLanguageProvider.overrideWithValue(language),
      ...await catalogOverrides(Env.fromEnvironment(), bootDio()),
    ];
  } on Object catch (error) {
    runApp(BootFailureApp(error: error, onRetry: main, language: language));
    return;
  }
  runApp(
    ProviderScope(
      retry: noRetry,
      overrides: overrides,
      child: const IShinyDexApp(),
    ),
  );
  // Guarda para usar offline o que o app só baixa quando usa (#337).
  if (kIsWeb) unawaited(warmUpOffline());
}
