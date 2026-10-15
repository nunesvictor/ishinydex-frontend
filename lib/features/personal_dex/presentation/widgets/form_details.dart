import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Tipos, habilidades e selos (shiny-lock, só distribuição) da forma
/// [formId], carregados de `GET /forms/{id}/`.
///
/// Carregamento e erro ficam contidos aqui: o resto do painel do slot (e
/// as ações) continua funcionando.
class FormDetails extends ConsumerWidget {
  const FormDetails({
    required this.formId,
    this.highlightAbility,
    this.types = true,
    this.abilities = true,
    super.key,
  });

  final int formId;

  /// O que mostrar: no detalhe compacto (#207), os tipos vão para o
  /// cabeçalho e as habilidades, para os campos.
  final bool types;
  final bool abilities;

  /// Habilidade do espécime depositado, destacada na lista (✓ e negrito).
  final String? highlightAbility;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(formDetailProvider(formId))) {
        AsyncData(:final value) => _Details(
          form: value,
          highlightAbility: highlightAbility,
          showTypes: types,
          showAbilities: abilities,
        ),
        AsyncError() => Column(
          children: [
            Text(
              context.l10n.formDetailsError,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => ref.invalidate(formDetailProvider(formId)),
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

class _Details extends StatelessWidget {
  const _Details({
    required this.form,
    required this.showTypes,
    required this.showAbilities,
    this.highlightAbility,
  });

  final FormDetail form;
  final String? highlightAbility;
  final bool showTypes;
  final bool showAbilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = [...form.types]..sort((a, b) => a.slot.compareTo(b.slot));
    final abilities = [...form.abilities]
      ..sort((a, b) => a.slot.compareTo(b.slot));
    final highlight = TextStyle(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
    );
    // Só uma das partes: alinhada à esquerda, como o resto do cabeçalho e
    // dos campos compactos.
    final alone = showTypes != showAbilities;
    return Column(
      spacing: 8,
      crossAxisAlignment: alone
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (showTypes)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: alone ? WrapAlignment.start : WrapAlignment.center,
            children: [
              // O ícone do tipo do HOME e o nome (#230).
              for (final t in types) TypeChip(t.type),
              if (form.isShinylocked)
                Chip(
                  avatar: Icon(Icons.lock, color: theme.colorScheme.error),
                  label: Text(context.l10n.shinyLockChip),
                  visualDensity: VisualDensity.compact,
                ),
              if (form.isDistroOnly)
                Chip(
                  avatar: const Icon(Icons.card_giftcard),
                  label: Text(context.l10n.distroOnlyChip),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        if (showAbilities && abilities.isNotEmpty)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: context.l10n.abilitiesLabel),
                for (final (i, a) in abilities.indexed) ...[
                  if (i > 0) const TextSpan(text: ' · '),
                  if (a.ability == highlightAbility)
                    TextSpan(
                      text: '✓ ${_abilityName(context, a)}',
                      style: highlight,
                    )
                  else
                    TextSpan(text: _abilityName(context, a)),
                ],
              ],
            ),
            style: theme.textTheme.bodySmall,
            textAlign: alone ? TextAlign.start : TextAlign.center,
          ),
      ],
    );
  }

  /// "Chlorophyll (oculta)" / "Chlorophyll (hidden)".
  static String _abilityName(BuildContext context, FormAbility a) => a.isHidden
      ? context.l10n.hiddenAbility(prettifyName(a.ability))
      : prettifyName(a.ability);
}
