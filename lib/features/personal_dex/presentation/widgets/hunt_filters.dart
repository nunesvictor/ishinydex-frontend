import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/chip_icons.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_labels.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Abre os filtros de escopo das caçadas (fecha no HOME, categoria,
/// geração, tipo, shiny impossível): bottom sheet no compacto, diálogo nos
/// demais. Retorna a consulta nova ao aplicar, ou `null` se o usuário fechou
/// sem aplicar. Com [dexId], as opções de "Fim do Pokémon Bank" mostram quantas
/// caçadas dão.
Future<HuntQuery?> showHuntFilters(
  BuildContext context,
  HuntQuery query, {
  int? dexId,
}) {
  final panel = HuntFiltersPanel(initial: query, dexId: dexId);
  if (WindowSize.of(context).isCompact) {
    return showModalBottomSheet<HuntQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: panel,
      ),
    );
  }
  return showDialog<HuntQuery>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: panel,
      ),
    ),
  );
}

/// Conteúdo da folha: edita um rascunho; só "Mostrar resultados" devolve.
/// Os motivos não entram aqui: ficam sempre à vista na tela de caçadas.
class HuntFiltersPanel extends ConsumerStatefulWidget {
  const HuntFiltersPanel({required this.initial, this.dexId, super.key});

  final HuntQuery initial;
  final int? dexId;

  @override
  ConsumerState<HuntFiltersPanel> createState() => _HuntFiltersPanelState();
}

class _HuntFiltersPanelState extends ConsumerState<HuntFiltersPanel> {
  late HuntQuery _draft = widget.initial;

  void _update(HuntQuery draft) => setState(() => _draft = draft);

  static List<T> _toggle<T>(List<T> values, T value, bool on) =>
      on ? [...values, value] : [...values.where((v) => v != value)];

