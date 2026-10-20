import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

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

/// O nome de um jogo pelas versões dele ("Ultra Sun / Ultra Moon").
String gameLabel(Catalog catalog, String group) {
  final versions = catalog.gameVersions(group);
  return versions.isEmpty
      ? prettifyName(group)
      : versions.map(versionLabel).join(' / ');
}

/// O começo do Novo PersonalDex (#34): a base (Nacional ou um jogo, com as
/// pokédex dele) e "O que entra", com os atalhos da planilha de Austin John
/// e as chaves. Um atalho liga as chaves; mexer numa chave marca o atalho
/// que tiver a mesma combinação, ou "Personalizado". Sem catálogo (a
/// demonstração antiga), só o Nacional.
class DexRecipePicker extends ConsumerWidget {
  const DexRecipePicker({
    required this.recipe,
    required this.onChanged,
    super.key,
  });

  final DexRecipe recipe;
  final ValueChanged<DexRecipe> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final preset = recipe.preset;
    final catalog = ref.watch(catalogLoadProvider)?.catalog;
    final games = catalog?.dexGames ?? const <String>[];
    // Os saves desde já: o jogo padrão sai deles ao tocar em "Por jogo".
    final owned = catalog == null
        ? const <String, int>{}
        : _ownedGames(catalog, ref);
    final hint = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (catalog != null && games.isNotEmpty) ...[
          Text(l10n.dexStartFrom, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.dexNational)),
              ButtonSegment(value: true, label: Text(l10n.dexByGame)),
            ],
            selected: {recipe.byGame},
            onSelectionChanged: (selection) => onChanged(
              selection.single
                  ? _withGame(catalog, _defaultGame(catalog, owned))
                  : recipe.copyWith(
                      versionGroup: null,
                      pokedexes: const <String>[],
                    ),
            ),
          ),
          if (recipe.versionGroup case final group?) ...[
            const SizedBox(height: 12),
            _GameSelect(
              catalog: catalog,
              group: group,
              onSelected: (group) => onChanged(_withGame(catalog, group)),
            ),
            const SizedBox(height: 8),
            Text(l10n.dexGamePokedexesHint, style: hint),
            _PokedexChecks(
              catalog: catalog,
              recipe: recipe,
              onChanged: onChanged,
            ),
          ],
          const Divider(height: 32),
        ],
        Text(l10n.dexWhatGoesIn, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in DexPreset.values)
              ChoiceChip(
                label: Text(presetLabel(l10n, p)),
                selected: preset == p,
                onSelected: (_) => onChanged(recipe.withPreset(p)),
              ),
            // Uma combinação fora dos atalhos: só aparece, não se escolhe.
            if (preset == null)
              ChoiceChip(label: Text(presetLabel(l10n, null)), selected: true),
          ],
        ),
        const SizedBox(height: 4),
        // No dex por jogo não há a chave das regionais: cada espécie entra
        // com as formas que existem no jogo.
        if (recipe.byGame)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.dexGameFormsNote, style: hint),
          )
        else
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

  /// O jogo, com as pokédex marcadas por padrão; as chaves continuam, e as
  /// regionais voltam a valer (não há a chave delas no dex por jogo).
  DexRecipe _withGame(Catalog catalog, String group) => recipe.copyWith(
    regional: true,
    versionGroup: group,
    pokedexes: [
      for (final dex in catalog.gamePokedexes(group))
        if (dex.selectedByDefault) dex.name,
    ],
  );

  /// O jogo mais recente dos seus saves; sem saves de jogos com pokédex, o
  /// mais recente do HOME.
  String _defaultGame(Catalog catalog, Map<String, int> owned) => catalog
      .dexGames
      .lastWhere(owned.containsKey, orElse: () => catalog.dexGames.last);
}

/// Os jogos dos seus saves: grupo → quantos saves.
Map<String, int> _ownedGames(Catalog catalog, WidgetRef ref) {
  final result = <String, int>{};
  for (final save in ref.watch(savesProvider).value ?? const <Save>[]) {
    final group = save.trainer.version == null
        ? null
        : catalog.groupOf(save.trainer.version!);
    if (group != null) result[group] = (result[group] ?? 0) + 1;
  }
  return result;
}

