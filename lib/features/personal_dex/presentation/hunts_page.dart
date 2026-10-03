import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/menu_chip.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/search_field.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/hunt_filters.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_headline.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Caçadas de um shiny dex: o que ainda falta, ou não serve, em shiny.
///
/// Os motivos (sem shiny, shiny do GO, pokébola fora da lista) e a situação
/// do slot (faltando ou registrado) ficam à vista, em chips com menu; o
/// escopo (categoria, geração, tipo) fica na folha de filtros. Tocar num item empilha o dex naquela box, com o slot aberto: o
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

/// Busca + botão Filtros numa linha; Motivos e Situação em chips com menu;
/// e, só com escopo ativo, os chips removíveis dele. Mesmo desenho do
/// inventário.
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

  /// O `onChanged` do checkbox de menu recebe `bool?`.
  ValueChanged<bool?>? _check(ValueChanged<bool>? toggle) =>
      toggle == null ? null : (on) => toggle(on!);

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
    final first = query.reasons.first;
    final more = query.reasons.length - 1;
    final chips = <Widget>[
      MenuChip(
        label: more > 0 ? '${first.label} +$more' : first.label,
        tooltip: 'Motivos',
        // Sempre há pelo menos um motivo: o chip está sempre "ativo".
        selected: true,
        menuChildren: [
          const MenuHeader('Motivos (qualquer um; pelo menos um)'),
          CheckboxMenuButton(
            value: _isOn(HuntReason.noShiny),
            closeOnActivate: false,
            onChanged: _check(_toggler(HuntReason.noShiny)),
            child: MenuOptionText(
              HuntReason.noShiny.label,
              'Slot vazio ou com espécime não shiny',
              leading: const ShinyIcon(size: 18, semanticLabel: null),
            ),
          ),
          CheckboxMenuButton(
            value: _isOn(HuntReason.fromGo),
            closeOnActivate: false,
            onChanged: _check(_toggler(HuntReason.fromGo)),
            child: MenuOptionText(
              HuntReason.fromGo.label,
              'Shiny que veio do Pokémon GO',
              leading: const GoIcon(size: 18, semanticLabel: null),
            ),
          ),
          // Ligar pede as bolas aceitas, num diálogo: o menu fecha.
          CheckboxMenuButton(
            value: pokeballOn,
            onChanged: pokeballOn && query.reasons.length == 1
                ? null
                : (on) => _togglePokeball(context, options, on!),
            child: MenuOptionText(
              pokeballOn && balls != null
                  ? 'Pokébola fora de: $balls'
                  : 'Pokébola fora das escolhidas',
              'Shiny numa pokébola que não é a da caçada',
              leading: const Icon(Icons.catching_pokemon, size: 18),
            ),
          ),
        ],
      ),
      MenuChip(
        label: query.situation == HuntSituation.all
            ? 'Situação'
            : query.situation.label,
        selected: query.situation != HuntSituation.all,
        menuChildren: [
          const MenuHeader('Situação do slot'),
          for (final situation in HuntSituation.values)
            RadioMenuButton<HuntSituation>(
              value: situation,
              groupValue: query.situation,
              onChanged: (s) => onChanged(query.copyWith(situation: s!)),
              child: MenuOptionText(situation.label, situation.hint),
            ),
        ],
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
                child: SearchField(
                  hintText: 'Nome ou número',
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
          // Os grupos ficam em chips com menu: cabe numa linha, sem rolar.
          child: Wrap(spacing: 8, runSpacing: 8, children: chips),
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

/// Uma caçada, no estilo do item do inventário: sprite shiny da forma (o que
/// se procura) e, no título, o espécime que está no slot como o inventário o
/// mostra (pokébola, nome, gênero, ✨, alfa, GO). Slot vazio: só o nome da
/// forma. Um cadeado indica shiny lock.
class HuntTile extends ConsumerWidget {
  const HuntTile({required this.hunt, required this.onTap, super.key});

  final Hunt hunt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options =
        ref.watch(specimenOptionsProvider).value ?? const SpecimenOptions();
    final slot = hunt.slot;
    final form = slot.form;
    final specimen = slot.specimen;
    final lock = hunt.shinyLock;
    final hasNickname = specimen?.nickname?.isNotEmpty ?? false;
    // "Do GO" não entra: o emoji do GO já está no título.
    final reasons = [
      for (final reason in hunt.reasons)
        ?switch (reason) {
          HuntReason.noShiny => specimen == null ? 'Faltando' : 'Não shiny',
          HuntReason.fromGo => null,
          HuntReason.pokeball => 'Outra pokébola',
        },
    ];
    return ListTile(
      key: ValueKey('hunt-${slot.id}'),
      leading: PokemonSprite(url: form?.spriteFor(shiny: true), size: 48),
      title: Row(
        spacing: 4,
        children: [
          Flexible(
            child: SpecimenHeadline(
              name: specimen?.displayName ?? form?.displayName ?? '',
              pokeballSpriteUrl: specimen?.pokeballSpriteUrl,
              pokeballLabel: choiceLabel(options.pokeball, specimen?.pokeball),
              gender: specimen?.gender,
              isShiny: specimen?.isShiny ?? false,
              isAlpha: specimen?.isAlpha ?? false,
              isFromGo: specimen?.isFromGo ?? false,
            ),
          ),
          if (lock != null)
            Tooltip(
              message: lock.label,
              child: const Icon(Icons.lock_outline, size: 16),
            ),
        ],
      ),
      // Uma linha só (espaço no celular): a espécie (só se o título mostra
      // um apelido), nº da dex, posição na box e motivos.
      subtitle: Text(
        [
          if (hasNickname) ?form?.displayName,
          ?form?.dexNumber,
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
