import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

/// A planilha de onde vêm os atalhos (#34), nos créditos.
const austinJohnSheetUrl =
    'https://pokejungle.net/2023/03/27/how-to-organize-pokemon-home-for-a-living-dex/';

/// Nome do atalho, como aparece nos chips e na ajuda.
String presetLabel(AppLocalizations l10n, DexPreset? preset) =>
    switch (preset) {
      DexPreset.livingFormLite => l10n.dexPresetLivingFormLite,
      DexPreset.living => 'Living',
      DexPreset.finalFormForm => 'Final Form Form',
      DexPreset.finalForm => 'Final Form',
      null => l10n.dexPresetCustom,
    };

/// "O que entra" do Novo PersonalDex (#34): os atalhos da planilha de
/// Austin John e as três chaves. Um atalho liga as chaves; mexer numa chave
/// marca o atalho que tiver a mesma combinação, ou "Personalizado".
class DexRecipePicker extends StatelessWidget {
  const DexRecipePicker({
    required this.recipe,
    required this.onChanged,
    super.key,
  });

  final DexRecipe recipe;
  final ValueChanged<DexRecipe> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preset = recipe.preset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in DexPreset.values)
              ChoiceChip(
                label: Text(presetLabel(l10n, p)),
                selected: preset == p,
                onSelected: (_) => onChanged(DexRecipe.of(p)),
              ),
            // Uma combinação fora dos atalhos: só aparece, não se escolhe.
            if (preset == null)
              ChoiceChip(label: Text(presetLabel(l10n, null)), selected: true),
          ],
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.dexKeyRegional),
          subtitle: Text(l10n.dexKeyRegionalHint),
          value: recipe.regional,
          onChanged: (v) => onChanged(recipe.copyWith(regional: v)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.dexKeyPreEvolutions),
          subtitle: Text(l10n.dexKeyPreEvolutionsHint),
          value: recipe.preEvolutions,
          onChanged: (v) => onChanged(recipe.copyWith(preEvolutions: v)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.dexKeyAlternate),
          subtitle: Text(l10n.dexKeyAlternateHint),
          value: recipe.alternateForms,
          onChanged: (v) => onChanged(recipe.copyWith(alternateForms: v)),
        ),
      ],
    );
  }
}

/// O "?" do Novo PersonalDex: os tipos de dex, o critério do conjunto
/// padrão e os créditos a Austin John.
Future<void> showDexTypesHelp(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const DexTypesHelp(),
    );

class DexTypesHelp extends ConsumerWidget {
  const DexTypesHelp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    // Quantas formas cada atalho dá no catálogo carregado (sem catálogo,
    // como na demonstração antiga, a tabela vem sem os números).
    final catalog = ref.watch(catalogLoadProvider)?.catalog;
    final number = NumberFormat.decimalPattern();
    Widget mark({required bool on}) => Center(
      child: on
          ? Icon(Icons.check, size: 20, semanticLabel: l10n.dexTypesYes)
          : Text('—', semanticsLabel: l10n.dexTypesNo),
    );
    TableRow row(DexPreset preset) {
      final recipe = DexRecipe.of(preset);
      final count = catalog?.dexForms(recipe).length;
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presetLabel(l10n, preset),
                  style: theme.textTheme.bodyMedium,
                ),
                if (count != null)
                  Text(
                    l10n.dexTypesForms(number.format(count)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          mark(on: recipe.regional),
          mark(on: recipe.preEvolutions),
          mark(on: recipe.alternateForms),
        ],
      );
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium,
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(l10n.dexTypesTitle, style: theme.textTheme.titleLarge),
            Text(l10n.dexTypesIntro),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(),
                1: FixedColumnWidth(56),
                2: FixedColumnWidth(56),
                3: FixedColumnWidth(56),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    header(l10n.dexTypesColumnRegional),
                    header(l10n.dexTypesColumnPreEvolutions),
                    header(l10n.dexTypesColumnAlternate),
                  ],
                ),
                for (final preset in DexPreset.values) row(preset),
              ],
            ),
            Text(l10n.dexTypesCriteria, style: theme.textTheme.bodySmall),
            Card.filled(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(l10n.dexTypesCredit, style: theme.textTheme.bodySmall),
                    SelectableText(
                      austinJohnSheetUrl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
