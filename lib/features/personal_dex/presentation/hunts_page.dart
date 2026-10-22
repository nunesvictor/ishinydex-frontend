import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import 'package:ishinydex/core/widgets/success_icon.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_labels.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_list_page.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/hunt_filters.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_tile.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/completed_hunts.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/start_hunt_sheet.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/home_cutoff.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/game_picker.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/home_tag.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Aba Caçadas (#246): o que ainda falta em shiny num shiny dex, e as
/// caçadas em andamento e pausadas, que não dependem de dex.
///
/// No Faltam, os motivos (sem shiny, shiny do GO, pokébola fora da lista) e
/// a situação do slot (faltando ou registrado) ficam à vista, em chips com
/// menu; o escopo (categoria, geração, tipo) fica na folha de filtros.
/// Tocar num item empilha o dex naquela box, com o slot aberto: o voltar
/// retorna para cá, com os filtros intactos.
class HuntsPage extends ConsumerStatefulWidget {
  const HuntsPage({this.dexId, this.initialTab, super.key});

  /// O shiny dex do Faltam, pedido por um atalho; sem ele, o último
  /// escolhido aqui (ou o primeiro shiny dex).
  final int? dexId;

  /// A aba pedida por um atalho (`&tab=active`). Sem ela, Ativas quando há
  /// caçada em andamento; senão, Faltam (#279).
  final HuntsTab? initialTab;

  @override
  ConsumerState<HuntsPage> createState() => _HuntsPageState();
}

/// As abas de Caçadas, na ordem do seletor (#279): as caçadas em andamento,
/// o que falta, as pausadas e as concluídas (#297).
enum HuntsTab { active, missing, paused, done }

