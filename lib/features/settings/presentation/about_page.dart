import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_recipe_picker.dart';

/// Endereço do código, mostrado (selecionável) em "Sobre".
const projectUrl = 'https://github.com/nunesvictor/ishinydex';

/// Ajustes → Sobre o iShinyDex: versão, privacidade e aviso legal.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(envProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    Widget section(String title, List<String> paragraphs) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          for (final text in paragraphs)
            Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: Center(
        child: ConstrainedBox(
          // Texto corrido: linhas longas demais cansam a leitura no PC.
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome, size: 40),
                title: const Text('iShinyDex'),
                subtitle: Text(l10n.settingsVersion(env.appVersion)),
              ),
              const SelectableText(projectUrl),
              if (ref.watch(catalogLoadProvider) case final load?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.aboutCatalog(
                      load.catalog.version,
                      load.elapsed.inMilliseconds,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 24),
              section(l10n.aboutPrivacy, [
                if (env.localData) ...[
                  l10n.aboutLocalData,
                  if (env.syncAvailable) l10n.aboutSyncData,
                ] else ...[
                  l10n.aboutDemoData,
                  l10n.aboutDemoNothingSent,
                ],
              ]),
              // A classificação dos dex pré-moldados (#34) vem da planilha
              // de Austin John: usamos a ideia, não os dados.
              section(l10n.aboutCredits, [l10n.dexTypesCredit]),
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: SelectableText(austinJohnSheetUrl),
              ),
              section(l10n.aboutLegal, [
                l10n.aboutTrademarks,
                l10n.aboutFanProject,
                l10n.aboutSources,
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
