import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/auto_deposit_sheet.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_grid.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_list_panel.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_navigator.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_view.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_menu.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_switcher.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/generation_progress.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_detail_panel.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_navigation.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_search.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/deposit_flow.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';

/// Boxes de um PersonalDex.
///
/// - expandido: lista de boxes | grade | detalhe do slot
/// - médio: grade | detalhe do slot
/// - compacto: grade com swipe entre boxes; detalhe em bottom sheet
///
/// [initialBoxId]/[initialSlotId] (da URL `?box=&slot=`) abrem a página já
/// numa box com o slot selecionado, ex.: "Ver no dex" do inventário.
class DexDetailPage extends ConsumerStatefulWidget {
  const DexDetailPage({
    required this.dexId,
    this.initialBoxId,
    this.initialSlotId,
    super.key,
  });

  final int dexId;
  final int? initialBoxId;
  final int? initialSlotId;

  @override
  ConsumerState<DexDetailPage> createState() => _DexDetailPageState();
}

class _DexDetailPageState extends ConsumerState<DexDetailPage> {
  int _boxIndex = 0;
  late int? _selectedSlotId = widget.initialSlotId;

  /// A box pedida na URL só é aplicada uma vez, quando as boxes carregam.
  bool _initialBoxApplied = false;

  /// No compacto, o slot pedido na URL (caçadas, "Ver no dex") já abre no
  /// bottom sheet, uma vez só; nos demais tamanhos o painel já fica ao lado.
  late bool _openInitialSheet = widget.initialSlotId != null;
  bool _onlyMissing = false;

  /// A última troca de box pela navegação do painel (o balão), e o sentido
  /// do último passo. Um toque na grade limpa os dois.
  BoxNotice? _boxNotice;
  int _direction = 0;

  /// Avisa o bottom sheet de que a seleção mudou. O sheet é outra rota: o
  /// `setState` da página não o reconstrói.
  final ValueNotifier<int> _selection = ValueNotifier(0);

  /// Lista de boxes ao lado da grade (expandido e maior). `null` = padrão do
  /// tamanho: aberta só em telas largas, para a grade crescer no PC.
  bool? _boxListOpen;

  bool _isBoxListOpen(WindowSize size) => _boxListOpen ?? size.isLarge;
  PageController? _pageController;

  int get _dexId => widget.dexId;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// Texto da busca depois do debounce (o que vai para a API).
  String _search = '';
  Timer? _searchDebounce;

  /// Resultado destacado (o que o Enter abre): volta ao primeiro a cada
  /// busca nova.
  int _highlight = 0;

  /// Enter apertado: abrir o destacado assim que a lista chegar.
  bool _openWhenReady = false;

  final GlobalKey _searchStackKey = GlobalKey();
  final GlobalKey _pillAnchorKey = GlobalKey();

  /// Onde a pílula fica em repouso (meio da borda de cima), medido logo
  /// abaixo da grade.
  Offset? _pillRest;

  /// Depois da primeira medida, a pílula passa a animar ao mudar de lugar.
  bool _pillPlaced = false;

