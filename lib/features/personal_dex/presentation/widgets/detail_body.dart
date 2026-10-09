import 'package:flutter/material.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_details.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_info_tabs.dart';

/// O corpo comum do detalhe do slot e do detalhe do espécime (inventário):
/// sprite, [title] (o nome, ou o `SpecimenHeadline`), as linhas de
/// [subtitle] e [caption] e as abas ([FormInfoTabs]) com o resumo: tipos e
/// habilidades, os [chips], o cartão de status, os [fields] e o [footer].
///
/// O que muda entre as duas telas vem por parâmetro: a posição na caixa (o
/// [caption], só no slot), os chips de situação, os campos (só no
/// inventário) e a navegação da aba Espécie ([dexId] + [onOpenSlot] no dex,
/// [onOpenForm] fora dele). As ações ficam com cada tela.
class DetailBody extends StatelessWidget {
  const DetailBody({
    required this.spriteUrl,
    required this.semanticLabel,
    required this.title,
    required this.formId,
    required this.tabsKey,
    this.subtitle,
    this.caption,
    this.summaryLabel = 'Espécime',
    this.highlightAbility,
    this.chips = const [],
    this.fields = const [],
    this.footer,
    this.nature,
    this.dexId,
    this.onOpenSlot,
    this.onOpenForm,
    super.key,
  });

  final String? spriteUrl;
  final String semanticLabel;
  final Widget title;
  final String? subtitle;
  final String? caption;

  /// A forma do detalhe; `null` se o espécime não tiver a forma carregada
  /// (sem abas: só os chips, os campos e o [footer]).
  final int? formId;

  /// Chave das abas: trocar de slot ou de espécime volta para o resumo.
  final Key tabsKey;
  final String summaryLabel;

  /// Habilidade do espécime, destacada na lista da forma.
  final String? highlightAbility;
  final List<Widget> chips;

  /// Campos do espécime (nome, valor); os vazios não aparecem.
  final List<(String, String?)> fields;
  final Widget? footer;

  /// Ver [FormInfoTabs].
  final String? nature;
  final int? dexId;
  final ValueChanged<Slot>? onOpenSlot;
  final ValueChanged<FormRef>? onOpenForm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipRow = chips.isEmpty
        ? null
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: chips,
          );
    final filled = [
      for (final (name, value) in fields)
        if (value != null && value.isNotEmpty) (name, value),
    ];
    final fieldList = filled.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (name, value) in filled)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  subtitle: Text(value),
                ),
            ],
          );
    final formId = this.formId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: PokemonSprite(
            url: spriteUrl,
            size: 112,
            semanticLabel: semanticLabel,
          ),
        ),
        const SizedBox(height: 8),
        title,
        if (subtitle case final subtitle?)
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        if (caption case final caption?)
          Text(
            caption,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 12),
        if (formId == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [?chipRow, ?fieldList, ?footer],
          )
        else
          FormInfoTabs(
            key: tabsKey,
            formId: formId,
            summaryLabel: summaryLabel,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                FormDetails(formId: formId, highlightAbility: highlightAbility),
                ?chipRow,
              ],
            ),
            fields: fieldList,
            footer: footer,
            nature: nature,
            dexId: dexId,
            onOpenSlot: onOpenSlot,
            onOpenForm: onOpenForm,
          ),
      ],
    );
  }
}
