import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_info_tabs.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// A ficha de uma forma, só leitura, num bottom sheet: aberta pela aba
/// Espécie fora de um dex (no inventário não há slot para onde ir). Tocar em
/// outra forma da linha troca a ficha, sem empilhar outro sheet.
Future<void> showFormSheet(BuildContext context, FormRef form) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: FormSheet(form: form),
      ),
    );

class FormSheet extends ConsumerStatefulWidget {
  const FormSheet({required this.form, super.key});

  final FormRef form;

  @override
  ConsumerState<FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends ConsumerState<FormSheet> {
  late FormRef _form = widget.form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = _form;
    final types = [...?ref.watch(formDetailProvider(form.id)).value?.types]
      ..sort((a, b) => a.slot.compareTo(b.slot));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PokemonSprite(
              url: form.spriteUrl,
              size: 112,
              semanticLabel: form.displayName,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            form.displayName,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          Text(
            [
              form.dexNumber,
              ...types.map((t) => typeLabel(t.type)),
              'só leitura',
            ].join(' · '),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // A mesma chave para todas as formas: trocar de forma mantém a aba
          // (quem navega pela linha continua na Espécie).
          FormInfoTabs(
            formId: form.id,
            summaryLabel: 'Forma',
            onOpenForm: (other) => setState(() => _form = other),
          ),
        ],
      ),
    );
  }
}
