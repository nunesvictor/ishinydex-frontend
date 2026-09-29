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
  const FormDetails({required this.formId, super.key});

  final int formId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(formDetailProvider(formId))) {
        AsyncData(:final value) => _Details(form: value),
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
  const _Details({required this.form});

  final FormDetail form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = [...form.types]..sort((a, b) => a.slot.compareTo(b.slot));
    final abilities = [
      for (final a in [
        ...form.abilities,
      ]..sort((a, b) => a.slot.compareTo(b.slot)))
        '${prettifyName(a.ability)}${a.isHidden ? ' (oculta)' : ''}',
    ];
    return Column(
      spacing: 8,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
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
        if (abilities.isNotEmpty)
          Text(
            'Habilidades: ${abilities.join(' · ')}',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
