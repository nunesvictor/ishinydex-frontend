import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/base_stats_chart.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/species_info.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

enum _Tab { summary, stats, species }

/// As abas dos detalhes (painel do slot e detalhe do espécime): o resumo
/// ([summary], "Espécime"), os status base em hexágono e os dados da
/// espécie. Com abas, a altura é a da maior delas, e não a soma de tudo.
class FormInfoTabs extends ConsumerStatefulWidget {
  const FormInfoTabs({
    required this.formId,
    required this.summary,
    this.summaryLabel = 'Espécime',
    this.dexId,
    this.onOpenSlot,
    this.nature,
    super.key,
  });

  final int formId;
  final Widget summary;

  /// "Forma" num slot faltante (não há espécime).
  final String summaryLabel;

  /// Ver [SpeciesInfo].
  final int? dexId;
  final ValueChanged<Slot>? onOpenSlot;

  /// Natureza do espécime (valor da API), para o hexágono dos status;
  /// `null` sem espécime.
  final String? nature;

  @override
  ConsumerState<FormInfoTabs> createState() => _FormInfoTabsState();
}

class _FormInfoTabsState extends ConsumerState<FormInfoTabs> {
  _Tab _tab = _Tab.summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      SegmentedButton<_Tab>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: _Tab.summary, label: Text(widget.summaryLabel)),
          const ButtonSegment(value: _Tab.stats, label: Text('Status')),
          const ButtonSegment(value: _Tab.species, label: Text('Espécie')),
        ],
        selected: {_tab},
        onSelectionChanged: (selected) =>
            setState(() => _tab = selected.single),
      ),
      switch (_tab) {
        _Tab.summary => widget.summary,
        _Tab.stats => _withForm(
          (form) => BaseStatsChart(stats: form.stats, nature: _nature()),
        ),
        _Tab.species => _withForm(
          (form) => SpeciesInfo(
            form: form,
            dexId: widget.dexId,
            onOpenSlot: widget.onOpenSlot,
          ),
        ),
      },
    ],
  );

  /// A natureza entre as opções da API (com os stats que ela muda).
  Choice? _nature() {
    final value = widget.nature;
    if (value == null) return null;
    final natures = ref.watch(specimenOptionsProvider).value?.nature;
    return natures?.where((n) => n.value == value).firstOrNull;
  }

  /// O detalhe da forma (`GET /forms/{id}/`), com carregamento e erro
  /// contidos na aba.
  Widget _withForm(Widget Function(FormDetail form) builder) =>
      switch (ref.watch(formDetailProvider(widget.formId))) {
        AsyncData(:final value) => builder(value),
        AsyncError() => Column(
          children: [
            Text(
              'Não foi possível carregar os detalhes da forma.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () =>
                  ref.invalidate(formDetailProvider(widget.formId)),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
        _ => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
      };
}
