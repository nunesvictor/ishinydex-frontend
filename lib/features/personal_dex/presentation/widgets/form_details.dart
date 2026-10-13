import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
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
              'Não foi possível carregar os detalhes da forma.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => ref.invalidate(formDetailProvider(formId)),
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
              for (final t in types)
                Chip(
                  avatar: t.spriteUrl == null
                      ? null
                      : PokemonSprite(url: t.spriteUrl, size: 20),
                  label: Text(typeLabel(t.type)),
                  backgroundColor: typeColor(t.type),
                  labelStyle: TextStyle(
                    color: typeOnColor(t.type),
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              if (form.isShinylocked)
                Chip(
                  avatar: Icon(Icons.lock, color: theme.colorScheme.error),
                  label: const Text('Shiny-lock'),
                  visualDensity: VisualDensity.compact,
                ),
              if (form.isDistroOnly)
                const Chip(
                  avatar: Icon(Icons.card_giftcard),
                  label: Text('Só distribuição'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        if (showAbilities && abilities.isNotEmpty)
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Habilidades: '),
                for (final (i, a) in abilities.indexed) ...[
                  if (i > 0) const TextSpan(text: ' · '),
                  if (a.ability == highlightAbility)
                    TextSpan(text: '✓ ${_abilityName(a)}', style: highlight)
                  else
                    TextSpan(text: _abilityName(a)),
                ],
              ],
            ),
            style: theme.textTheme.bodySmall,
            textAlign: alone ? TextAlign.start : TextAlign.center,
          ),
      ],
    );
  }

  static String _abilityName(FormAbility a) =>
      '${prettifyName(a.ability)}${a.isHidden ? ' (oculta)' : ''}';
}
