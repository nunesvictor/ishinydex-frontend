import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/theme/version_colors.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/chip_icons.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/menu_chip.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/search_field.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/hunt_share_sheet.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/game_picker.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// A aba Concluídas (#297): os espécimes com registro de caçada, dos
/// capturados mais recentes aos mais antigos (sem data, no fim).
const completedHuntsQuery = SpecimenQuery(
  huntsOnly: true,
  ordering: SpecimenOrdering.capturedDesc,
);

/// Todas as caçadas concluídas, sem filtro: o número da aba e as opções dos
/// filtros (os jogos do OT e os métodos que aparecem). Observa a 1ª página
/// da lista, então recarrega quando os espécimes mudam.
final FutureProvider<List<Specimen>> completedHuntsProvider =
    FutureProvider.autoDispose<List<Specimen>>((ref) async {
      final first = await ref.watch(
        specimenPageProvider((query: completedHuntsQuery, page: 1)).future,
      );
      if (first.next == null) return first.results;
      return (await ref
              .watch(specimenRepositoryProvider)
              .fetchSpecimens(
                completedHuntsQuery,
                page: 1,
                pageSize: first.count,
              ))
          .results;
    });

/// O conteúdo da aba: a busca, os chips Jogo e Método, a contagem e a
/// lista. Sem nenhuma caçada concluída, a explicação de como uma chega aqui.
class CompletedHunts extends ConsumerStatefulWidget {
  const CompletedHunts({super.key});

  @override
  ConsumerState<CompletedHunts> createState() => _CompletedHuntsState();
}

class _CompletedHuntsState extends ConsumerState<CompletedHunts> {
  SpecimenQuery _query = completedHuntsQuery;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setQuery(SpecimenQuery query) => setState(() => _query = query);

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _setQuery(_query.copyWith(search: text.trim())),
    );
  }

  void _submitSearch(String text) {
    _debounce?.cancel();
    _setQuery(_query.copyWith(search: text.trim()));
  }

  @override
  Widget build(BuildContext context) =>
      switch (ref.watch(completedHuntsProvider)) {
        AsyncData(value: final all) when all.isEmpty => EmptyView(
          message: context.l10n.huntsDoneEmptyTitle,
          detail: context.l10n.huntsDoneEmptyBody,
        ),
        AsyncData(value: final all) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchField(
                hintText: context.l10n.searchNameOrNumber,
                onChanged: _onSearchChanged,
                onSubmitted: _submitSearch,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GameChip(all: all, query: _query, onChanged: _setQuery),
                  _MethodChip(all: all, query: _query, onChanged: _setQuery),
                ],
              ),
            ),
            Expanded(child: _CompletedList(query: _query)),
          ],
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(specimenPageProvider),
        ),
        _ => const LoadingView(),
      };
}

/// O chip Jogo, com a mesma folha das Faltam: os jogos do OT das caçadas
/// concluídas, com quantas cada um tem; marcados, os ícones (com um só, na
/// cor do jogo).
class _GameChip extends ConsumerWidget {
  const _GameChip({
    required this.all,
    required this.query,
    required this.onChanged,
  });