  /// Busca ativa: com foco ou com texto. Os resultados cobrem as boxes.
  bool get _searching =>
      _searchFocus.hasFocus || _searchController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(lastDexStorageProvider).write(_dexId));
    // Ganhar ou perder o foco muda o layout (AppBar, "Cancelar").
    _searchFocus.addListener(() => setState(() {}));
  }

  bool get _preferShiny =>
      ref.read(dexProvider(_dexId)).value?.isShinyDex ?? false;

  @override
  void dispose() {
    _pageController?.dispose();
    _selection.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dex = ref.watch(dexProvider(_dexId));
    final boxes = ref.watch(boxesProvider(_dexId));
    final body = _body(context, dex, boxes);
    return Scaffold(body: _searchLayout(context, dex.value, body));
  }

  /// Como a tela inicial do iPhone, a busca é uma pílula logo abaixo da
  /// grade da box (no celular, no alcance do polegar). O mesmo vale para
  /// telas maiores, para não ter uma barra de busca sempre aberta no topo.
  ///
  /// A pílula é o próprio campo de texto (o Safari do iOS só abre o teclado
  /// com um toque no campo). Ao ganhar o foco, o mesmo campo anima até o
  /// topo e vira a barra de busca, com os resultados por trás. Ele muda de
  /// lugar com um `AnimatedPositioned` e nunca é recriado, então o foco (e o
  /// teclado) continuam durante a animação.
  Widget _searchLayout(BuildContext context, PersonalDex? dex, Widget body) {
    final active = _searching;
    final top = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Ativa, a barra vai para o topo, centralizada junto do "Cancelar";
        // no celular ocupa a largura, nas telas maiores tem um limite.
        final barWidth = math.min(width - 16 - _cancelWidth, _maxBarWidth);
        final barLeft = math.max<double>(
          16,
          (width - barWidth - _cancelWidth) / 2,
        );
        final rest = _pillRest;
        return Stack(
          key: _searchStackKey,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A AppBar fica no corpo (e não em `Scaffold.appBar`) para
                // poder recolher com animação durante a busca: o
                // AnimatedAlign encolhe a altura até zero.
                ClipRect(
                  child: AnimatedAlign(
                    duration: searchAnimationDuration,
                    curve: searchAnimationCurve,
                    alignment: Alignment.bottomCenter,
                    heightFactor: active ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: active,
                      child: ExcludeSemantics(
                        excluding: active,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: active ? 0 : 1,
                          child: _appBar(context, dex),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
            Positioned.fill(
              child: _resultsPanel(
                context,
                topInset: top + _barHeight + 2 * _barMargin,
              ),
            ),
            Positioned(
              top: top + _barMargin,
              left: barLeft + barWidth + 8,
              height: _barHeight,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: active
                    ? TextButton(
                        key: const ValueKey('search-cancel'),
                        onPressed: _cancelSearch,
                        child: const Text('Cancelar'),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            AnimatedPositioned(
              // A primeira posição medida entra sem animação (senão a pílula
              // subiria do rodapé ao abrir a tela).
              duration: _pillPlaced ? searchAnimationDuration : Duration.zero,
              curve: searchAnimationCurve,
              // Em repouso, logo abaixo da grade (ver _withPillAnchor). Sem
              // grade (carregando, erro), no rodapé, centralizada.
              left: active ? barLeft : (rest?.dx ?? width / 2) - _pillWidth / 2,
              top: active
                  ? top + _barMargin
                  : rest?.dy ??
                        constraints.maxHeight - _pillHeight - _pillMargin,
              width: active ? barWidth : _pillWidth,
              height: active ? _barHeight : _pillHeight,
              child: SlotSearchPill(
                controller: _searchController,
                focusNode: _searchFocus,
                active: active,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
                onSubmitted: _submitSearch,
                onMove: _moveHighlight,
                onEscape: _cancelSearch,
              ),
            ),
          ],
        );
      },
    );
  }

  static const _pillWidth = 160.0;
  static const _pillHeight = 44.0;
  static const _pillMargin = 12.0;

  /// Distância entre a última linha da box e a pílula.
  static const _pillGap = 16.0;
  static const _barHeight = 56.0;
  static const _barMargin = 8.0;

  /// Largura máxima da barra ativa (telas maiores).
  static const _maxBarWidth = 560.0;

  /// Largura reservada ao "Cancelar" à direita da barra ativa.
  static const _cancelWidth = 104.0;

  /// Resultados por cima das boxes enquanto a busca está ativa. [topInset]
  /// deixa livre o espaço da barra, que flutua por cima.
  Widget _resultsPanel(BuildContext context, {required double topInset}) =>
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _searching
            ? Material(
                key: const ValueKey('search-results'),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.only(top: topInset),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: SlotSearchResults(
                        dexId: _dexId,
                        search: _search,
                        onSelected: _goToSlot,
                        highlighted: _highlight,
                        onHighlight: (i) => setState(() => _highlight = i),
                        onReady: _openWhenReady ? _openReady : null,
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );

  /// Título (nome e progresso do dex), Caçadas, faltantes e o menu ⋮. Só o
  /// essencial, para o nome caber inteiro no celular.
  AppBar _appBar(BuildContext context, PersonalDex? dex) {
    final size = WindowSize.of(context);
    return AppBar(
      title: DexSwitcher(
        dexId: _dexId,
        title: dex?.name ?? 'PersonalDex',
        subtitle: dex == null
            ? null
            : '${dex.registered} de ${dex.total} registrados · '
                  '${percentOf(dex.registered, dex.total)}%',
      ),
      actions: [
        if (size.isExpanded)
          IconButton(
            tooltip: _isBoxListOpen(size)
                ? 'Ocultar lista de boxes'
                : 'Mostrar lista de boxes',
            isSelected: _isBoxListOpen(size),
            onPressed: () =>
                setState(() => _boxListOpen = !_isBoxListOpen(size)),
            icon: const Icon(Icons.view_sidebar_outlined),
            selectedIcon: const Icon(Icons.view_sidebar),
          ),
        if (dex?.isShinyDex ?? false)
          IconButton(
            tooltip: 'Caçadas',
            onPressed: () => context.push(Routes.hunts(_dexId)),
            icon: const Icon(Icons.track_changes),
          ),
        _missingToggle(context),
        if (dex != null)
          DexMenu(
            dex: dex,
            onShowProgress: _openGenerations,
            onAutoDeposit: () => _autoDeposit(dex),
          ),
      ],
    );
  }

  /// Filtro da visualização, na AppBar. Selecionado, ganha fundo para o
  /// estado ficar visível.
  Widget _missingToggle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: _onlyMissing ? 'Mostrar todos' : 'Destacar faltantes',
      isSelected: _onlyMissing,
      onPressed: () => setState(() => _onlyMissing = !_onlyMissing),
      style: _onlyMissing
          ? IconButton.styleFrom(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
            )
          : null,
      icon: const Icon(Icons.filter_alt_outlined),
      selectedIcon: const Icon(Icons.filter_alt),
    );
  }

  Widget _body(
    BuildContext context,
    AsyncValue<PersonalDex> dex,
    AsyncValue<List<BoxSummary>> boxes,
  ) => switch (dex) {
    AsyncError(:final error) when !dex.hasValue => ErrorView(
      error: error,
      onRetry: () => ref.invalidate(dexProvider(_dexId)),
    ),
    _ => boxes.when(
      skipLoadingOnRefresh: true,
      data: (items) => items.isEmpty
          ? const EmptyView(message: 'Este dex ainda não tem boxes.')
          : _buildLayout(context, items),
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(boxesProvider(_dexId)),
      ),
    ),
  };

  /// Espera o usuário parar de digitar antes de consultar a API.
  void _onSearchChanged(String text) {
    _openWhenReady = false;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => setState(() {
        _search = text.trim();
        _highlight = 0;
      }),
    );
  }

  /// Enter: abre o resultado destacado, como um toque nele. Usa o texto do
  /// campo agora, sem esperar o debounce: quem digita rápido e já aperta
  /// Enter abre o primeiro do que digitou, assim que a lista chegar (ver
  /// [SlotSearchResults.onReady]). Texto curto ou nenhum resultado: nada (a
  /// lista explica).
  void _submitSearch() {
    _searchDebounce?.cancel();
    final text = _searchController.text.trim();
    if (!slotSearchReady(text)) return;
    setState(() {
      if (text != _search) {
        _search = text;
        _highlight = 0;
      }
      _openWhenReady = true;
    });
  }

  /// A lista chegou depois de um Enter: abre o destacado, uma vez só.
  void _openReady(Slot slot) {
    if (_openWhenReady) _goToSlot(slot);
  }

  /// ↑/↓: move o destaque, sem passar do primeiro nem do último.
  void _moveHighlight(int delta) {
    final slots = ref
        .read(slotSearchProvider((dexId: _dexId, search: _search)))
        .value;
    if (slots == null || slots.isEmpty) return;
    setState(
      () => _highlight = (_highlight + delta).clamp(0, slots.length - 1),
    );
  }

  /// O "x" do campo: apaga o texto na hora (sem debounce) e mantém o foco,
  /// para digitar outra coisa. Chamado dentro do toque, então o teclado do
  /// iPhone continua aberto.
  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocus.requestFocus();
    setState(() {
      _search = '';
      _highlight = 0;
    });
  }

  /// Limpa a busca e devolve as boxes (a AppBar volta junto).
  void _cancelSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _search = '';
      _highlight = 0;
      _openWhenReady = false;
    });
  }

  Widget _buildLayout(BuildContext context, List<BoxSummary> boxes) {
    _applyInitialBox(boxes);
    final index = _boxIndex.clamp(0, boxes.length - 1);
    final box = boxes[index];
    final size = WindowSize.of(context);
    final openSheet = _openInitialSheet;
    _openInitialSheet = false;
    if (size.isCompact) {
      if (openSheet) {
        // Depois do frame: não dá para abrir um sheet no meio do build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showSlotSheet(box));
        });
      }
      return _buildCompact(boxes, index);
    }
    _releasePageController();

    final grid = Column(
      children: [
        BoxNavigator(boxes: boxes, index: index, onChanged: _selectBox),
        Expanded(child: _withPillAnchor(_boxView(box))),
      ],
    );
    final detail = SizedBox(
      width: size.isExpanded ? 320 : 280,
      child: SlotDetailPanel(
        slot: _selectedSlot(box),
        onDeposit: () => _deposit(_selectedSlot(box)!),
        onEdit: () => _edit(_selectedSlot(box)!),
        onRelease: () => _release(_selectedSlot(box)!),
        onWithdraw: () => _withdraw(_selectedSlot(box)!),
        onOpenSlot: _goToSlot,
        onShowHunts: _showHunts,
        navigation: _navigation(boxes, index),
        fillHeight: true,
      ),
    );
    return Row(
      children: [
        if (size.isExpanded && _isBoxListOpen(size)) ...[
          SizedBox(
            width: 220,
            child: BoxListPanel(
              boxes: boxes,
              index: index,
              onSelected: _selectBox,
            ),
          ),
          const VerticalDivider(width: 1),
        ],
        Expanded(child: grid),
        const VerticalDivider(width: 1),
        detail,
      ],
    );
  }

  Widget _buildCompact(List<BoxSummary> boxes, int index) {
    final controller = _pageController ??= PageController(initialPage: index);
    return Column(
      children: [
        BoxNavigator(
          boxes: boxes,
          index: index,
          onChanged: (i) {
            _selectBox(i);
            controller.jumpToPage(i);
          },
        ),
        Expanded(
          child: _withPillAnchor(
            PageView.builder(
              controller: controller,
              itemCount: boxes.length,
              // Ignora a página atual: pular para a box de um slot buscado
              // não pode limpar a seleção.
              onPageChanged: (i) {
                if (i != _boxIndex) _selectBox(i);
              },
              itemBuilder: (context, i) => _boxView(boxes[i], compact: true),
            ),
          ),
        ),
      ],
    );
  }

  /// A área das boxes ([page]) com o lugar da pílula de busca logo abaixo
  /// da grade, como a busca da tela inicial do iPhone acompanha os ícones: o
  /// espaço dela é reservado embaixo, e o conjunto grade + pílula fica
  /// centralizado.
  Widget _withPillAnchor(Widget page) => LayoutBuilder(
    builder: (context, area) {
      // Embaixo da pílula fica uma margem, para ela não colar no rodapé.
      final pageHeight = area.maxHeight - _pillHeight - _pillGap - _pillMargin;
      // A grade fica centralizada na página, dentro da margem do BoxView: a
      // borda de baixo dela fica a meia altura dela abaixo do centro.
      final grid = boxGridSize(
        Size(
          area.maxWidth - 2 * boxViewPadding,
          pageHeight - 2 * boxViewPadding,
        ),
      );
      // A pílula fica numa camada acima de tudo (para poder subir até o
      // topo); aqui só marcamos o lugar dela, e a página mede depois do
      // layout.
      WidgetsBinding.instance.addPostFrameCallback((_) => _measurePillAnchor());
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: pageHeight,
            child: page,
          ),
          Positioned(
            top: pageHeight / 2 + grid.height / 2 + _pillGap,
            left: 0,
            right: 0,
            height: _pillHeight,
            child: SizedBox(key: _pillAnchorKey),
          ),
        ],
      );
    },
  );

  /// Converte a marca da pílula (dentro da área das boxes) para a camada da
  /// busca, onde a pílula de fato fica. Só reconstrói se a posição mudou.
  void _measurePillAnchor() {
    if (!mounted) return;
    final anchor = _pillAnchorKey.currentContext?.findRenderObject();
    final stack = _searchStackKey.currentContext?.findRenderObject();
    if (anchor is! RenderBox || stack is! RenderBox) return;
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: stack);
    final rest = topLeft + Offset(anchor.size.width / 2, 0);
    if (rest == _pillRest) return;
    final first = _pillRest == null;
    setState(() => _pillRest = rest);
    if (first) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pillPlaced = true);
    }
  }

  Widget _boxView(BoxSummary box, {bool compact = false}) => BoxView(
    dexId: _dexId,
    boxId: box.id,
    selectedSlotId: _selectedSlotId,
    onlyMissing: _onlyMissing,
    onSlotTap: (slot) {
      setState(() {
        _selectedSlotId = slot.id;
        _boxNotice = null;
        _direction = 0;
      });
      if (compact) unawaited(_showSlotSheet(box));
    },
  );

  /// Posiciona na box da URL. Roda dentro do build, antes de o índice ser
  /// usado, então basta ajustar o campo (sem setState).
  void _applyInitialBox(List<BoxSummary> boxes) {
    if (_initialBoxApplied) return;
    _initialBoxApplied = true;
    final index = boxes.indexWhere((b) => b.id == widget.initialBoxId);
    if (index >= 0) _boxIndex = index;
  }

  /// Resultado escolhido na busca: fecha a busca e leva até a box, com o
  /// slot selecionado (no compacto, já abre o detalhe no bottom sheet).
  void _goToSlot(Slot slot) {
    _cancelSearch();
    final boxes = ref.read(boxesProvider(_dexId)).value ?? const [];
    final index = boxes.indexWhere((b) => b.id == slot.box.id);
    setState(() {
      _boxIndex = index < 0 ? _boxIndex : index;
      _selectedSlotId = slot.id;
      _boxNotice = null;
      _direction = 0;
    });
    final controller = _pageController;
    if (controller == null) return;
    controller.jumpToPage(_boxIndex);
    unawaited(_showSlotSheet(boxes[_boxIndex]));
  }

  /// Progresso por geração; tocar numa geração leva à primeira box dela.
  Future<void> _openGenerations() async {
    final boxId = await showGenerationProgress(context, dexId: _dexId);
    if (boxId == null || !mounted) return;
    final boxes = ref.read(boxesProvider(_dexId)).value ?? const [];
    final index = boxes.indexWhere((b) => b.id == boxId);
    if (index < 0) return;
    _selectBox(index);
    _pageController?.jumpToPage(index);
  }

  void _selectBox(int index) => setState(() {
    _boxIndex = index;
    _selectedSlotId = null;
    _boxNotice = null;
  });

  /// A navegação do painel para o slot selecionado da box [index]; `null`
  /// enquanto os slots carregam ou sem slot selecionado.
  SlotNavigation? _navigation(
    List<BoxSummary> boxes,
    int index, [
    WidgetRef? watcher,
  ]) {
    final box = boxes[index];
    final slots = (watcher ?? ref)
        .watch(slotsProvider((dexId: _dexId, boxId: box.id)))
        .value;
    if (slots == null) return null;
    final list = navigableSlots(
      slots,
      onlyMissing: _onlyMissing,
      keep: _selectedSlotId,
    );
    final position = list.indexWhere((s) => s.id == _selectedSlotId);
    if (position < 0) return null;
    final slot = list[position];
    return SlotNavigation(
      label:
          '${box.name} · L${slot.row + 1} C${slot.col + 1} · '
          '${position + 1} de ${list.length}',
      onPrevious: position == 0 && index == 0
          ? null
          : () => unawaited(_step(-1)),
      onNext: position == list.length - 1 && index == boxes.length - 1
          ? null
          : () => unawaited(_step(1)),
      notice: _boxNotice,
      direction: _direction,
    );
  }

  /// Vai para o slot anterior ([delta] -1) ou o seguinte (1). Na borda da
  /// box, passa para a vizinha (pulando as que não têm slot para mostrar,
  /// como uma box completa com o filtro de faltantes), com o balão. Os
  /// slots da box vizinha podem não ter carregado ainda: daí o `await`.
  Future<void> _step(int delta) async {
    final boxes = ref.read(boxesProvider(_dexId)).value ?? const [];
    final start = _boxIndex.clamp(0, boxes.length - 1);
    var index = start;
    try {
      var list = await _navigableOf(boxes[index]);
      var target = list.indexWhere((s) => s.id == _selectedSlotId) + delta;
      while (target < 0 || target >= list.length) {
        index += delta;
        if (index < 0 || index >= boxes.length) return;
        list = await _navigableOf(boxes[index]);
        target = delta > 0 ? 0 : list.length - 1;
      }
      if (!mounted) return;
      final slot = list[target];
      setState(() {
        _boxIndex = index;
        _selectedSlotId = slot.id;
        _direction = delta;
        if (index != start) {
          _boxNotice = BoxNotice((_boxNotice?.id ?? 0) + 1, boxes[index].name);
        }
      });
      _selection.value++;
      if (index != start) _pageController?.jumpToPage(index);
    } on AppFailure catch (failure) {
      _notify(failure.message);
    }
  }

  Future<List<Slot>> _navigableOf(BoxSummary box) async => navigableSlots(
    await ref.read(slotsProvider((dexId: _dexId, boxId: box.id)).future),
    onlyMissing: _onlyMissing,
    keep: _selectedSlotId,
  );

  /// Slot selecionado, sempre na versão mais recente vinda da API.
  ///
  /// [watcher] é o `ref` de quem vai se reconstruir quando os slots mudarem.
  /// O bottom sheet passa o do próprio `Consumer`: com o `ref` da página, o
  /// sheet não se atualizaria quando os slots terminassem de carregar.
  Slot? _selectedSlot(BoxSummary box, [WidgetRef? watcher]) {
    final slots = (watcher ?? ref)
        .watch(slotsProvider((dexId: _dexId, boxId: box.id)))
        .value;
    if (slots == null) return null;
    for (final slot in slots) {
      if (slot.id == _selectedSlotId) return slot;
    }
    return null;
  }

  void _releasePageController() {
    final old = _pageController;
    if (old == null) return;
    _pageController = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// Abre as caçadas na aba Ativas; `null` fora de um shiny dex.
  VoidCallback? get _showHunts =>
      (ref.read(dexProvider(_dexId)).value?.isShinyDex ?? false)
      ? () => unawaited(context.push(Routes.hunts(_dexId, active: true)))
      : null;

  Future<void> _showSlotSheet(BoxSummary box) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => Consumer(
        builder: (context, sheetRef, _) {
          // A navegação do painel pode levar a outra box: o sheet segue a box
          // atual, e não a do slot que o abriu.
          final boxes = sheetRef.watch(boxesProvider(_dexId)).value ?? [box];
          final index = _boxIndex.clamp(0, boxes.length - 1);
          final slot = _selectedSlot(boxes[index], sheetRef);
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: SlotDetailPanel(
              slot: slot,
              onDeposit: () {
                Navigator.of(sheetContext).pop();
                unawaited(_deposit(slot!));
              },
              onEdit: () {
                Navigator.of(sheetContext).pop();
                unawaited(_edit(slot!));
              },
              onRelease: () {
                Navigator.of(sheetContext).pop();
                unawaited(_release(slot!));
              },
              onWithdraw: () {
                Navigator.of(sheetContext).pop();
                unawaited(_withdraw(slot!));
              },
              // Outra forma da linha evolutiva: fecha este sheet e abre o do
              // slot dela (na box certa).
              onOpenSlot: (other) {
                Navigator.of(sheetContext).pop();
                _goToSlot(other);
              },
              onShowHunts: _showHunts == null
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      _showHunts!();
                    },
              navigation: _navigation(boxes, index, sheetRef),
            ),
          );
        },
      ),
    ),
  );

  /// Retira o espécime do slot (ele fica disponível no inventário). A
  /// mensagem tem "Desfazer", que o deposita de novo no mesmo slot.
  Future<void> _withdraw(Slot slot) async {
    final specimen = slot.specimen!;
    final actions = ref.read(slotActionsProvider);
    try {
      await actions.withdraw(slot);
    } on AppFailure catch (failure) {
      _notify(failure.message);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${specimen.displayName} retirado do slot.'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              try {
                await actions.deposit(slot, specimenId: specimen.id);
              } on AppFailure catch (failure) {
                _notify(failure.message);
              }
            },
          ),
        ),
      );
  }

  Future<void> _autoDeposit(PersonalDex dex) async {
    final result = await showAutoDepositSheet(context, dex: dex);
    if (result == null) return;
    _notify(
      result.linked == 1
          ? '1 espécime depositado.'
          : '${result.linked} espécimes depositados.',
    );
  }

  Future<void> _deposit(Slot slot) async {
    final deposited = await showDepositFlow(
      context,
      slot: slot,
      preferShiny: _preferShiny,
    );
    if (deposited && mounted) _notify('Specimen depositado.');
  }

  Future<void> _edit(Slot slot) async {
    // Navigator raiz: o formulário cobre a casca toda (inclusive a
    // NavigationBar do compacto), como um diálogo de tela cheia.
    final edited = await Navigator.of(context, rootNavigator: true)
        .push<Specimen>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => SpecimenFormPage(
              form: slot.form!,
              specimenId: slot.specimen!.id,
            ),
          ),
        );
    if (edited == null) return;
    ref.read(slotActionsProvider).specimenEdited(slot);
    _notify('Espécime atualizado.');
  }

  /// Libertar apaga o cadastro do specimen (como o *release* do HOME).
  Future<void> _release(Slot slot) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.warning_amber_rounded,
      title: 'Libertar ${slot.specimen!.displayName}?',
      message:
          'O cadastro deste espécime será apagado e o slot ficará faltante. '
          'Esta ação não pode ser desfeita.',
      confirmLabel: 'Libertar',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(slotActionsProvider).release(slot);
      _notify('Espécime libertado.');
    } on AppFailure catch (failure) {
      _notify(failure.message);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
