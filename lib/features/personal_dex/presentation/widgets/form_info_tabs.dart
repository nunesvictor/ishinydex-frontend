import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/base_stats_chart.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/species_info.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/type_matchups.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

enum _Tab { summary, species }

/// As abas dos detalhes (slot, espécime e ficha da forma): o resumo
/// ("Espécime", ou "Forma" sem espécime) e os dados da espécie. Com abas, a
/// altura é a da maior delas, e não a soma de tudo.
///
/// O resumo junta o que era a aba Status, como na tela de resumo dos jogos:
/// [header] (tipos, habilidades e chips), o cartão "Status base" com o
/// hexágono compacto (e a [nature], se houver), os [fields] e o [footer].
class FormInfoTabs extends ConsumerStatefulWidget {
  const FormInfoTabs({
    required this.formId,
    this.summaryLabel,
    this.header,
    this.fields,
    this.footer,
    this.nature,
    this.dexId,
    this.onOpenSlot,
    this.onOpenForm,
    super.key,
  });

  final int formId;

  /// "Forma" num slot faltante ou na ficha da forma (não há espécime).
  final String? summaryLabel;

  /// Partes do resumo (ver a classe); todas opcionais.
  final Widget? header;
  final Widget? fields;
  final Widget? footer;

  /// Natureza do espécime (valor da API), para o hexágono dos status;
  /// `null` sem espécime.
  final String? nature;

  /// Ver [SpeciesInfo].
  final int? dexId;
  final ValueChanged<Slot>? onOpenSlot;
  final ValueChanged<FormRef>? onOpenForm;

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
          ButtonSegment(
            value: _Tab.summary,
            label: Text(widget.summaryLabel ?? context.l10n.summarySpecimen),
          ),
          ButtonSegment(
            value: _Tab.species,
            label: Text(context.l10n.tabSpecies),
          ),
        ],
        selected: {_tab},
        onSelectionChanged: (selected) =>
            setState(() => _tab = selected.single),
      ),
      switch (_tab) {
        _Tab.summary => _summary(),
        _Tab.species => _withForm(
          (form) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              SpeciesInfo(
                form: form,
                dexId: widget.dexId,
                onOpenSlot: widget.onOpenSlot,
                onOpenForm: widget.onOpenForm,
              ),
              // Forças e fraquezas pelos tipos da forma (#230), por último:
              // a linha evolutiva fica no topo da aba (#270). Ficam aqui, e
              // não no Resumo, para o detalhe do espécime continuar cabendo
              // sem rolar no iPhone (#207).
              TypeMatchupsCard(
                types: [
                  for (final t in [
                    ...form.types,
                  ]..sort((a, b) => a.slot.compareTo(b.slot)))
                    t.type,
                ],
              ),
            ],
          ),
        ),
      },
    ],
  );

  Widget _summary() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      ?widget.header,
      ?widget.fields,
      _withForm((form) => StatsCard(stats: form.stats, nature: _nature())),
      ?widget.footer,
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
              context.l10n.formDetailsError,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () =>
                  ref.invalidate(formDetailProvider(widget.formId)),
              child: Text(context.l10n.tryAgain),
            ),
          ],
        ),
        _ => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
      };
}

/// O cartão "Status base": o hexágono, a natureza (se houver), o total e o
/// EV que o Pokémon dá.
class StatsCard extends StatelessWidget {
  const StatsCard({required this.stats, this.nature, super.key});

  final List<FormStat> stats;
  final Choice? nature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Text(context.l10n.baseStats, style: theme.textTheme.titleSmall),
            BaseStatsChart(stats: stats, nature: nature, compact: true),
          ],
        ),
      ),
    );
  }
}