/// O jogo do dex: um menu com os jogos dos seus saves primeiro.
class _GameSelect extends ConsumerWidget {
  const _GameSelect({
    required this.catalog,
    required this.group,
    required this.onSelected,
  });

  final Catalog catalog;
  final String group;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final owned = _ownedGames(catalog, ref);
    final number = NumberFormat.decimalPattern();
    // Do mais recente ao mais antigo, como o usuário pensa nos jogos.
    final games = catalog.dexGames.reversed.toList();
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text, style: theme.textTheme.labelMedium),
    );
    Widget item(String g, String detail) => MenuItemButton(
      key: ValueKey('dex-game-$g'),
      leadingIcon: GameIcon(catalog.gameVersions(g).first),
      onPressed: g == group ? null : () => onSelected(g),
      child: ConstrainedBox(
        // No celular, o menu não passa da tela (o ícone e as margens ficam
        // fora do texto).
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 112).clamp(120, 260),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(gameLabel(catalog, g)),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    String species(String g) =>
        l10n.dexGameSpecies(number.format(catalog.gameSpecies(g)));
    final mine = [
      for (final g in games)
        if (owned.containsKey(g)) g,
    ];
    final others = [
      for (final g in games)
        if (!owned.containsKey(g)) g,
    ];
    return MenuAnchor(
      menuChildren: [
        if (mine.isNotEmpty) ...[
          header(l10n.dexYourSaves),
          for (final g in mine)
            item(g, '${l10n.dexGameSaves(owned[g]!)} · ${species(g)}'),
          if (others.isNotEmpty) const Divider(),
        ],
        if (others.isNotEmpty) ...[
          if (mine.isNotEmpty) header(l10n.dexOtherGames),
          for (final g in others) item(g, species(g)),
        ],
      ],
      builder: (context, controller, _) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: controller.isOpen ? controller.close : controller.open,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.dexGame,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Row(
            spacing: 12,
            children: [
              GameIcon(catalog.gameVersions(group).first),
              Expanded(child: Text(gameLabel(catalog, group))),
            ],
          ),
        ),
      ),
    );
  }
}

/// As pokédex do jogo, para marcar: a principal e as das DLCs vêm marcadas;
/// as listas extras e as que já estão numa anterior (as ilhas de Alola),
/// não.
class _PokedexChecks extends StatelessWidget {
  const _PokedexChecks({
    required this.catalog,
    required this.recipe,
    required this.onChanged,
  });

  final Catalog catalog;
  final DexRecipe recipe;
  final ValueChanged<DexRecipe> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final number = NumberFormat.decimalPattern();
    final choices = catalog.gamePokedexes(recipe.versionGroup!);
    final main = choices
        .where((c) => c.dlc == null && !c.extra && c.coveredBy == null)
        .firstOrNull;
    String? hint(GameDexChoice choice) => switch (choice) {
      GameDexChoice(:final coveredBy?) => l10n.dexCoveredBy(
        context.catalogText(coveredBy, choice.coveredByLabels),
      ),
      GameDexChoice(extra: true) => l10n.dexExtraList,
      GameDexChoice(:final dlc?) => l10n.dexPokedexDlc(prettifyName(dlc)),
      _ when choice == main => l10n.dexMainPokedex,
      _ => null,
    };
    return Column(
      children: [
        for (final choice in choices)
          CheckboxListTile(
            key: ValueKey('dex-pokedex-${choice.name}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: recipe.pokedexes.contains(choice.name),
            title: Text(context.catalogText(choice.label, choice.labels)),
            subtitle: switch (hint(choice)) {
              final text? => Text(text),
              null => null,
            },
            secondary: Text(number.format(choice.species)),
            onChanged: (checked) {
              final picked = {...recipe.pokedexes};
              checked! ? picked.add(choice.name) : picked.remove(choice.name);
              onChanged(
                recipe.copyWith(
                  // Na ordem das pokédex do jogo, e não na ordem dos toques.
                  pokedexes: [
                    for (final c in choices)
                      if (picked.contains(c.name)) c.name,
                  ],
                ),
              );
            },
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
