import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/app_language.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/theme/app_theme.dart';
import 'package:ishinydex/core/theme/app_theme_mode.dart';
import 'package:ishinydex/core/widgets/update_notice.dart';
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
    // Claro, escuro ou o do aparelho, de Ajustes → Aparência (#273).
    themeMode: ref.watch(appThemeModeProvider),
    // O idioma escolhido em Ajustes; em "Automático" (`null`), o do
    // aparelho, pelo [resolveLocale]: português vira pt-BR, o resto inglês.
    locale: ref.watch(appLanguageProvider).locale,
    supportedLocales: supportedLocales,
    localeListResolutionCallback: (device, _) => resolveLocale(device),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: ref.watch(routerProvider),
    // Na web, o `Title` grava o `<meta name="theme-color">`, que o iPhone usa
    // na barra de status (relógio, bateria). O do MaterialApp usa sempre o
    // tema claro; este, abaixo dele, usa a cor do AppBar do tema em uso e é
    // refeito quando o sistema troca entre claro e escuro.
    // O SyncLifecycle sincroniza com o Dropbox ao abrir e ao voltar ao app
    // (sem Dropbox neste build, não faz nada).
    // O UpdateNotice avisa quando sai uma versão nova com o app aberto.
    builder: (context, child) {
      // Datas e números formatados sem `locale` explícito (`DateFormat`,
      // `NumberFormat`) seguem o idioma da interface.
      Intl.defaultLocale = Localizations.localeOf(context).toString();
      return UpdateNotice(
        child: SyncLifecycle(
          child: Title(
            title: 'iShinyDex',
            color: Theme.of(context).colorScheme.surface,
            child: child!,
          ),
        ),
      );
    },
  );
}
