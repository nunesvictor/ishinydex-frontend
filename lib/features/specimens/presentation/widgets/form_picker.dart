import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/search_field.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Busca uma forma pelo nome. Tela cheia no compacto, diálogo nos demais.
/// Retorna a forma escolhida, ou `null` se o usuário fechar. Com [allow],
/// só as formas que ele aceita (as que existem num jogo, no team builder).
Future<FormRef?> showFormPicker(
  BuildContext context, {
  bool Function(FormRef form)? allow,
}) {
  final picker = FormPicker(allow: allow);
  return showDialog<FormRef>(
    context: context,
    builder: (context) => WindowSize.of(context).isCompact
        ? Dialog.fullscreen(child: picker)
        : Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
              child: picker,
            ),
          ),
  );
}

class FormPicker extends ConsumerStatefulWidget {
  const FormPicker({this.allow, super.key});

  final bool Function(FormRef form)? allow;

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

  /// Enter: busca na hora, sem esperar o debounce, e escolhe o primeiro
  /// resultado assim que ele chegar (#205), como a busca de slot no dex. Se
  /// a busca falhar ou não achar nada, a lista mostra o porquê.
  Future<void> _onSubmitted(String text) async {
    _debounce?.cancel();
    final search = text.trim();
    setState(() => _search = search);
    if (search.length < FormPicker.minSearchLength) return;
    final List<FormRef> forms;
    try {
      forms = _allowed(await ref.read(formSearchProvider(search).future));
    } on Exception {
      return;
    }
    // O texto pode ter mudado enquanto a busca corria.
    if (!mounted || _search != search || forms.isEmpty) return;
    Navigator.of(context).pop(forms.first);
  }

  List<FormRef> _allowed(List<FormRef> forms) => switch (widget.allow) {
    final allow? => [
      for (final form in forms)
        if (allow(form)) form,
    ],
    null => forms,
  };

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
                hintText: context.l10n.searchFormByName,
                onChanged: _onChanged,
                onSubmitted: _onSubmitted,
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
      return EmptyView(message: context.l10n.typeTwoLetters);
    }
    return switch (ref.watch(formSearchProvider(_search)).whenData(_allowed)) {
      AsyncData(value: final forms) when forms.isEmpty => EmptyView(
        message: context.l10n.noFormFound,
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
