import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/home_tag.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_record_card.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

// O que o detalhe mostra de um espécime cadastrado, além do cabeçalho e das
// abas do `DetailBody`. Fica num lugar só para o detalhe do slot e o do
// inventário mostrarem as mesmas coisas (#195): um dado novo do espécime
// entra aqui e aparece nas duas telas.

/// Os campos do espécime: treinador original, data de captura e
/// observação. Habilidade, natureza e gênero já aparecem no corpo (lista da
/// forma, cartão de status e cabeçalho), e o idioma é uma etiqueta no
/// cabeçalho ([languageTag]).
List<(String, String?)> specimenFields(
  BuildContext context,
  WidgetRef ref,
  Specimen specimen,
) {
  final trainers = ref.watch(trainersProvider).value;
  final ot = trainers?.where((t) => t.id == specimen.ot).firstOrNull;
  final capturedAt = specimen.capturedAt;
  return [
    (context.l10n.originalTrainer, ot?.label),
    (
      context.l10n.captureDate,
      capturedAt == null
          ? null
          : MaterialLocalizations.of(context).formatCompactDate(capturedAt),
    ),
    (context.l10n.fieldObservation, specimen.observation),
  ];
}

/// As siglas de idioma do HOME (ENG, JPN...); os outros, em maiúsculas.
const _languageCodes = {
  'ja': 'JPN',
  'ja-hrkt': 'JPN',
  'ja-roma': 'JPN',
  'en': 'ENG',
  'fr': 'FRE',
  'it': 'ITA',
  'de': 'GER',
  'es': 'SPA',
  'es-419': 'SP-LA',
  'ko': 'KOR',
  'zh-hans': 'CHS',
  'zh-hant': 'CHT',
};

/// A etiqueta de idioma do cabeçalho (#207), como no HOME: "ENG", com o
/// nome completo no toque e no leitor de tela. `null` sem idioma.
Widget? languageTag(BuildContext context, WidgetRef ref, String? language) {
  if (language == null) return null;
  final name = context.l10n.choiceOf(
    ref.watch(specimenOptionsProvider).value?.language,
    language,
  )!;
  final code = _languageCodes[language] ?? language.toUpperCase();
  return Tooltip(
    message: context.l10n.languageValue(name),
    excludeFromSemantics: true,
    child: Semantics(
      label: context.l10n.languageValue(name),
      excludeSemantics: true,
      child: Chip(label: Text(code)),
    ),
  );
}

/// A etiqueta do corte do HOME (#222) no cabeçalho, para o espécime num
/// save cujo jogo deixa (ou deixou) de chegar ao HOME. `null` nos outros.
Widget? homeTagOf(WidgetRef ref, Save? location) =>
    switch (ref.watch(homeCutoffProvider)(location?.trainer.version)) {
      final cutoff? => HomeTag(cutoff),
      null => null,
    };

/// Chip "Visitando o Champions" (#174).
class ChampionsChip extends StatelessWidget {
  const ChampionsChip({super.key});

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const ChampionsIcon(size: 18),
    label: Text(context.l10n.visitingChampionsLabel),
  );
}

/// O rodapé do detalhe: onde o espécime está ([save], desde [since]), a
/// visita ao Champions e o registro da caçada, com [trailing] por último.
/// `null` quando não há nada a mostrar.
///
/// [save] vem à parte porque o slot já o tem no resumo; o resto vem do
/// [specimen] completo, que o slot carrega depois (`null` enquanto isso).
Widget? specimenFooter({
  required Save? save,
  DateTime? since,
  Specimen? specimen,
  Widget? trailing,
}) {
  final champions = specimen?.championsSince;
  final hunt = specimen?.hunt;
  final children = [
    if (save != null) LocationTile(save: save, since: since),
    if (champions != null) ChampionsTile(since: champions),
    if (hunt != null)
      HuntRecordCard(
        hunt: hunt,
        capturedAt: specimen!.capturedAt,
        specimen: specimen,
      ),
    ?trailing,
  ];
  if (children.isEmpty) return null;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}
