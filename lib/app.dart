import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/theme/app_theme.dart';
import 'package:ishinydex/features/sync/presentation/sync_lifecycle.dart';

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
    // Na web, o `Title` grava o `<meta name="theme-color">`, que o iPhone usa
    // na barra de status (relógio, bateria). O do MaterialApp usa sempre o
    // tema claro; este, abaixo dele, usa a cor do AppBar do tema em uso e é
    // refeito quando o sistema troca entre claro e escuro.
    // O SyncLifecycle sincroniza com o Dropbox ao abrir e ao voltar ao app
    // (sem Dropbox neste build, não faz nada).
    builder: (context, child) => SyncLifecycle(
      child: Title(
        title: 'iShinyDex',
        color: Theme.of(context).colorScheme.surface,
        child: child!,
      ),
    ),
  );
}