class _HuntsPageState extends ConsumerState<HuntsPage>
    with SingleTickerProviderStateMixin {
  HuntQuery _query = const HuntQuery();
  TabController? _controller;
  Timer? _debounce;

  /// A aba inicial já foi decidida (pelo atalho, pelas caçadas carregadas
  /// ou por um toque do usuário).
  bool _tabDecided = false;

  /// O shiny dex escolhido da última vez (`null` sem nenhum), e se já foi
  /// lido do aparelho.
  int? _stored;
  bool _storedRead = false;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(lastDexStorageProvider);
    // Um atalho também conta como escolha: a aba volta nele depois.
    final asked = widget.dexId;
    unawaited(
      (asked == null
              ? storage.readHunts()
              : storage.writeHunts(asked).then((_) => asked))
          .then((id) {
            if (mounted) {
              setState(() {
                _stored = id;
                _storedRead = true;
              });
            }
          }),
    );
    // Retomar uma pausada leva a Ativas (#279).
    ref.listenManual(resumedHuntProvider, (_, resumed) {
      if (resumed != null) _controller?.animateTo(HuntsTab.active.index);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Criado aqui, e não no initState, para ler o "reduzir movimento": com
    // ele, tocar numa aba troca sem animação.
    if (_controller != null) return;
    final asked = widget.initialTab;
    final hunts = ref.read(shinyHuntsProvider).value;
    final tab = asked ?? (hunts == null ? null : _startTab(hunts));
    _tabDecided = tab != null;
    _controller = TabController(
      length: HuntsTab.values.length,
      initialIndex: (tab ?? HuntsTab.missing).index,
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : null,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  /// Sem atalho: Ativas quando há caçada em andamento; senão, Faltam.
  static HuntsTab _startTab(List<ShinyHunt> hunts) =>
      hunts.any((h) => !h.paused) ? HuntsTab.active : HuntsTab.missing;

  void _onTabChanged() {
    _tabDecided = true;
    // O botão "Começar caçada" segue a aba.
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller?.dispose();
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

  /// Enter: busca na hora, sem esperar o debounce.
  void _submitSearch(String text) {
    _debounce?.cancel();
    _setQuery(_query.copyWith(search: text.trim()));
  }

  /// Os shiny dexes do usuário (o Faltam só faz sentido neles).
  List<PersonalDex>? get _shinyDexes =>
      ref.watch(dexListProvider).value?.where((d) => d.isShinyDex).toList();

  /// O shiny dex do Faltam: o pedido (ou o último escolhido), se ainda for
  /// um shiny dex; senão o primeiro. `null` sem nenhum ou até ler a escolha.
  PersonalDex? get _missingDex {
    final shiny = _shinyDexes;
    if (!_storedRead || shiny == null || shiny.isEmpty) return null;
    return shiny.where((d) => d.id == _stored).firstOrNull ?? shiny.first;
  }

  /// O total do Faltam (o mesmo do "n para caçar"); `null` enquanto carrega
  /// ou sem shiny dex (#277).
  int? _missingCount() {
    final dex = _missingDex;
    return dex == null
        ? null
        : ref
              .watch(huntPageProvider((dexId: dex.id, query: _query, page: 1)))
              .value
              ?.count;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final loaded = ref.watch(shinyHuntsProvider).value;
    // Sem atalho, a aba inicial espera as caçadas (no aparelho, chegam
    // quase na hora) e só muda se o usuário ainda não trocou de aba.
    if (!_tabDecided && loaded != null) {
      _tabDecided = true;
      controller.index = _startTab(loaded).index;
    }
    final hunts = loaded ?? const <ShinyHunt>[];
    final active = hunts.where((h) => !h.paused).length;
    final tab = HuntsTab.values[controller.index];
    // Sem shiny dex, não há Faltam de onde começar.
    final hasDex = _shinyDexes?.isNotEmpty ?? true;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.huntsTitle)),
      floatingActionButton: tab == HuntsTab.active
          ? const StartHuntButton()
          : null,
      body: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: HuntsTabBar(
                controller: controller,
                tabs: [
                  (label: context.l10n.huntsTabActive, count: active),
                  (label: context.l10n.huntsTabMissing, count: _missingCount()),
                  (
                    label: context.l10n.huntsTabPaused,
                    count: hunts.length - active,
                  ),
                  (
                    label: context.l10n.huntsTabDone,
                    count: ref.watch(completedHuntsProvider).value?.length,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: controller,
              children: [
                // No PC, uma lista de 1.400 px de largura só espalharia o
                // texto; os cartões das caçadas, em grade, usam mais.
                _TabPage(
                  maxWidth: 1100,
                  child: HuntCards(paused: false, hasDex: hasDex),
                ),
                _TabPage(
                  maxWidth: 720,
                  child: Column(children: _missing(context)),
                ),
                _TabPage(
                  maxWidth: 1100,
                  child: HuntCards(paused: true, hasDex: hasDex),
                ),
                const _TabPage(maxWidth: 720, child: CompletedHunts()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _missing(BuildContext context) {
    final dexes = ref.watch(dexListProvider);
    if (dexes case AsyncError(:final error)) {
      return [
        Expanded(
          child: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(dexListProvider),
          ),
        ),
      ];
    }
    final shiny = _shinyDexes;
    if (shiny == null) return [const Expanded(child: LoadingView())];
    if (shiny.isEmpty) return [const Expanded(child: _NoShinyDex())];
    final dex = _missingDex;
    if (dex == null) return [const Expanded(child: LoadingView())];
    return [
      if (shiny.length > 1) _DexPicker(dexes: shiny, selected: dex),
      _Filters(
        dexId: dex.id,
        query: _query,
        onSearchChanged: _onSearchChanged,
        onSearchSubmitted: _submitSearch,
        onChanged: _setQuery,
      ),
      Expanded(
        child: HuntList(
          dexId: dex.id,
          query: _query,
          onShowActive: () => _controller!.animateTo(HuntsTab.active.index),
          onOpenBox: (box) =>
              context.push(Routes.huntsDex(dex.id, boxId: box.id)),
          onTap: (hunt) => context.push(
            Routes.huntsDex(
              dex.id,
              boxId: hunt.slot.box.id,
              slotId: hunt.slot.id,
            ),
          ),
          onTapGames: (hunt) => context.push(
            Routes.huntsDex(
              dex.id,
              boxId: hunt.slot.box.id,
              slotId: hunt.slot.id,
              species: true,
            ),
          ),
        ),
      ),
    ];
  }
}

/// Uma aba das Caçadas: centrada, com a largura máxima dela, e mantida viva
/// ao deslizar para as outras (filtros, busca e rolagem continuam).
class _TabPage extends StatefulWidget {
  const _TabPage({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: widget.child,
      ),
    );
  }
}

/// Uma aba do seletor: o nome e o número do selo (`null`, sem selo).
typedef HuntsTabLabel = ({String label, int? count});

/// O seletor das abas das Caçadas (#272): um traço embaixo da aba marcada,
/// cada aba na largura do próprio texto, com o número num selo. A sobra se
/// divide entre as abas; quando nem assim cabe (texto aumentado), a fileira
/// rola para o lado em vez de cortar.
class HuntsTabBar extends StatelessWidget {
  const HuntsTabBar({required this.controller, required this.tabs, super.key});

  final TabController controller;
  final List<HuntsTabLabel> tabs;

  /// O espaço de cada lado do conteúdo da aba e entre o nome e o selo.
  static const _padding = 16.0;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final number = NumberFormat.decimalPattern(context.l10n.localeName);
    final labelStyle = theme.textTheme.titleSmall!;
    final badgeStyle = theme.textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final badgeHeight = scaler.scale(18);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final counts = [
      for (final t in tabs)
        if (t.count case final count?) number.format(count) else null,
    ];
    final natural = [
      for (final (i, t) in tabs.indexed)
        _padding * 2 +
            measure(t.label, labelStyle) +
            switch (counts[i]) {
              final count? =>
                _gap + math.max(badgeHeight, measure(count, badgeStyle) + 12),
              null => 0,
            },
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = natural.fold<double>(0, (a, b) => a + b);
        final extra = math.max(
          0,
          ((constraints.maxWidth - total) / tabs.length).floorToDouble(),
        );
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) => TabBar(
            key: const ValueKey('hunts-tabs'),
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.zero,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: labelStyle,
            unselectedLabelStyle: labelStyle,
            tabs: [
              for (final (i, t) in tabs.indexed)
                Tab(
                  child: SizedBox(
                    width: natural[i] + extra,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: _gap,
                      children: [
                        Text(t.label, maxLines: 1, softWrap: false),
                        if (counts[i] case final count?)
                          _CountBadge(
                            count: count,
                            selected: controller.index == i,
                            height: badgeHeight,
                            style: badgeStyle,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// O número da aba (#272): na cor principal na aba marcada; nas outras,
/// discreto.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.selected,
    required this.height,
    required this.style,
  });

  final String count;
  final bool selected;
  final double height;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      constraints: BoxConstraints(minWidth: height),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Text(
        count,
        style: style.copyWith(
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// O seletor do shiny dex do Faltam, com mais de um (#246). Trocar recria a
/// página no dex novo, que fica lembrado para a próxima vez.
class _DexPicker extends StatelessWidget {
  const _DexPicker({required this.dexes, required this.selected});

  final List<PersonalDex> dexes;
  final PersonalDex selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: MenuAnchor(
        menuChildren: [
          for (final dex in dexes)
            RadioMenuButton<int>(
              value: dex.id,
              groupValue: selected.id,
              onChanged: (id) => context.go(Routes.hunts(dexId: id)),
              child: Text(dex.name),
            ),
        ],
        builder: (context, controller, _) => Tooltip(
          message: context.l10n.huntsChooseDex,
          child: FilledButton.tonalIcon(
            key: const ValueKey('hunts-dex-picker'),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.grid_view, size: 18),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(selected.name, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// O Faltam sem nenhum shiny dex (#246): o que ele mostraria, e o atalho
/// para criar um. As caçadas seguem nas outras abas.
class _NoShinyDex extends ConsumerWidget {
  const _NoShinyDex();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Icon(
                Icons.grid_view,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Text(
                context.l10n.huntsNoDexTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              Text(context.l10n.huntsNoDexBody, textAlign: TextAlign.center),
              FilledButton(
                onPressed: () => _create(context),
                child: Text(context.l10n.huntsNoDexAction),
              ),
              Text(
                context.l10n.huntsNoDexNote,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final dex = await openNewDex(context);
    if (dex != null && dex.isShinyDex && context.mounted) {
      context.go(Routes.hunts(dexId: dex.id));
    }
  }
}

/// Busca + botão Filtros numa linha; Motivos, Situação e Jogo em chips com
/// menu; e, só com escopo ativo, os chips removíveis dele. Mesmo desenho do
/// inventário.
class _Filters extends ConsumerWidget {
  const _Filters({
    required this.dexId,
    required this.query,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onChanged,
  });

  final int dexId;
  final HuntQuery query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
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
      title: context.l10n.acceptedBalls,
      choices: context.l10n.choicesIn(options.pokeball),
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
    final balls = summarize(
      labelsOf(context.l10n, query.acceptedBalls, options.pokeball),
    );
    final pokeballOn = _isOn(HuntReason.pokeball);
    // Jogo: só com o catálogo das pokédex e algum save; um item por versão.
    final saves = ref.watch(knowsGamesProvider)
        ? ref.watch(savesProvider).value ?? const <Save>[]
        : const <Save>[];
    // Na ordem da série (geração, lançamento, par), não na de cadastro.
    final order = ref.watch(versionOrderProvider);
    final versions = {for (final save in saves) ?save.trainer.version}.toList()
      ..sort(order);
    final savesOf = {
      for (final version in versions)
        version: [
          for (final save in saves)
            if (save.trainer.version == version) save,
        ],
    };
    final chips = <Widget>[
      // Situação · Jogo · Motivos (#251): o que falta e onde ficam juntos;
      // o refinamento vem depois, como a Raridade no inventário.
      MenuChip(
        label: context.l10n.filterSituation,
        icons: [?_situationIcon(query.situation)],
        tooltip: query.situation == HuntSituation.all
            ? null
            : context.l10n.filterSituationValue(
                context.l10n.huntSituation(query.situation),
              ),
        selected: query.situation != HuntSituation.all,
        menuChildren: [
          MenuHeader(context.l10n.slotSituation),
          for (final situation in HuntSituation.values)
            RadioMenuButton<HuntSituation>(
              value: situation,
              groupValue: query.situation,
              onChanged: (s) => onChanged(query.copyWith(situation: s!)),
              child: MenuOptionText(
                context.l10n.huntSituation(situation),
                context.l10n.huntSituationHint(situation),
                leading: switch (_situationIcon(situation)) {
                  final Icon icon => Icon(
                    icon.icon,
                    color: icon.color,
                    size: 18,
                  ),
                  _ => null,
                },
              ),
            ),
        ],
      ),
      if (savesOf.isNotEmpty)
        _GameChip(
          dexId: dexId,
          query: query,
          savesOf: savesOf,
          onChanged: onChanged,
        ),
      MenuChip(
        label: context.l10n.filterReasons,
        icons: [for (final r in query.reasons) _reasonIcon(r)],
        tooltip: context.l10n.filterReasonsValue(
          joinLabels(context.l10n, [
            for (final r in query.reasons) _lower(context.l10n.huntReason(r)),
          ]),
        ),
        // Sempre há pelo menos um motivo: o chip está sempre "ativo".
        selected: true,
        menuChildren: [
          MenuHeader(context.l10n.reasonsHeader),
          CheckboxMenuButton(
            value: _isOn(HuntReason.noShiny),
            closeOnActivate: false,
            onChanged: _check(_toggler(HuntReason.noShiny)),
            child: MenuOptionText(
              context.l10n.huntReason(HuntReason.noShiny),
              context.l10n.reasonNoShinyHint,
              leading: const NoShinyIcon(size: 18),
            ),
          ),
          // Com um catálogo antigo, sem a lista dos alfas, o motivo some.
          if (ref.watch(knowsAlphasProvider) || _isOn(HuntReason.noAlpha))
            CheckboxMenuButton(
              value: _isOn(HuntReason.noAlpha),
              closeOnActivate: false,
              onChanged: _check(_toggler(HuntReason.noAlpha)),
              child: MenuOptionText(
                context.l10n.huntReason(HuntReason.noAlpha),
                context.l10n.reasonNoAlphaHint,
                leading: const AlphaIcon(size: 18, semanticLabel: null),
              ),
            ),
          CheckboxMenuButton(
            value: _isOn(HuntReason.fromGo),
            closeOnActivate: false,
            onChanged: _check(_toggler(HuntReason.fromGo)),
            child: MenuOptionText(
              context.l10n.huntReason(HuntReason.fromGo),
              context.l10n.reasonFromGoHint,
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
                  ? context.l10n.reasonBallOutside(balls)
                  : context.l10n.reasonBallOutsideChosen,
              context.l10n.reasonBallHint,
              leading: const Icon(Icons.catching_pokemon, size: 18),
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
                  hintText: context.l10n.searchNameOrNumber,
                  onChanged: onSearchChanged,
                  onSubmitted: onSearchSubmitted,
                ),
              ),
              IconButton(
                tooltip: context.l10n.filtersTitle,
                onPressed: () async {
                  final applied = await showHuntFilters(
                    context,
                    query,
                    dexId: dexId,
                  );
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

/// O chip Jogo: abre a folha dos jogos ([showGamePicker]) e aplica o que
/// ela devolver.
class _GameChip extends StatelessWidget {
  const _GameChip({
    required this.dexId,
    required this.query,
    required this.savesOf,
    required this.onChanged,
  });

  final int dexId;
  final HuntQuery query;
  final Map<String, List<Save>> savesOf;
  final ValueChanged<HuntQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final games = query.versions;
    final names = joinLabels(context.l10n, [
      for (final g in games) versionLabel(g),
    ]);
    return FilterChip(
      tooltip: games.isEmpty ? null : context.l10n.filterGameValue(names),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (games.isEmpty)
            Text(context.l10n.fieldGame)
          else
            ChipIcons([
              for (final g in games) GameIcon(g, size: 18),
            ], semanticLabel: context.l10n.filterGameValue(names)),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
      selected: games.isNotEmpty,
      // Um jogo só marcado: o chip na cor dele (#203).
      selectedColor: {...games}.length == 1
          ? versionTone(games.first, Theme.of(context).brightness)?.background
          : null,
      showCheckmark: false,
      onSelected: (_) async {
        final picked = await showGamePicker(
          context,
          subtitle: context.l10n.huntableInSaves,
          sections: [
            GamePickerSection(
              title: context.l10n.fieldGame,
              versions: [...savesOf.keys],
              selected: games,
              saves: {for (final e in savesOf.entries) e.key: e.value.length},
              count: (version) => HuntCount(
                dexId: dexId,
                query: query.copyWith(versions: [version]),
              ),
            ),
          ],
          applyLabel: (ref, draft) {
            final count = ref
                .watch(
                  huntPageProvider((
                    dexId: dexId,
                    query: query.copyWith(versions: draft.single),
                    page: 1,
                  )),
                )
                .value
                ?.count;
            return count == null
                ? context.l10n.showResults
                : context.l10n.showCountResults(count);
          },
        );
        if (picked != null) onChanged(query.copyWith(versions: picked.single));
      },
    );
  }
}

/// `"Scarlet"`, `"Scarlet ou Sword"`, `"Scarlet, Violet ou Sword"`.
String _gameNames(AppLocalizations l10n, List<String> versions) =>
    joinAlternatives(l10n, [for (final v in versions) versionLabel(v)]);

/// O motivo em minúscula, no meio da frase ("Motivos: sem shiny").
String _lower(String text) => text.replaceRange(0, 1, text[0].toLowerCase());

/// Lista paginada, agrupada pela box do dex (#282): um cabeçalho por box,
/// preso no topo ao rolar, com o mapa dos slots. O total vem da 1ª página, e
/// cada item observa só a página em que está, carregada quando aparece na
/// tela.
class HuntList extends ConsumerWidget {
  const HuntList({
    required this.dexId,
    required this.query,
    required this.onTap,
    this.onTapGames,
    this.onOpenBox,
    this.onShowActive,
    super.key,
  });

  final int dexId;
  final HuntQuery query;
  final ValueChanged<Hunt> onTap;

  /// Os ícones de jogo de um item (#276): abrem o slot na aba Espécie.
  final ValueChanged<Hunt>? onTapGames;

  /// "Abrir box" do cabeçalho: a box no PersonalDex.
  final ValueChanged<BoxRef>? onOpenBox;

  /// O selo da caçada de um item, e começar uma caçada, levam à aba Ativas.
  final VoidCallback? onShowActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstPage = huntPageProvider((dexId: dexId, query: query, page: 1));
    final boxes = huntBoxesProvider((dexId: dexId, query: query));
    return switch (ref.watch(firstPage)) {
      AsyncData(value: final page) when page.count == 0 => EmptyView(
        message: context.l10n.nothingToHunt,
      ),
      AsyncData(value: final page) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              query.versions.isEmpty
                  ? context.l10n.toHunt(page.count)
                  : context.l10n.toHuntIn(
                      page.count,
                      _gameNames(context.l10n, query.versions),
                    ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: switch (ref.watch(boxes)) {
              AsyncData(value: final list) => RefreshIndicator.adaptive(
                onRefresh: () {
                  ref
                    ..invalidate(huntPageProvider)
                    ..invalidate(huntBoxesProvider);
                  return ref.read(firstPage.future);
                },
                child: CustomScrollView(slivers: _slivers(context, list)),
              ),
              AsyncError(:final error) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(boxes),
              ),
              _ => const LoadingView(),
            },
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

  /// Um grupo por box: o cabeçalho preso e os itens dela, que seguem a
  /// ordem da lista paginada.
  List<Widget> _slivers(BuildContext context, List<HuntBox> boxes) {
    final extent = HuntBoxHeader.extentFor(context);
    var offset = 0;
    return [
      for (final box in boxes)
        () {
          final first = offset;
          offset += box.count;
          return SliverMainAxisGroup(
            key: ValueKey('hunt-box-${box.box.id}'),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _BoxHeaderDelegate(
                  box: box,
                  extent: extent,
                  onOpen: switch (onOpenBox) {
                    final open? => () => open(box.box),
                    null => null,
                  },
                ),
              ),
              SliverList.builder(
                itemCount: box.count,
                itemBuilder: (context, i) => _HuntItem(
                  dexId: dexId,
                  query: query,
                  index: first + i,
                  onTap: onTap,
                  onTapGames: onTapGames,
                  onShowActive: onShowActive,
                ),
              ),
            ],
          );
        }(),
      const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
    ];
  }
}

class _BoxHeaderDelegate extends SliverPersistentHeaderDelegate {
  _BoxHeaderDelegate({required this.box, required this.extent, this.onOpen});

  final HuntBox box;
  final double extent;
  final VoidCallback? onOpen;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(
    // A altura reservada, não a do conteúdo: o sliver preso exige as duas
    // iguais.
    child: HuntBoxHeader(box: box, onOpen: onOpen, raised: overlapsContent),
  );

  @override
  bool shouldRebuild(_BoxHeaderDelegate old) =>
      old.box != box || old.extent != extent || old.onOpen != onOpen;
}

/// O cabeçalho de uma box do Faltam (#282): o mapa dos 30 slots, o nome, quantos
/// faltam na lista e "Abrir box". Preso no topo, ganha uma sombra.
class HuntBoxHeader extends StatelessWidget {
  const HuntBoxHeader({
    required this.box,
    this.onOpen,
    this.raised = false,
    super.key,
  });

  final HuntBox box;
  final VoidCallback? onOpen;
  final bool raised;

  /// A altura: 52 px, e mais com o texto aumentado.
  static double extentFor(BuildContext context) =>
      math.max(52, MediaQuery.textScalerOf(context).scale(20) + 32);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      elevation: raised ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          spacing: 12,
          children: [
            HuntBoxMap(cells: box.cells),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: box.box.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: context.l10n.huntBoxMissing(box.count),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onOpen != null)
              TextButton.icon(
                onPressed: onOpen,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right),
                label: Text(context.l10n.openBox),
              ),
          ],
        ),
      ),
    );
  }
}

/// O mapa de uma box (#282): 6 × 5 quadradinhos, cheios na cor principal o
/// que falta e está na lista, só o contorno o que falta fora dos filtros, e
/// discretos o que já tem.
class HuntBoxMap extends StatelessWidget {
  const HuntBoxMap({required this.cells, super.key});

  final List<HuntCell> cells;

  static const _cell = 5.0;
  static const _gap = 1.5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: _gap,
        children: [
          for (var row = 0; row < 5; row++)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: _gap,
              children: [
                for (var col = 0; col < 6; col++)
                  Container(
                    width: _cell,
                    height: _cell,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      color: switch (cells[row * 6 + col]) {
                        HuntCell.listed => scheme.primary,
                        HuntCell.done => scheme.outlineVariant,
                        HuntCell.hidden || HuntCell.empty => null,
                      },
                      border: cells[row * 6 + col] == HuntCell.hidden
                          ? Border.all(color: scheme.outline)
                          : null,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HuntItem extends ConsumerWidget {
  const _HuntItem({
    required this.dexId,
    required this.query,
    required this.index,
    required this.onTap,
    this.onTapGames,
    this.onShowActive,
  });

  final int dexId;
  final HuntQuery query;
  final int index;
  final ValueChanged<Hunt> onTap;
  final ValueChanged<Hunt>? onTapGames;
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
          onTapGames: switch (onTapGames) {
            final open? => () => open(page.results[offset]),
            null => null,
          },
          onShowActive: onShowActive,
        ),
      // A lista encolheu entre páginas (ex.: depositou um shiny).
      AsyncData() => const SizedBox.shrink(),
      // O erro aparece uma vez, no primeiro item da página.
      AsyncError() when offset == 0 => ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(context.l10n.huntsLoadMoreError),
        trailing: TextButton(
          onPressed: () => ref.invalidate(huntPageProvider(key)),
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

/// Um item do Faltam (#282): a forma, sem texto de subtítulo. Na 1ª linha,
/// o nome (até duas linhas) e os motivos fora do padrão como ícone (outra
/// pokébola, não shiny, shiny lock); na 2ª, onde caçar: os jogos dos seus
/// saves e a etiqueta do HOME. À direita, só a ação. No PC, tudo numa linha.
class HuntTile extends ConsumerWidget {
  const HuntTile({
    required this.hunt,
    required this.onTap,
    this.onTapGames,
    this.onShowActive,
    super.key,
  });

  final Hunt hunt;
  final VoidCallback onTap;

  /// Tocar nos ícones de jogo; `null` = eles fazem parte do item.
  final VoidCallback? onTapGames;
  final VoidCallback? onShowActive;

  /// A partir desta largura, o item fica numa linha só.
  static const wideFrom = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final form = hunt.slot.form;
    final name = Text(
      form?.displayName ?? '',
      style: theme.textTheme.bodyLarge,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Flexible(child: name),
        ..._reasonIcons(context, theme),
      ],
    );
    final home = hunt.versions.isEmpty ? null : _homeTag(ref);
    final games = hunt.versions.isEmpty ? null : _games(context, ref);
    final action = _huntAction(context, ref, form);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideFrom;
        return InkWell(
          key: ValueKey('hunt-${hunt.slot.id}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: wide ? 56 : 72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                spacing: 12,
                children: [
                  PokemonSprite(
                    url: form?.spriteFor(shiny: true),
                    size: wide ? 40 : 48,
                  ),
                  if (wide) ...[
                    Expanded(child: title),
                    ?games,
                    ?home,
                  ] else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          title,
                          // Num celular estreito, a etiqueta desce em vez de
                          // transbordar.
                          if (games != null || home != null)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              runSpacing: 4,
                              children: [
                                ?games,
                                if (games != null && home != null)
                                  const SizedBox(
                                    height: 16,
                                    child: VerticalDivider(width: 9),
                                  ),
                                ?home,
                              ],
                            ),
                        ],
                      ),
                    ),
                  ?action,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Os motivos que fogem do padrão, como ícone: "Faltando" e "Do GO" não
  /// aparecem (o primeiro é o normal numa lista do que falta).
  List<Widget> _reasonIcons(BuildContext context, ThemeData theme) {
    final color = theme.colorScheme.onSurfaceVariant;
    final lock = hunt.shinyLock;
    Widget icon(String message, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Tooltip(message: message, child: child),
    );
    return [
      if (hunt.reasons.contains(HuntReason.pokeball))
        icon(
          context.l10n.reasonOtherBall,
          Icon(Icons.catching_pokemon, size: 16, color: color),
        ),
      if (hunt.reasons.contains(HuntReason.noShiny) &&
          hunt.slot.specimen != null)
        icon(context.l10n.notShiny, const NoShinyIcon(size: 16)),
      if (hunt.reasons.contains(HuntReason.noAlpha))
        icon(
          context.l10n.huntReason(HuntReason.noAlpha),
          const AlphaIcon(size: 16, semanticLabel: null),
        ),
      if (lock != null)
        icon(
          context.l10n.shinyLockType(lock),
          Icon(Icons.lock_outline, size: 16, color: color),
        ),
    ];
  }

  /// Os ícones de jogo, ou nada sem save em que caçar; com [onTapGames], um
  /// alvo de toque próprio, que leva à lista completa na aba Espécie (#276).
  Widget? _games(BuildContext context, WidgetRef ref) {
    final owned = _owned(ref);
    if (!hunt.versions.any(owned.contains)) return null;
    final games = HuntGames(versions: hunt.versions, owned: owned);
    final open = onTapGames;
    if (open == null) return games;
    return Tooltip(
      message: context.l10n.huntGamesAll,
      child: InkWell(
        key: ValueKey('hunt-games-${hunt.slot.id}'),
        onTap: open,
        borderRadius: BorderRadius.circular(8),
        child: games,
      ),
    );
  }

  Set<String> _owned(WidgetRef ref) => {
    for (final save in ref.watch(savesProvider).value ?? const <Save>[])
      ?save.trainer.version,
  };

  /// A etiqueta do corte do HOME (#222) quando todos os jogos dos seus saves
  /// em que a forma pode ser caçada têm corte: o shiny achado ali não chega
  /// (ou deixa de chegar) ao HOME. A caçada continua possível.
  Widget? _homeTag(WidgetRef ref) {
    final cutoffOf = ref.watch(homeCutoffProvider);
    final cutoffs = [
      for (final v in hunt.versions)
        if (_owned(ref).contains(v)) cutoffOf(v),
    ];
    if (cutoffs.isEmpty || cutoffs.any((c) => c == null)) return null;
    return HomeTag(
      cutoffs.cast<HomeCutoff>().reduce(
        (a, b) => a.until.isAfter(b.until) ? a : b,
      ),
    );
  }

  /// Caçada em andamento desta forma: o selo (o mesmo da grade da box), que
  /// leva à aba; senão, o botão "Começar caçada" (desabilitado com um
  /// cronômetro rodando). Os dois têm o mesmo tamanho: o item não muda de
  /// largura.
  Widget? _huntAction(BuildContext context, WidgetRef ref, FormRef? form) {
    if (form == null) return null;
    final hunts = ref.watch(shinyHuntsProvider).value ?? const <ShinyHunt>[];
    if (hunts.any((h) => !h.paused && h.form == form.id)) {
      return IconButton(
        tooltip: context.l10n.huntInProgress,
        onPressed: onShowActive,
        icon: const HuntBadge(size: 28),
      );
    }
    return IconButton(
      tooltip: context.l10n.huntStart,
      onPressed: hunts.any((h) => h.running)
          ? null
          : () async {
              final started = await showHuntSheet(context, form: form);
              if (started != null) onShowActive?.call();
            },
      icon: const Icon(Icons.track_changes),
    );
  }
}

/// Onde caçar (#282): os ícones dos jogos em que o usuário tem save, lado a
/// lado, até [max]; o resto vira "+N". Os outros jogos ficam na Pokédex dos
/// jogos do detalhe da espécie (#202). Sem ícone: nenhum save serve para
/// caçar a forma.
class HuntGames extends StatelessWidget {
  const HuntGames({
    required this.versions,
    required this.owned,
    this.max = 6,
    super.key,
  });

  final List<String> versions;

  /// As versões dos saves do usuário.
  final Set<String> owned;
  final int max;

  @override
  Widget build(BuildContext context) {
    final mine = [...versions.where(owned.contains)];
    if (mine.isEmpty) return const SizedBox.shrink();
    final shown = mine.take(max).toList();
    final rest = mine.length - shown.length;
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        for (final version in shown)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: GameIcon(version),
          ),
        if (rest > 0)
          Text(
            '+$rest',
            semanticsLabel: context.l10n.moreGames(rest),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
      ],
    );
  }
}

/// O ícone de cada situação do slot (#219); "Todos" não tem.
Widget? _situationIcon(HuntSituation situation) => switch (situation) {
  HuntSituation.all => null,
  HuntSituation.missing => const Icon(Icons.radio_button_unchecked),
  HuntSituation.registered => const SuccessIcon(Icons.check_circle),
};

/// O ícone de cada motivo (#219), os mesmos do menu.
Widget _reasonIcon(HuntReason reason) => switch (reason) {
  HuntReason.noShiny => const NoShinyIcon(size: 18),
  HuntReason.noAlpha => const AlphaIcon(size: 18, semanticLabel: null),
  HuntReason.fromGo => const GoIcon(size: 18, semanticLabel: null),
  HuntReason.pokeball => const Icon(Icons.catching_pokemon),
};
