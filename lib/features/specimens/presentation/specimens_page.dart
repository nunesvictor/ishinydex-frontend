import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_detail.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Inventário: todos os specimens, com busca e filtros.
///
/// - compacto: lista; tocar abre o detalhe em tela própria
/// - médio/expandido: lista | detalhe do specimen selecionado
class SpecimensPage extends ConsumerStatefulWidget {
  const SpecimensPage({super.key});

  @override
  ConsumerState<SpecimensPage> createState() => _SpecimensPageState();
}

class _SpecimensPageState extends ConsumerState<SpecimensPage> {
  SpecimenQuery _query = emptySpecimenQuery;
  int? _selectedId;
  Timer? _debounce;

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
      () => setState(() => _query = _query.copyWith(search: text.trim())),
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
          onChanged: (query) => setState(() => _query = query),
        ),
        Expanded(
          child: SpecimenList(
            query: _query,
            selectedId: size.isCompact ? null : _selectedId,
            onTap: (specimen) => size.isCompact
                ? context.go(Routes.specimen(specimen.id))
                : setState(() => _selectedId = specimen.id),
          ),
        ),
      ],
    );
    final selected = _selectedId;
    return Scaffold(
      appBar: AppBar(title: const Text('Espécimes')),
      floatingActionButton: FloatingActionButton.extended(
        // As abas ficam vivas juntas: cada botão precisa da sua hero tag.
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

class _Filters extends StatelessWidget {
  const _Filters({
    required this.query,
    required this.onSearchChanged,
    required this.onChanged,
  });

  final SpecimenQuery query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SpecimenQuery> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar por apelido ou forma',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: onSearchChanged,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
              onSelectionChanged: (s) =>
                  onChanged(query.copyWith(status: s.single)),
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
          ],
        ),
      ],
    ),
  );
}

/// Lista paginada: o total vem da 1ª página e cada item observa só a página
/// em que está, carregada quando aparece na tela.
class SpecimenList extends ConsumerWidget {
  const SpecimenList({
    required this.query,
    required this.onTap,
    this.selectedId,
    super.key,
  });

  final SpecimenQuery query;
  final int? selectedId;
  final ValueChanged<Specimen> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstPage = specimenPageProvider((query: query, page: 1));
    return switch (ref.watch(firstPage)) {
      AsyncData(value: final page) when page.count == 0 => const EmptyView(
        message: 'Nenhum espécime encontrado.',
      ),
      AsyncData(value: final page) => RefreshIndicator.adaptive(
        onRefresh: () {
          ref.invalidate(specimenPageProvider);
          return ref.read(firstPage.future);
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 88), // espaço do botão +
          itemCount: page.count,
          itemBuilder: (context, i) => _SpecimenItem(
            query: query,
            index: i,
            selectedId: selectedId,
            onTap: onTap,
          ),
        ),
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(firstPage),
      ),
      _ => const LoadingView(),
    };
  }
}

class _SpecimenItem extends ConsumerWidget {
  const _SpecimenItem({
    required this.query,
    required this.index,
    required this.selectedId,
    required this.onTap,
  });

  final SpecimenQuery query;
  final int index;
  final int? selectedId;
  final ValueChanged<Specimen> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (query: query, page: index ~/ specimenPageSize + 1);
    final offset = index % specimenPageSize;
    return switch (ref.watch(specimenPageProvider(key))) {
      AsyncData(value: final page) when offset < page.results.length =>
        SpecimenListTile(
          specimen: page.results[offset],
          selected: page.results[offset].id == selectedId,
          onTap: () => onTap(page.results[offset]),
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
    super.key,
  });

  final Specimen specimen;
  final bool selected;
  final VoidCallback onTap;

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
      selected: selected,
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
      trailing: specimen.isDeposited
          ? const Tooltip(
              message: 'Depositado',
              child: Icon(Icons.inventory_2_outlined),
            )
          : null,
      onTap: onTap,
    );
  }
}
