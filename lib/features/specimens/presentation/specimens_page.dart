import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_detail.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/bulk_edit_sheet.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Inventário: todos os specimens, com busca e filtros.
///
/// - compacto: lista; tocar abre o detalhe em tela própria
/// - médio/expandido: lista | detalhe do specimen selecionado
/// - toque longo: modo de seleção para editar em lote (tocar marca e
///   desmarca; a AppBar mostra as ações do lote). A seleção sobrevive à
///   busca e aos filtros, para montar o lote em várias buscas; o chip
///   "Só selecionados" lista só os marcados.
class SpecimensPage extends ConsumerStatefulWidget {
  const SpecimensPage({super.key});

  @override
  ConsumerState<SpecimensPage> createState() => _SpecimensPageState();
}

class _SpecimensPageState extends ConsumerState<SpecimensPage> {
  SpecimenQuery _query = emptySpecimenQuery;
  int? _selectedId;
  Timer? _debounce;

  /// Marcados para a edição em lote; vazio = fora do modo de seleção.
  Set<int> _checked = {};

  /// Chip "Só selecionados": a lista mostra só os marcados.
  bool _onlySelected = false;

  bool get _selecting => _checked.isNotEmpty;

  /// O que a lista mostra: a consulta da barra, ou só os marcados (na mesma
  /// ordem escolhida).
  SpecimenQuery get _listQuery => _onlySelected
      ? SpecimenQuery(ids: [..._checked]..sort(), ordering: _query.ordering)
      : _query;

  /// Mudar a busca ou um filtro mantém a seleção (o lote pode juntar
  /// resultados de várias buscas) e volta da visão "Só selecionados".
  void _setQuery(SpecimenQuery query) => setState(() {
    _query = query;
    _onlySelected = false;
  });

  /// Troca a seleção; sem nenhum marcado, sai do modo de seleção.
  void _setChecked(Set<int> checked) => setState(() {
    _checked = checked;
    if (checked.isEmpty) _onlySelected = false;
  });

