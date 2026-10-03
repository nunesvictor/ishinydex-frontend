import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Abre os filtros de escopo das caçadas (categoria, geração, tipo, shiny
/// impossível): bottom sheet no compacto, diálogo nos demais. Retorna a
/// consulta nova ao aplicar, ou `null` se o usuário fechou sem aplicar.
Future<HuntQuery?> showHuntFilters(BuildContext context, HuntQuery query) {
  final panel = HuntFiltersPanel(initial: query);
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
  const HuntFiltersPanel({required this.initial, super.key});

  final HuntQuery initial;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Filtros', style: theme.textTheme.titleLarge),
              ),
              TextButton(
                onPressed: _draft.scopeCount == 0
                    ? null
                    : () => _update(_draft.clearScope()),
                child: const Text('Limpar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _Section(
                title: 'Categoria',
                children: [
                  for (final category in SpeciesCategory.values)
                    FilterChip(
                      label: Text(category.label),
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
                title: 'Geração',
                children: [
                  for (final generation in options.generation)
                    FilterChip(
                      label: Text(generationNumber(generation.value)),
                      tooltip: generation.label,
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
                title: 'Tipo (qualquer um)',
                children: [
                  for (final type in options.type)
                    FilterChip(
                      avatar: type.spriteUrl == null
                          ? null
                          : PokemonSprite(url: type.spriteUrl, size: 18),
                      label: Text(type.label),
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
                title: const Text('Incluir shiny impossível'),
                subtitle: const Text('Formas com shiny lock sem distribuição'),
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
            child: const Text('Mostrar resultados'),
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
          summarize([for (final c in q.categories) c.label])!,
          q.copyWith(categories: const []),
        ),
      if (q.generations.isNotEmpty)
        (
          'Geração ${q.generations.map(generationNumber).join(', ')}',
          q.copyWith(generations: const []),
        ),
      if (q.types.isNotEmpty)
        (
          labelsOf(q.types, options.type).join(' ou '),
          q.copyWith(types: const []),
        ),
      if (q.includeLocked)
        ('Com shiny impossível', q.copyWith(includeLocked: false)),
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
              deleteButtonTooltipMessage: 'Remover filtro',
              onDeleted: () => onChanged(cleared),
            ),
        ],
      ),
    );
  }
}