  @override
  Widget build(BuildContext context) {
    final options =
        ref.watch(specimenOptionsProvider).value ?? const SpecimenOptions();
    final theme = Theme.of(context);
    final cutoff = ref.watch(nextHomeCutoffProvider);
    final dexId = widget.dexId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.filtersTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: _draft.scopeCount == 0
                    ? null
                    : () => _update(_draft.clearScope()),
                child: Text(context.l10n.clearAction),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Até o corte do HOME (#316); depois, só para poder desligar
              // um filtro que ficou ligado.
              if (cutoff != null ||
                  _draft.homeCutoff != HomeCutoffFilter.all) ...[
                _Section(
                  title: cutoff == null
                      ? context.l10n.filterHomeCutoffPassed
                      : context.l10n.filterHomeCutoff(
                          MaterialLocalizations.of(context)
                              .formatCompactDate(cutoff.toLocal()),
                        ),
                  children: [
                    for (final option in HomeCutoffFilter.values)
                      ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 6,
                          children: [
                            Text(homeCutoffLabel(context.l10n, option)),
                            if (dexId != null)
                              HuntCount(
                                dexId: dexId,
                                query: _draft.copyWith(homeCutoff: option),
                              ),
                          ],
                        ),
                        selected: _draft.homeCutoff == option,
                        onSelected: (_) =>
                            _update(_draft.copyWith(homeCutoff: option)),
                      ),
                  ],
                ),
                if (switch (_draft.homeCutoff) {
                      HomeCutoffFilter.all => null,
                      HomeCutoffFilter.only => context.l10n.homeCutoffOnlyHint,
                      HomeCutoffFilter.also => context.l10n.homeCutoffAlsoHint,
                    }
                    case final hint?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              _Section(
                title: context.l10n.filterCategory,
                children: [
                  for (final category in SpeciesCategory.values)
                    FilterChip(
                      label: Text(context.l10n.speciesCategory(category)),
                      selected: _draft.categories.contains(category),
                      onSelected: (on) => _update(
                        _draft.copyWith(
                          categories: _toggle(_draft.categories, category, on),
                        ),
                      ),
                    ),
                ],
              ),
              _Section(
                title: context.l10n.filterGeneration,
                children: [
                  for (final generation in options.generation)
                    FilterChip(
                      label: Text(generationNumber(generation.value)),
                      tooltip: context.catalogText(
                        generation.label,
                        generation.labels,
                      ),
                      selected: _draft.generations.contains(generation.value),
                      onSelected: (on) => _update(
                        _draft.copyWith(
                          generations: _toggle(
                            _draft.generations,
                            generation.value,
                            on,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              _Section(
                title: context.l10n.filterTypeAny,
                children: [
                  for (final type in options.type)
                    FilterChip(
                      avatar: TypeIcon(type.value),
                      label: Text(context.catalogText(type.label, type.labels)),
                      selected: _draft.types.contains(type.value),
                      onSelected: (on) => _update(
                        _draft.copyWith(
                          types: _toggle(_draft.types, type.value, on),
                        ),
                      ),
                    ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(context.l10n.includeUnobtainable),
                subtitle: Text(context.l10n.includeUnobtainableHint),
                value: _draft.includeLocked,
                onChanged: (v) => _update(_draft.copyWith(includeLocked: v)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_draft),
            child: Text(context.l10n.showResults),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        Wrap(spacing: 8, runSpacing: 4, children: children),
      ],
    ),
  );
}

/// Chips do escopo ativo, numa linha rolável; o X limpa aquele filtro. Não
/// ocupa espaço quando não há filtro de escopo.
class ActiveHuntFilterChips extends ConsumerWidget {
  const ActiveHuntFilterChips({
    required this.query,
    required this.onChanged,
    super.key,
  });

  final HuntQuery query;
  final ValueChanged<HuntQuery> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.scopeCount == 0) return const SizedBox.shrink();
    final options =
        ref.watch(specimenOptionsProvider).value ?? const SpecimenOptions();
    final q = query;
    final chips = <(String, HuntQuery)>[
      if (q.categories.isNotEmpty)
        (
          summarize([
            for (final c in q.categories) context.l10n.speciesCategory(c),
          ])!,
          q.copyWith(categories: const []),
        ),
      if (q.generations.isNotEmpty)
        (
          context.l10n.generationNumber(
            q.generations.map(generationNumber).join(', '),
          ),
          q.copyWith(generations: const []),
        ),
      if (q.types.isNotEmpty)
        (
          joinAlternatives(
            context.l10n,
            labelsOf(context.l10n, q.types, options.type),
          ),
          q.copyWith(types: const []),
        ),
      if (q.includeLocked)
        (context.l10n.withUnobtainable, q.copyWith(includeLocked: false)),
      if (q.homeCutoff != HomeCutoffFilter.all)
        (
          homeCutoffLabel(context.l10n, q.homeCutoff),
          q.copyWith(homeCutoff: HomeCutoffFilter.all),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          for (final (label, cleared) in chips)
            InputChip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
              deleteButtonTooltipMessage: context.l10n.removeFilter,
              onDeleted: () => onChanged(cleared),
            ),
        ],
      ),
    );
  }
}

/// O nome da opção de "Fim do Pokémon Bank" (#316), no chip e no filtro aplicado.
String homeCutoffLabel(AppLocalizations l10n, HomeCutoffFilter filter) =>
    switch (filter) {
      HomeCutoffFilter.all => l10n.homeCutoffAll,
      HomeCutoffFilter.only => l10n.homeCutoffOnly,
      HomeCutoffFilter.also => l10n.homeCutoffAlso,
    };

/// Quantas caçadas a [query] dá (o total da 1ª página), em letra pequena: à
/// direita dos jogos no menu Jogo e nas opções de "Fim do Pokémon Bank".
class HuntCount extends ConsumerWidget {
  const HuntCount({required this.dexId, required this.query, super.key});

  final int dexId;
  final HuntQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref
        .watch(huntPageProvider((dexId: dexId, query: query, page: 1)))
        .value;
    return Text(
      page == null ? '' : '${page.count}',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