  void _toggle(Specimen specimen) => _setChecked(
    _checked.contains(specimen.id)
        ? ({..._checked}..remove(specimen.id))
        : {..._checked, specimen.id},
  );

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

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
    final size = WindowSize.of(context);
    final list = Column(
      children: [
        _Filters(
          query: _query,
          onSearchChanged: _onSearchChanged,
          onChanged: _setQuery,
          selectedCount: _checked.length,
          onlySelected: _onlySelected,
          onOnlySelectedChanged: (on) => setState(() => _onlySelected = on),
        ),
        Expanded(
          child: SpecimenList(
            query: _listQuery,
            selectedId: size.isCompact ? null : _selectedId,
            checkedIds: _selecting ? _checked : null,
            onLongPress: _toggle,
            onTap: (specimen) => _selecting
                ? _toggle(specimen)
                : size.isCompact
                ? context.go(Routes.specimen(specimen.id))
                : setState(() => _selectedId = specimen.id),
          ),
        ),
      ],
    );
    final selected = _selectedId;
    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                tooltip: 'Cancelar seleção',
                onPressed: () => _setChecked({}),
                icon: const Icon(Icons.close),
              ),
              title: _SelectionTitle(
                checked: _checked,
                // Na visão "Só selecionados", todos estão na lista.
                query: _onlySelected ? null : _query,
              ),
              actions: [
                IconButton(
                  tooltip: 'Selecionar todos os resultados',
                  onPressed: _selectAll,
                  icon: const Icon(Icons.select_all),
                ),
                IconButton(
                  tooltip: 'Editar em lote',
                  onPressed: _bulkEdit,
                  icon: const Icon(Icons.edit_note),
                ),
              ],
            )
          : AppBar(title: const Text('Espécimes')),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton.extended(
              // As abas ficam vivas juntas: cada botão precisa da sua hero
              // tag.
              heroTag: 'new-specimen',
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Novo espécime'),
            ),
      body: size.isCompact
          ? list
          : Row(
              children: [
                SizedBox(width: size.isExpanded ? 440 : 340, child: list),
                const VerticalDivider(width: 1),
                Expanded(
                  child: selected == null
                      ? const Center(
                          child: Text('Selecione um espécime na lista.'),
                        )
                      : SpecimenDetailView(
                          key: ValueKey(selected),
                          specimenId: selected,
                          onReleased: () => setState(() => _selectedId = null),
                        ),
                ),
              ],
            ),
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// Soma à seleção todos os resultados do filtro, inclusive as páginas não
  /// carregadas.
  Future<void> _selectAll() async {
    try {
      final ids = await ref
          .read(specimenRepositoryProvider)
          .fetchSpecimenIds(_listQuery);
      if (mounted) _setChecked({..._checked, ...ids});
    } on AppFailure catch (failure) {
      if (mounted) _showMessage(failure.message);
    }
  }

  Future<void> _bulkEdit() async {
    final count = _checked.length;
    final changes = await showBulkEditSheet(context, count);
    if (changes == null || !mounted) return;
    final labels = BulkLabels(
      context,
      ref,
      ref.read(specimenOptionsProvider).value ?? const SpecimenOptions(),
      ref.read(trainersProvider).value ?? const <Trainer>[],
    );
    final confirmed = await confirmBulkEdit(
      context,
      count: count,
      summary: labels.summary(changes),
    );
    if (!confirmed || !mounted) return;
    try {
      final updated = await ref
          .read(specimenRepositoryProvider)
          .bulkUpdate(ids: [..._checked]..sort(), changes: changes);
      ref.read(slotActionsProvider).specimensChanged();
      if (!mounted) return;
      _setChecked({});
      _showMessage(
        '$updated ${updated == 1 ? 'espécime atualizado' : 'espécimes atualizados'}.',
      );
    } on GenderConflictFailure catch (failure) {
      if (mounted) await _showGenderConflicts(failure);
    } on AppFailure catch (failure) {
      if (mounted) _showMessage(failure.message);
    }
  }

  /// Nada foi gravado; mostra quem impediu e oferece desmarcá-los.
  Future<void> _showGenderConflicts(GenderConflictFailure failure) async {
    final uncheck = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gênero impossível'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text('${failure.message} Nenhum espécime foi alterado.'),
              const SizedBox(height: 4),
              for (final c in failure.conflicts)
                Text('• ${prettifyName(c.formName)} (#${c.id})'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desmarcar estes'),
          ),
        ],
      ),
    );
    if (uncheck ?? false) {
      _setChecked({..._checked}..removeAll(failure.conflicts.map((c) => c.id)));
    }
  }

  /// Cadastro avulso: escolhe a forma e abre o formulário, sem depositar.
  Future<void> _create() async {
    final form = await showFormPicker(context);
    if (form == null || !mounted) return;
    final created = await Navigator.of(context, rootNavigator: true)
        .push<Specimen>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) =>
                SpecimenFormPage(form: form, depositAfterSave: false),
          ),
        );
    if (created == null || !mounted) return;
    ref.read(slotActionsProvider).specimensChanged();
    setState(() => _selectedId = created.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Espécime cadastrado.')));
  }
}

