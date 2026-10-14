import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_details.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_info_tabs.dart';

/// O corpo comum do detalhe do slot e do detalhe do espécime (inventário),
/// compacto como o resumo do HOME (#207): o cabeçalho em linha (sprite; o
/// [title], o `SpecimenHeadline` ou o nome; [subtitle], [caption], tipos e
/// os [chips] como etiquetas) e as abas ([FormInfoTabs]) com o resumo:
/// habilidades, os [fields] em duas colunas, o cartão de status e o
/// [footer].
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
    this.position,
    this.summaryLabel,
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

  /// No lugar do [caption]: a posição com as setas de navegação do slot.
  final Widget? position;

  /// A forma do detalhe; `null` se o espécime não tiver a forma carregada
  /// (sem abas: só os chips, os campos e o [footer]).
  final int? formId;

  /// Chave das abas: trocar de slot ou de espécime volta para o resumo.
  final Key tabsKey;
  final String? summaryLabel;

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
    // As etiquetas (situação, marca, idioma) ficam no cabeçalho, menores.
    final chipRow = chips.isEmpty
        ? null
        : ChipTheme(
            data: ChipTheme.of(context).copyWith(
              labelStyle: theme.textTheme.labelSmall,
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in chips)
                  Theme(
                    data: theme.copyWith(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: chip,
                  ),
              ],
            ),
          );
    final filled = [
      for (final (name, value) in fields)
        if (value != null && value.isNotEmpty) (name, value),
    ];
    final fieldGrid = filled.isEmpty ? null : FieldGrid(fields: filled);
    final formId = this.formId;
    // Cabeçalho em linha (#207), como no resumo do HOME: o sprite à
    // esquerda; o nome, os tipos e as etiquetas à direita.
    final header = Row(
      spacing: 14,
      children: [
        PokemonSprite(url: spriteUrl, size: 96, semanticLabel: semanticLabel),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              title,
              if (subtitle case final subtitle?)
                Text(subtitle, style: theme.textTheme.bodyMedium),
              if (caption case final caption?)
                Text(caption, style: theme.textTheme.bodySmall),
              if (formId != null) FormDetails(formId: formId, abilities: false),
              ?chipRow,
            ],
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        header,
        ?position,
        if (formId == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [?fieldGrid, ?footer],
          )
        else
          FormInfoTabs(
            key: tabsKey,
            formId: formId,
            summaryLabel: summaryLabel,
            header: FormDetails(
              formId: formId,
              highlightAbility: highlightAbility,
              types: false,
            ),
            fields: fieldGrid,
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

/// Os campos do espécime em duas colunas (#207): rótulo pequeno em cima e
/// o valor embaixo. A observação, texto livre, ocupa a largura toda, com
/// até 2 linhas e "ver mais".
class FieldGrid extends StatelessWidget {
  const FieldGrid({required this.fields, super.key});

  /// Campos já preenchidos (nome, valor).
  final List<(String, String)> fields;

  /// O campo de texto livre, em largura total.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String name, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value,
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final half = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 10,
          children: [
            for (final (name, value) in fields)
              if (name == context.l10n.fieldObservation)
                SizedBox(
                  width: constraints.maxWidth,
                  child: cell(name, _MoreText(value)),
                )
              else
                SizedBox(
                  width: half,
                  child: cell(
                    name,
                    Text(value, style: theme.textTheme.bodyMedium),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// Texto longo em até 2 linhas, com "ver mais" quando passa disso.
class _MoreText extends StatefulWidget {
  const _MoreText(this.text);

  final String text;

  @override
  State<_MoreText> createState() => _MoreTextState();
}

class _MoreTextState extends State<_MoreText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 2,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final long = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _open ? null : 2,
              overflow: _open ? null : TextOverflow.ellipsis,
            ),
            if (long)
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => setState(() => _open = !_open),
                child: Text(
                  _open ? context.l10n.seeLess : context.l10n.seeMore,
                ),
              ),
          ],
        );
      },
    );
  }
}
