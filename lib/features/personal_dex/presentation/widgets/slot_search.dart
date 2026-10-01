import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

/// Busca uma forma no dex [dexId] pelo nome ou número. Tela cheia no
/// compacto, diálogo nos demais. Retorna o slot escolhido, ou `null`.
Future<Slot?> showSlotSearch(BuildContext context, {required int dexId}) {
  final search = SlotSearch(dexId: dexId);
  return showDialog<Slot>(
    context: context,
    builder: (context) => WindowSize.of(context).isCompact
        ? Dialog.fullscreen(child: search)
        : Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
              child: search,
            ),
          ),
  );
}

class SlotSearch extends ConsumerStatefulWidget {
  const SlotSearch({required this.dexId, super.key});

  final int dexId;

  @override
  ConsumerState<SlotSearch> createState() => _SlotSearchState();
}

class _SlotSearchState extends ConsumerState<SlotSearch> {
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
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Nome ou número',
                  prefixIcon: Icon(Icons.search),
                ),
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
    // Um número basta ("6"); por nome, 2 letras evitam listas enormes.
    final ready =
        int.tryParse(_search) != null || _search.characters.length >= 2;
    if (!ready) {
      return const EmptyView(
        message: 'Digite o nome (2 letras ou mais) ou o número.',
      );
    }
    final key = (dexId: widget.dexId, search: _search);
    return switch (ref.watch(slotSearchProvider(key))) {
      AsyncData(value: final slots) when slots.isEmpty => const EmptyView(
        message: 'Nenhuma forma deste dex encontrada.',
      ),
      AsyncData(value: final slots) => ListView.builder(
        itemCount: slots.length,
        itemBuilder: (context, i) => _SlotResult(slot: slots[i]),
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(slotSearchProvider(key)),
      ),
      _ => const LoadingView(),
    };
  }
}

class _SlotResult extends StatelessWidget {
  const _SlotResult({required this.slot});

  final Slot slot;

  @override
  Widget build(BuildContext context) {
    // A busca só devolve slots com forma.
    final form = slot.form!;
    return ListTile(
      key: ValueKey('search-slot-${slot.id}'),
      leading: PokemonSprite(url: slot.spriteUrl, size: 40),
      title: Text(form.displayName),
      subtitle: Text(
        '${form.dexNumber} · ${slot.box.name} · '
        'linha ${slot.row + 1}, coluna ${slot.col + 1}',
      ),
      trailing: slot.isRegistered
          ? const Tooltip(
              message: 'Registrado',
              child: Icon(Icons.check_circle, color: Colors.green),
            )
          : const Tooltip(
              message: 'Faltante',
              child: Icon(Icons.radio_button_unchecked),
            ),
      onTap: () => Navigator.of(context).pop(slot),
    );
  }
}