/// Barra de filtros pensada para o celular: busca + botão Filtros numa
/// linha; filtros rápidos numa linha rolável (altura fixa); e, só quando há
/// filtros avançados ativos, uma linha com os chips removíveis deles.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.query,
    required this.onSearchChanged,
    required this.onChanged,
    required this.selectedCount,
    required this.onlySelected,
    required this.onOnlySelectedChanged,
  });

  final SpecimenQuery query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SpecimenQuery> onChanged;

  /// Marcados para o lote (0 = fora do modo de seleção).
  final int selectedCount;
  final bool onlySelected;
  final ValueChanged<bool> onOnlySelectedChanged;

  @override
  Widget build(BuildContext context) {
    final count = query.advancedCount;
    final quick = <Widget>[
      // No modo de seleção, o primeiro chip lista só os marcados.
      if (selectedCount > 0)
        FilterChip(
          avatar: const Icon(Icons.checklist),
          label: Text('Só selecionados ($selectedCount)'),
          selected: onlySelected,
          onSelected: onOnlySelectedChanged,
        ),
      SegmentedButton<SpecimenStatus>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: SpecimenStatus.all, label: Text('Todos')),
          ButtonSegment(
            value: SpecimenStatus.available,
            label: Text('Disponíveis'),
          ),
          ButtonSegment(
            value: SpecimenStatus.deposited,
            label: Text('Depositados'),
          ),
        ],
        selected: {query.status},
        onSelectionChanged: (s) => onChanged(query.copyWith(status: s.single)),
      ),
      FilterChip(
        avatar: const Text(shinyEmoji),
        label: const Text('Shiny'),
        selected: query.shinyOnly,
        onSelected: (v) => onChanged(query.copyWith(shinyOnly: v)),
      ),
      FilterChip(
        avatar: const Text(alphaEmoji),
        label: const Text('Alfa'),
        selected: query.alphaOnly,
        onSelected: (v) => onChanged(query.copyWith(alphaOnly: v)),
      ),
      FilterChip(
        avatar: const Text(goEmoji),
        label: const Text('GO'),
        tooltip: 'Veio do Pokémon GO',
        selected: query.fromGoOnly,
        onSelected: (v) => onChanged(query.copyWith(fromGoOnly: v)),
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
                    hintText: 'Buscar por apelido ou forma',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              IconButton(
                tooltip: 'Filtros',
                onPressed: () async {
                  final applied = await showSpecimenFilters(context, query);
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
          // No celular, uma linha rolável (altura fixa); nos demais tamanhos
          // não falta espaço vertical, então os chips quebram linha.
          child: WindowSize.of(context).isCompact
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(spacing: 8, children: quick),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: quick,
                ),
        ),
        ActiveFilterChips(query: query, onChanged: onChanged),
      ],
    );
  }
}

/// Título do modo de seleção: "N selecionados" e, se houver marcados fora
/// dos resultados da [query], "M fora da lista" (o lote vale para todos).
class _SelectionTitle extends ConsumerWidget {
  const _SelectionTitle({required this.checked, required this.query});

  final Set<int> checked;

