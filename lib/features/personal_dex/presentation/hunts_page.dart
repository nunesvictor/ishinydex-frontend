import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/hunt_filters.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Caçadas de um shiny dex: o que ainda falta, ou não serve, em shiny.
///
/// Os motivos (sem shiny, shiny do GO, pokébola fora da lista) ficam sempre
/// à vista, em chips; o escopo (categoria, geração, tipo) fica na folha de
/// filtros. Tocar num item empilha o dex naquela box, com o slot aberto: o
/// voltar retorna para cá, com os filtros intactos.
class HuntsPage extends ConsumerStatefulWidget {
  const HuntsPage({required this.dexId, super.key});

  final int dexId;

  @override
  ConsumerState<HuntsPage> createState() => _HuntsPageState();
}

class _HuntsPageState extends ConsumerState<HuntsPage> {
  HuntQuery _query = const HuntQuery();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setQuery(HuntQuery query) => setState(() => _query = query);

  /// Espera o usuário parar de digitar antes de consultar a API.
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _setQuery(_query.copyWith(search: text.trim())),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Caçadas')),
    body: Center(
      // No PC, uma lista de 1.400 px de largura só espalharia o texto.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            _Filters(
              query: _query,
              onSearchChanged: _onSearchChanged,
              onChanged: _setQuery,
            ),
            Expanded(
              child: HuntList(
                dexId: widget.dexId,
                query: _query,
                onTap: (hunt) => context.push(
                  Routes.dex(
                    widget.dexId,
                    boxId: hunt.slot.box.id,
                    slotId: hunt.slot.id,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Busca + botão Filtros numa linha; motivos numa linha de chips; e, só com
/// escopo ativo, os chips removíveis dele. Mesmo desenho do inventário.
class _Filters extends ConsumerWidget {
  const _Filters({
    required this.query,
    required this.onSearchChanged,
    required this.onChanged,
  });

  final HuntQuery query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<HuntQuery> onChanged;

  bool _isOn(HuntReason reason) => query.reasons.contains(reason);

  /// O último motivo marcado não pode sair: sem motivo, a lista é vazia.
  ValueChanged<bool>? _toggler(HuntReason reason) {
    if (_isOn(reason) && query.reasons.length == 1) return null;
    return (on) => onChanged(
      query.copyWith(
        reasons: on
            ? [...query.reasons, reason]
            : [...query.reasons.where((r) => r != reason)],
      ),
    );
  }

  /// Ligar o motivo "pokébola" pede as bolas aceitas; sem nenhuma, não liga.
  Future<void> _togglePokeball(
    BuildContext context,
    SpecimenOptions options,
    bool on,
  ) async {
    if (!on) return _toggler(HuntReason.pokeball)!(false);
    final picked = await showChoicePicker(
      context,
      title: 'Pokébolas aceitas',
      choices: options.pokeball,
      selected: query.acceptedBalls.toSet(),
    );
    if (picked == null || picked.isEmpty) return;
    onChanged(
      query.copyWith(
        reasons: [...query.reasons, HuntReason.pokeball],
        acceptedBalls: [...picked],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options =
        ref.watch(specimenOptionsProvider).value ?? const SpecimenOptions();
    final count = query.scopeCount;
    final balls = summarize(labelsOf(query.acceptedBalls, options.pokeball));
    final pokeballOn = _isOn(HuntReason.pokeball);
    final reasons = <Widget>[
      FilterChip(
        avatar: const Text(shinyEmoji),
        label: Text(HuntReason.noShiny.label),
        tooltip: 'Slot vazio ou com espécime não shiny',
        selected: _isOn(HuntReason.noShiny),
        onSelected: _toggler(HuntReason.noShiny),
      ),
      FilterChip(
        avatar: const Text(goEmoji),
        label: Text(HuntReason.fromGo.label),
        tooltip: 'Shiny que veio do Pokémon GO',
        selected: _isOn(HuntReason.fromGo),
        onSelected: _toggler(HuntReason.fromGo),
      ),
      FilterChip(
        avatar: const Icon(Icons.catching_pokemon),
        label: Text(
          pokeballOn && balls != null ? 'Fora de: $balls' : 'Pokébola…',
        ),
        tooltip: 'Shiny numa pokébola fora das escolhidas',
        selected: pokeballOn,
        onSelected: pokeballOn && query.reasons.length == 1
            ? null
            : (on) => _togglePokeball(context, options, on),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            spacing: 4,
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nome ou número',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              IconButton(
                tooltip: 'Filtros',
                onPressed: () async {
                  final applied = await showHuntFilters(context, query);
                  if (applied != null) onChanged(applied);
                },
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          // No celular, uma linha rolável (altura fixa); nos demais
          // tamanhos, os chips quebram linha.
          child: WindowSize.of(context).isCompact
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(spacing: 8, children: reasons),
                )
              : Wrap(spacing: 8, runSpacing: 8, children: reasons),
        ),
        ActiveHuntFilterChips(query: query, onChanged: onChanged),
      ],
    );
  }
}

/// Lista paginada: o total vem da 1ª página e cada item observa só a página
/// em que está, carregada quando aparece na tela.
class HuntList extends ConsumerWidget {
  const HuntList({
    required this.dexId,
    required this.query,
    required this.onTap,
    super.key,
  });

  final int dexId;
  final HuntQuery query;
  final ValueChanged<Hunt> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstPage = huntPageProvider((dexId: dexId, query: query, page: 1));
    return switch (ref.watch(firstPage)) {
      AsyncData(value: final page) when page.count == 0 => const EmptyView(
        message: 'Nada para caçar com estes filtros.',
      ),
      AsyncData(value: final page) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '${page.count} para caçar',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: () {
                ref.invalidate(huntPageProvider);
                return ref.read(firstPage.future);
              },
              child: ListView.builder(
                itemCount: page.count,
                itemBuilder: (context, i) => _HuntItem(
                  dexId: dexId,
                  query: query,
                  index: i,
                  onTap: onTap,
                ),
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

class _HuntItem extends ConsumerWidget {
  const _HuntItem({
    required this.dexId,
    required this.query,
    required this.index,
    required this.onTap,
  });

  final int dexId;
  final HuntQuery query;
  final int index;
  final ValueChanged<Hunt> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (dexId: dexId, query: query, page: index ~/ huntPageSize + 1);
    final offset = index % huntPageSize;
    return switch (ref.watch(huntPageProvider(key))) {
      AsyncData(value: final page) when offset < page.results.length =>
        HuntTile(
          hunt: page.results[offset],
          onTap: () => onTap(page.results[offset]),
        ),
      // A lista encolheu entre páginas (ex.: depositou um shiny).
      AsyncData() => const SizedBox.shrink(),
      // O erro aparece uma vez, no primeiro item da página.
      AsyncError() when offset == 0 => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Não foi possível carregar mais caçadas.'),
        trailing: TextButton(
          onPressed: () => ref.invalidate(huntPageProvider(key)),
          child: const Text('Tentar novamente'),
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

/// Uma caçada: sprite shiny (o que se procura), nome, posição na box e os
/// motivos. Um cadeado indica shiny lock.
class HuntTile extends ConsumerWidget {
  const HuntTile({required this.hunt, required this.onTap, super.key});

  final Hunt hunt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options =
        ref.watch(specimenOptionsProvider).value ?? const SpecimenOptions();
    final slot = hunt.slot;
    final specimen = slot.specimen;
    final lock = hunt.shinyLock;
    final reasons = [
      for (final reason in hunt.reasons)
        switch (reason) {
          HuntReason.noShiny => specimen == null ? 'Faltando' : 'Não shiny',
          HuntReason.fromGo => '$goEmoji Do GO',
          HuntReason.pokeball =>
            choiceLabel(options.pokeball, specimen?.pokeball) ?? 'Pokébola',
        },
    ];
    return ListTile(
      key: ValueKey('hunt-${slot.id}'),
      leading: PokemonSprite(url: slot.form?.spriteFor(shiny: true), size: 48),
      title: Row(
        spacing: 4,
        children: [
          Flexible(
            child: Text(
              slot.form?.displayName ?? '',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lock != null)
            Tooltip(
              message: lock.label,
              child: const Icon(Icons.lock_outline, size: 16),
            ),
        ],
      ),
      // Uma linha só (espaço no celular): box, linha/coluna e motivos.
      subtitle: Text(
        [
          '${slot.box.name} · L${slot.row + 1} C${slot.col + 1}',
          ...reasons,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
