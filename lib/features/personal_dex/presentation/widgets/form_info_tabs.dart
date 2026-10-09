import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/base_stats_chart.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/species_info.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

enum _Tab { summary, species }

/// As abas dos detalhes (slot, espécime e ficha da forma): o resumo
/// ("Espécime", ou "Forma" sem espécime) e os dados da espécie. Com abas, a
/// altura é a da maior delas, e não a soma de tudo.
///
/// O resumo junta o que era a aba Status, como na tela de resumo dos jogos:
/// [header] (tipos, habilidades e chips), o cartão "Status base" com o
/// hexágono (e a [nature], se houver), os [fields] e o [footer]. Em telas
/// largas, o cartão vai para a direita dos campos.
class FormInfoTabs extends ConsumerStatefulWidget {
  const FormInfoTabs({
    required this.formId,
    this.summaryLabel = 'Espécime',
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
  final String summaryLabel;

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

  /// Largura a partir da qual o cartão de status fica ao lado dos campos.
  static const sideBySideMinWidth = 640.0;

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
          const ButtonSegment(value: _Tab.species, label: Text('Espécie')),
        ],
        selected: {_tab},
        onSelectionChanged: (selected) =>
            setState(() => _tab = selected.single),
      ),
      switch (_tab) {
        _Tab.summary => _summary(),
        _Tab.species => _withForm(
          (form) => SpeciesInfo(
            form: form,
            dexId: widget.dexId,
            onOpenSlot: widget.onOpenSlot,
            onOpenForm: widget.onOpenForm,
          ),
        ),
      },
    ],
  );

  Widget _summary() {
    final card = _withForm(
      (form) => StatsCard(stats: form.stats, nature: _nature()),
    );
    final fields = widget.fields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        ?widget.header,
        if (fields == null)
          card
        else
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth < FormInfoTabs.sideBySideMinWidth
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [card, fields],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      Expanded(child: fields),
                      SizedBox(width: StatsCard.width, child: card),
                    ],
                  ),
          ),
        ?widget.footer,
      ],
    );
  }

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

/// O cartão "Status base": o hexágono, a natureza (se houver), o total e o
/// EV que o Pokémon dá.
class StatsCard extends StatelessWidget {
  const StatsCard({required this.stats, this.nature, super.key});

  final List<FormStat> stats;
  final Choice? nature;

  /// Largura do cartão ao lado dos campos (cabe o hexágono de 300 px).
  static const width = 332.0;

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
            Text('Status base', style: theme.textTheme.titleSmall),
            BaseStatsChart(stats: stats, nature: nature),
          ],
        ),
      ),
    );
  }
}