  /// `null` quando todos os marcados estão na lista ("Só selecionados").
  final SpecimenQuery? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = this.query;
    final inList = query == null
        ? null
        : ref.watch(specimenIdsProvider(query)).value?.toSet();
    final outside = inList == null
        ? 0
        : checked.where((id) => !inList.contains(id)).length;
    final n = checked.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$n ${n == 1 ? 'selecionado' : 'selecionados'}'),
        if (outside > 0)
          Text(
            '$outside fora da lista',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

/// Lista paginada: o total vem da 1ª página e cada item observa só a página
/// em que está, carregada quando aparece na tela.
class SpecimenList extends ConsumerWidget {
  const SpecimenList({
    required this.query,
    required this.onTap,
    this.selectedId,
    this.checkedIds,
    this.onLongPress,
    super.key,
  });

  final SpecimenQuery query;
  final int? selectedId;
  final ValueChanged<Specimen> onTap;

  /// Marcados no modo de seleção; `null` = fora dele.
  final Set<int>? checkedIds;
  final ValueChanged<Specimen>? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstPage = specimenPageProvider((query: query, page: 1));
    return switch (ref.watch(firstPage)) {
      AsyncData(value: final page) when page.count == 0 => const EmptyView(
        message: 'Nenhum espécime encontrado.',
      ),
      AsyncData(value: final page) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResultCount(query: query, count: page.count),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: () {
                ref.invalidate(specimenPageProvider);
                return ref.read(firstPage.future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 88), // espaço do +
                itemCount: page.count,
                itemBuilder: (context, i) => _SpecimenItem(
                  query: query,
                  index: i,
                  selectedId: selectedId,
                  checkedIds: checkedIds,
                  onTap: onTap,
                  onLongPress: onLongPress,
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

/// Contador acima da lista: "1.159 espécimes" sem filtro, ou
/// "42 de 1.159 espécimes" com filtro. O [count] é o total da consulta (vem
/// da 1ª página); o total geral vem da mesma consulta sem filtros, que fica
/// em cache (sem filtro, é a mesma requisição).
class ResultCount extends ConsumerWidget {
  const ResultCount({required this.query, required this.count, super.key});

  final SpecimenQuery query;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = NumberFormat.decimalPattern('pt_BR');
    String noun(int n) => n == 1 ? 'espécime' : 'espécimes';
    // Com filtro, o total geral aparece assim que carregar; até lá, só o
    // número filtrado.
    final total = query.hasFilters
        ? ref
              .watch(specimenPageProvider((query: emptySpecimenQuery, page: 1)))
              .value
              ?.count
        : null;
    final text = total == null
        ? '${number.format(count)} ${noun(count)}'
        : '${number.format(count)} de ${number.format(total)} ${noun(total)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _SpecimenItem extends ConsumerWidget {
  const _SpecimenItem({
    required this.query,
    required this.index,
    required this.selectedId,
    required this.checkedIds,
    required this.onTap,
    required this.onLongPress,
  });

  final SpecimenQuery query;
  final int index;
  final int? selectedId;
  final Set<int>? checkedIds;
  final ValueChanged<Specimen> onTap;
  final ValueChanged<Specimen>? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (query: query, page: index ~/ specimenPageSize + 1);
    final offset = index % specimenPageSize;
    return switch (ref.watch(specimenPageProvider(key))) {
      AsyncData(value: final page) when offset < page.results.length =>
        SpecimenListTile(
          specimen: page.results[offset],
          selected: page.results[offset].id == selectedId,
          checked: checkedIds?.contains(page.results[offset].id),
          onTap: () => onTap(page.results[offset]),
          onLongPress: onLongPress == null
              ? null
              : () => onLongPress!(page.results[offset]),
        ),
      // A lista encolheu entre páginas (ex.: libertado): nada a mostrar.
      AsyncData() => const SizedBox.shrink(),
      // O erro aparece uma vez, no primeiro item da página.
      AsyncError() when offset == 0 => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Não foi possível carregar mais espécimes.'),
        trailing: TextButton(
          onPressed: () => ref.invalidate(specimenPageProvider(key)),
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

class SpecimenListTile extends StatelessWidget {
  const SpecimenListTile({
    required this.specimen,
    required this.onTap,
    this.selected = false,
    this.checked,
    this.onLongPress,
    super.key,
  });

  final Specimen specimen;
  final bool selected;
  final VoidCallback onTap;

  /// No modo de seleção, se está marcado (mostra a caixa); `null` = fora do
  /// modo.
  final bool? checked;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final form = specimen.formRef;
    final details = [
      if (form != null) form.displayName,
      if (specimen.isAlpha) '$alphaEmoji Alfa',
      if (specimen.pokeball != null) prettifyName(specimen.pokeball!),
    ];
    return ListTile(
      key: ValueKey('specimen-${specimen.id}'),
      selected: selected || (checked ?? false),
      leading: PokemonSprite(url: specimen.spriteUrl, size: 48),
      title: Row(
        spacing: 4,
        children: [
          Flexible(
            child: Text(specimen.displayName, overflow: TextOverflow.ellipsis),
          ),
          if (specimen.isShiny) const Text(shinyEmoji, semanticsLabel: 'Shiny'),
          if (specimen.isFromGo)
            const Text(goEmoji, semanticsLabel: 'Pokémon GO'),
        ],
      ),
      subtitle: Text(details.join(' · ')),
      trailing: switch (checked) {
        final bool value => Checkbox(value: value, onChanged: (_) => onTap()),
        null when specimen.isDeposited => const Tooltip(
          message: 'Depositado',
          child: Icon(Icons.inventory_2_outlined),
        ),
        null => null,
      },
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
