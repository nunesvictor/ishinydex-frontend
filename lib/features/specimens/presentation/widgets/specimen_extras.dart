import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
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
    ('Treinador original', ot?.label),
    (
      'Data de captura',
      capturedAt == null
          ? null
          : MaterialLocalizations.of(context).formatCompactDate(capturedAt),
    ),
    ('Observação', specimen.observation),
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
Widget? languageTag(WidgetRef ref, String? language) {
  if (language == null) return null;
  final name = choiceLabel(
    ref.watch(specimenOptionsProvider).value?.language,
    language,
  );
  final code = _languageCodes[language] ?? language.toUpperCase();
  return Tooltip(
    message: 'Idioma: $name',
    excludeFromSemantics: true,
    child: Semantics(
      label: 'Idioma: $name',
      excludeSemantics: true,
      child: Chip(label: Text(code)),
    ),
  );
}

/// Chip "Visitando o Champions" (#174).
class ChampionsChip extends StatelessWidget {
  const ChampionsChip({super.key});

  @override
  Widget build(BuildContext context) => const Chip(
    avatar: ChampionsIcon(size: 18),
    label: Text('Visitando o Champions'),
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
      HuntRecordCard(hunt: hunt, capturedAt: specimen!.capturedAt),
    ?trailing,
  ];
  if (children.isEmpty) return null;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}
