import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/menu_chip.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/search_field.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/hunt_filters.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/start_hunt_sheet.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
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

/// As abas de Caçadas: o que falta, as caçadas em andamento e as pausadas
/// (#164).
enum HuntsTab { missing, active, paused }

class _HuntsPageState extends ConsumerState<HuntsPage> {
  HuntQuery _query = const HuntQuery();
  HuntsTab _tab = HuntsTab.missing;
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
  Widget build(BuildContext context) {
    final hunts = ref.watch(shinyHuntsProvider).value ?? const <ShinyHunt>[];
    final active = hunts.where((h) => !h.paused).length;
    final tabs = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SegmentedButton<HuntsTab>(
        key: const ValueKey('hunts-tabs'),
        showSelectedIcon: false,
        segments: [
          const ButtonSegment(value: HuntsTab.missing, label: Text('Faltam')),
          ButtonSegment(
            value: HuntsTab.active,
            label: Text('Em andamento ($active)'),
          ),
          ButtonSegment(
            value: HuntsTab.paused,
            label: Text('Pausadas (${hunts.length - active})'),
          ),
        ],
        selected: {_tab},
        onSelectionChanged: (v) => setState(() => _tab = v.single),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Caçadas')),
      floatingActionButton: _tab == HuntsTab.active
          ? const StartHuntButton()
          : null,
      body: Center(
        // No PC, uma lista de 1.400 px de largura só espalharia o texto; os
        // cartões das caçadas, em grade, usam mais.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _tab == HuntsTab.missing ? 720 : 1100,
          ),
          child: Column(
            children: [
              tabs,
              if (_tab == HuntsTab.missing)
                ..._missing(context)
              else
                Expanded(child: HuntCards(paused: _tab == HuntsTab.paused)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _missing(BuildContext context) => [
    _Filters(
      dexId: widget.dexId,
      query: _query,
      onSearchChanged: _onSearchChanged,
      onChanged: _setQuery,
    ),
    Expanded(
      child: HuntList(
        dexId: widget.dexId,
        query: _query,
        onShowActive: () => setState(() => _tab = HuntsTab.active),
        onTap: (hunt) => context.push(
          Routes.dex(
            widget.dexId,
            boxId: hunt.slot.box.id,
            slotId: hunt.slot.id,
          ),
        ),
      ),
    ),
  ];
}

/// Busca + botão Filtros numa linha; Motivos, Situação e Jogo em chips com
/// menu; e, só com escopo ativo, os chips removíveis dele. Mesmo desenho do
/// inventário.
class _Filters extends ConsumerWidget {
  const _Filters({
    required this.dexId,
    required this.query,
    required this.onSearchChanged,
    required this.onChanged,
  });

  final int dexId;
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
    // Jogo: só com o catálogo das pokédex e algum save; um item por versão.
    final saves = ref.watch(knowsGamesProvider)
        ? ref.watch(savesProvider).value ?? const <Save>[]
        : const <Save>[];
    final savesOf = <String, List<Save>>{};
    for (final save in saves) {
      if (save.trainer.version case final version?) {
        (savesOf[version] ??= []).add(save);
      }
    }
    final games = query.versions;
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
      if (savesOf.isNotEmpty)
        MenuChip(
          label: switch (games) {
            [] => 'Jogo',
            [final one] => versionLabel(one),
            [final first, ...] => '${versionLabel(first)} +${games.length - 1}',
          },
          avatar: games.isEmpty ? null : _StackedGameIcons(games),
          selected: games.isNotEmpty,
          menuChildren: [
            const MenuHeader('Caçável em algum destes saves'),
            CheckboxMenuButton(
              value: games.isEmpty,
              closeOnActivate: false,
              // Já sem filtro, não há o que desmarcar.
              onChanged: games.isEmpty
                  ? null
                  : (_) => onChanged(query.copyWith(versions: const [])),
              child: const MenuOptionText(
                'Todos os jogos',
                'Sem filtrar por save',
              ),
            ),
            for (final MapEntry(key: version, value: saves) in savesOf.entries)
              CheckboxMenuButton(
                value: games.contains(version),
                closeOnActivate: false,
                onChanged: (on) => onChanged(
                  query.copyWith(
                    versions: on!
                        ? [...games, version]
                        : [...games.where((v) => v != version)],
                  ),
                ),
                trailingIcon: _GameCount(
                  dexId: dexId,
                  query: query.copyWith(versions: [version]),
                ),
                child: MenuOptionText(
                  versionLabel(version),
                  saves.map((s) => s.owner).join(' · '),
                  leading: GameIcon(version, size: 24),
                ),
              ),
            // Com caixas de seleção o menu não fecha a cada toque. Sem
            // `onPressed` o botão ficaria desabilitado (e não fecharia);
            // fechar é o próprio `closeOnActivate`.
            Align(
              alignment: Alignment.centerRight,
              child: MenuItemButton(
                onPressed: () {},
                child: const Text('Pronto'),
              ),
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

/// Os ícones dos jogos marcados, um por cima do outro (até 3), no chip Jogo.
class _StackedGameIcons extends StatelessWidget {
  const _StackedGameIcons(this.versions);

  final List<String> versions;

  static const _size = 18.0;
  static const _step = 8.0;

  @override
  Widget build(BuildContext context) {
    final shown = versions.take(3).toList();
    return SizedBox(
      width: _size + _step * (shown.length - 1),
      height: _size,
      child: Stack(
        children: [
          for (final (i, version) in shown.indexed)
            Positioned(
              left: _step * i,
              child: GameIcon(version, size: _size),
            ),
        ],
      ),
    );
  }
}

/// Quantas caçadas há em um jogo (com os outros filtros), à direita do item
/// do menu Jogo.
class _GameCount extends ConsumerWidget {
  const _GameCount({required this.dexId, required this.query});

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

/// `"Scarlet"`, `"Scarlet ou Sword"`, `"Scarlet, Violet ou Sword"`.
String _gameNames(List<String> versions) {
  final names = [for (final v in versions) versionLabel(v)];
  return names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} ou ${names.last}';
}

/// Lista paginada: o total vem da 1ª página e cada item observa só a página
/// em que está, carregada quando aparece na tela.
class HuntList extends ConsumerWidget {
  const HuntList({
    required this.dexId,
    required this.query,
    required this.onTap,
    this.onShowActive,
    super.key,
  });

  final int dexId;
  final HuntQuery query;
  final ValueChanged<Hunt> onTap;

  /// O chip "Em andamento" de um item leva à aba das caçadas.
  final VoidCallback? onShowActive;

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
              query.versions.isEmpty
                  ? '${page.count} para caçar'
                  : '${page.count} para caçar em ${_gameNames(query.versions)}',
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
                  onShowActive: onShowActive,
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
    this.onShowActive,
  });

  final int dexId;
  final HuntQuery query;
  final int index;
  final ValueChanged<Hunt> onTap;
  final VoidCallback? onShowActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (dexId: dexId, query: query, page: index ~/ huntPageSize + 1);
    final offset = index % huntPageSize;
    return switch (ref.watch(huntPageProvider(key))) {
      AsyncData(value: final page) when offset < page.results.length =>
        HuntTile(
          hunt: page.results[offset],
          onTap: () => onTap(page.results[offset]),
          onShowActive: onShowActive,
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
  const HuntTile({
    required this.hunt,
    required this.onTap,
    this.onShowActive,
    super.key,
  });

  final Hunt hunt;
  final VoidCallback onTap;
  final VoidCallback? onShowActive;

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hunt.versions.isNotEmpty)
            HuntGames(
              versions: hunt.versions,
              owned: {
                for (final save
                    in ref.watch(savesProvider).value ?? const <Save>[])
                  ?save.trainer.version,
              },
            ),
          ?_huntAction(context, ref, form),
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

  /// Caçada em andamento desta forma: o chip que leva à aba; senão, o botão
  /// "Começar caçada" (desabilitado com um cronômetro rodando).
  Widget? _huntAction(BuildContext context, WidgetRef ref, FormRef? form) {
    if (form == null) return null;
    final hunts = ref.watch(shinyHuntsProvider).value ?? const <ShinyHunt>[];
    if (hunts.any((h) => !h.paused && h.form == form.id)) {
      return ActionChip(
        avatar: const Icon(Icons.track_changes, size: 16),
        label: const Text('Em andamento'),
        onPressed: onShowActive,
      );
    }
    return IconButton(
      tooltip: 'Começar caçada',
      onPressed: hunts.any((h) => h.running)
          ? null
          : () => unawaited(showHuntSheet(context, form: form)),
      icon: const Icon(Icons.track_changes),
    );
  }
}

/// Onde caçar, em até [max] ícones de jogo: os saves do usuário em que dá
/// (coloridos) e depois os jogos em que ele não tem save (cinza); o resto
/// vira "+N". Sem ícone: fora das pokédex dos jogos do HOME.
class HuntGames extends StatelessWidget {
  const HuntGames({
    required this.versions,
    required this.owned,
    this.max = 4,
    super.key,
  });

  final List<String> versions;

  /// As versões dos saves do usuário.
  final Set<String> owned;
  final int max;

  @override
  Widget build(BuildContext context) {
    final mine = [...versions.where(owned.contains)];
    final others = [...versions.where((v) => !owned.contains(v))];
    final room = (max - mine.length).clamp(0, others.length);
    final rest = others.length - room;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        for (final version in mine) GameIcon(version),
        for (final version in others.take(room)) GameIcon(version, muted: true),
        if (rest > 0)
          Text(
            '+$rest',
            semanticsLabel: 'mais $rest jogos sem save seu',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
      ],
    );
  }
}