  final List<Specimen> all;
  final SpecimenQuery query;
  final ValueChanged<SpecimenQuery> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainers = {
      for (final t in ref.watch(trainersProvider).value ?? const <Trainer>[])
        t.id: t.version,
    };
    final order = ref.watch(versionOrderProvider);
    final games = [
      ...{for (final s in all) ?trainers[s.ot]},
    ]..sort(order);
    if (games.isEmpty) return const SizedBox.shrink();
    final selected = query.otVersions;
    final names = joinLabels(context.l10n, [
      for (final g in selected) versionLabel(g),
    ]);
    int? countOf(SpecimenQuery q) =>
        ref.watch(specimenPageProvider((query: q, page: 1))).value?.count;
    return FilterChip(
      tooltip: selected.isEmpty ? null : context.l10n.filterGameValue(names),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected.isEmpty)
            Text(context.l10n.fieldGame)
          else
            ChipIcons([
              for (final g in selected) GameIcon(g, size: 18),
            ], semanticLabel: context.l10n.filterGameValue(names)),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
      selected: selected.isNotEmpty,
      // Um jogo só marcado: o chip na cor dele (#203).
      selectedColor: selected.length == 1
          ? versionTone(
              selected.first,
              Theme.of(context).brightness,
            )?.background
          : null,
      showCheckmark: false,
      onSelected: (_) async {
        final picked = await showGamePicker(
          context,
          subtitle: context.l10n.huntsDoneGameHint,
          sections: [
            GamePickerSection(
              title: context.l10n.fieldGame,
              versions: games,
              selected: selected,
              count: (v) => Text(
                '${countOf(completedHuntsQuery.copyWith(otVersions: [v])) ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          applyLabel: (ref, draft) {
            final n = ref
                .watch(
                  specimenPageProvider((
                    query: query.copyWith(otVersions: draft.single),
                    page: 1,
                  )),
                )
                .value
                ?.count;
            return n == null
                ? context.l10n.showResults
                : context.l10n.showCountResults(n);
          },
        );
        if (picked != null) {
          onChanged(query.copyWith(otVersions: picked.single));
        }
      },
    );
  }
}

/// O chip Método: vários de uma vez, num menu de marcar, com os métodos que
/// aparecem nas caçadas concluídas.
class _MethodChip extends ConsumerWidget {
  const _MethodChip({
    required this.all,
    required this.query,
    required this.onChanged,
  });

  final List<Specimen> all;
  final SpecimenQuery query;
  final ValueChanged<SpecimenQuery> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(shinyMethodsProvider)(null);
    final used = {for (final s in all) ?s.hunt?.method};
    final methods = [
      for (final m in catalog)
        if (used.contains(m.id)) m,
    ];
    if (methods.isEmpty) return const SizedBox.shrink();
    String label(ShinyMethod m) => context.catalogText(m.label, m.labels);
    final selected = query.huntMethods;
    final names = [
      for (final m in methods)
        if (selected.contains(m.id)) label(m),
    ];
    return MenuChip(
      label: switch (names) {
        [] => context.l10n.fieldMethod,
        [final one] => one,
        _ => context.l10n.labelCount(context.l10n.fieldMethod, names.length),
      },
      tooltip: names.isEmpty
          ? null
          : context.l10n.filterMethodValue(joinLabels(context.l10n, names)),
      selected: names.isNotEmpty,
      menuChildren: [
        for (final m in methods)
          CheckboxMenuButton(
            value: selected.contains(m.id),
            closeOnActivate: false,
            onChanged: (on) => onChanged(
              query.copyWith(
                huntMethods: [
                  for (final id in selected)
                    if (id != m.id) id,
                  if (on ?? false) m.id,
                ],
              ),
            ),
            child: Text(label(m)),
          ),
      ],
    );
  }
}

/// A lista paginada, como a do inventário: o total vem da 1ª página e cada
/// item observa só a página em que está.
class _CompletedList extends ConsumerWidget {
  const _CompletedList({required this.query});

  final SpecimenQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstPage = specimenPageProvider((query: query, page: 1));
    return switch (ref.watch(firstPage)) {
      AsyncData(value: final page) when page.count == 0 => EmptyView(
        message: context.l10n.huntsDoneNothing,
      ),
      AsyncData(value: final page) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              query.otVersions.isEmpty
                  ? context.l10n.huntsDoneCount(page.count)
                  : context.l10n.huntsDoneCountIn(
                      page.count,
                      joinAlternatives(context.l10n, [
                        for (final v in query.otVersions) versionLabel(v),
                      ]),
                    ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: () {
                ref.invalidate(specimenPageProvider);
                return ref.read(firstPage.future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: page.count,
                itemBuilder: (context, i) =>
                    _CompletedItem(query: query, index: i),
              ),
            ),
          ),
        ],
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(firstPage),
      ),
      _ => const LoadingView(),
    };
  }
}

class _CompletedItem extends ConsumerWidget {
  const _CompletedItem({required this.query, required this.index});

