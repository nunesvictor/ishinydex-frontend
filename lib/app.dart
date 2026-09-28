import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/theme/app_theme.dart';

/// Desliga o retry automático do Riverpod 3: as telas têm botão
/// "Tentar novamente" e os erros de validação não devem ser repetidos.
Duration? noRetry(int retryCount, Object error) => null;

class IShinyDexApp extends ConsumerWidget {
  const IShinyDexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'iShinyDex',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(routerProvider),
  );
}
