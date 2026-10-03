import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/search_field.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Busca uma forma pelo nome. Tela cheia no compacto, diálogo nos demais.
/// Retorna a forma escolhida, ou `null` se o usuário fechar.
Future<FormRef?> showFormPicker(BuildContext context) {
  const picker = FormPicker();
  return showDialog<FormRef>(
    context: context,
    builder: (context) => WindowSize.of(context).isCompact
        ? const Dialog.fullscreen(child: picker)
        : Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
              child: picker,
            ),
          ),
  );
}

class FormPicker extends ConsumerStatefulWidget {
  const FormPicker({super.key});

  /// Menos que isso traria formas demais para ajudar.
  static const minSearchLength = 2;

  @override
  ConsumerState<FormPicker> createState() => _FormPickerState();
}

class _FormPickerState extends ConsumerState<FormPicker> {
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Espera o usuário parar de digitar antes de consultar a API.
  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => setState(() => _search = text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(
          children: [
            const CloseButton(),
            Expanded(
              child: SearchField(
                autofocus: true,
                hintText: 'Buscar forma pelo nome',
                onChanged: _onChanged,
              ),
            ),
          ],
        ),
      ),
      Expanded(child: _results()),
    ],
  );

  Widget _results() {
    if (_search.length < FormPicker.minSearchLength) {
      return const EmptyView(message: 'Digite ao menos 2 letras do nome.');
    }
    return switch (ref.watch(formSearchProvider(_search))) {
      AsyncData(value: final forms) when forms.isEmpty => const EmptyView(
        message: 'Nenhuma forma encontrada.',
      ),
      AsyncData(value: final forms) => ListView.builder(
        itemCount: forms.length,
        itemBuilder: (context, i) => ListTile(
          key: ValueKey('form-${forms[i].id}'),
          leading: PokemonSprite(url: forms[i].spriteUrl, size: 40),
          title: Text(forms[i].displayName),
          subtitle: Text(forms[i].dexNumber),
          onTap: () => Navigator.of(context).pop(forms[i]),
        ),
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(formSearchProvider(_search)),
      ),
      _ => const LoadingView(),
    };
  }
}