  final SpecimenQuery query;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (query: query, page: index ~/ specimenPageSize + 1);
    final offset = index % specimenPageSize;
    return switch (ref.watch(specimenPageProvider(key))) {
      AsyncData(value: final page) when offset < page.results.length =>
        CompletedHuntTile(specimen: page.results[offset]),
      // A lista encolheu entre páginas: nada a mostrar.
      AsyncData() => const SizedBox.shrink(),
      // O erro aparece uma vez, no primeiro item da página.
      AsyncError() when offset == 0 => ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(context.l10n.loadMoreSpecimensError),
        trailing: TextButton(
          onPressed: () => ref.invalidate(specimenPageProvider(key)),
          child: Text(context.l10n.tryAgain),
        ),
      ),
      AsyncError() => const SizedBox.shrink(),
      _ => const ListTile(
        leading: SizedBox.square(dimension: 48),
        title: LinearProgressIndicator(),
      ),
    };
  }
}

/// Uma caçada concluída (#297): o sprite e o nome (com o alfa); o método e a
/// contagem (sem contagem, só o método); o jogo do OT, a duração (com
/// início) e a data da captura. Tocar abre o espécime; à direita, o card
/// para compartilhar. No PC, tudo numa linha.
class CompletedHuntTile extends ConsumerWidget {
  const CompletedHuntTile({required this.specimen, super.key});

  final Specimen specimen;

  /// A partir desta largura, o item fica numa linha só.
  static const wideFrom = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hunt = specimen.hunt!;
    final method = ref
        .watch(shinyMethodsProvider)(null)
        .where((m) => m.id == hunt.method)
        .firstOrNull;
    final version = (ref.watch(trainersProvider).value ?? const <Trainer>[])
        .where((t) => t.id == specimen.ot)
        .firstOrNull
        ?.version;
    final (start, captured) = (hunt.startedAt, specimen.capturedAt);
    // Caçado como a pré-evolução (#315).
    final hunted = switch (hunt.huntedForm) {
      final id? => ref.watch(formRefOfProvider)(id),
      null => null,
    };
    final name = Row(
      spacing: 6,
      children: [
        Flexible(
          child: Text(
            specimen.displayName,
            style: theme.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const ShinyIcon(size: 14),
        if (specimen.isAlpha) const AlphaIcon(size: 16),
      ],
    );
    final count = hunt.count;
    final what = Text.rich(
      TextSpan(
        children: [
          if (method != null)
            TextSpan(text: context.catalogText(method.label, method.labels)),
          if (method != null && count != null) const TextSpan(text: ' · '),
          if (count != null)
            TextSpan(
              text: context.l10n.huntCount(count, hunt.unit),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
      style: theme.textTheme.bodyMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final when = Text(
      [
        if (hunted != null) context.l10n.huntedAs(hunted.displayName),
        if (captured == null)
          context.l10n.noCaptureDate
        else ...[
          if (start != null) context.l10n.huntDuration(start, captured),
          MaterialLocalizations.of(context).formatCompactDate(captured),
        ],
      ].join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final game = version == null ? null : GameIcon(version, size: 18);
    final share = huntShareDataOf(context, ref, specimen) == null
        ? null
        : IconButton(
            tooltip: context.l10n.shareHunt,
            onPressed: () => unawaited(showHuntShareSheet(context, specimen)),
            icon: const Icon(Icons.ios_share),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideFrom;
        return InkWell(
          key: ValueKey('done-${specimen.id}'),
          onTap: () => context.push(Routes.specimen(specimen.id)),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: wide ? 56 : 76),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                spacing: wide ? 16 : 12,
                children: [
                  PokemonSprite(url: specimen.spriteUrl, size: wide ? 40 : 48),
                  if (wide) ...[
                    SizedBox(width: 200, child: name),
                    Expanded(child: what),
                    ?game,
                    SizedBox(
                      width: 170,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: when,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          name,
                          what,
                          Row(
                            spacing: 6,
                            children: [
                              ?game,
                              Flexible(child: when),
                            ],
                          ),
                        ],
                      ),
                    ),
                  share ?? const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
