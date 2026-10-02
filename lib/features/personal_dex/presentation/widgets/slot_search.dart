import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

/// Duração e curva das animações da busca (campo, AppBar e botões).
const searchAnimationDuration = Duration(milliseconds: 300);
const Curve searchAnimationCurve = Curves.easeOutCubic;

/// Dica do campo enquanto se digita.
const _searchHint = 'Nome ou número';

/// Busca do dex: em repouso, uma pílula "Buscar" logo abaixo da grade;
/// ativa (com foco ou texto), a barra de busca do topo.
///
/// É o próprio campo, e não um botão que abre outro: o Safari do iOS só abre
/// o teclado quando o foco nasce de um toque no campo.
///
/// Quem posiciona e anima a posição e o tamanho é a página; aqui fica só a
/// aparência. O fundo e a borda são de um `AnimatedContainer` (e não do
/// `InputDecorator`) para acompanharem a altura enquanto ela anima.
class SlotSearchPill extends StatelessWidget {
  const SlotSearchPill({
    required this.controller,
    required this.focusNode,
    required this.active,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool active;
  final ValueChanged<String> onChanged;

  /// O "x" do campo: apaga o texto, mas a busca continua aberta.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: searchAnimationDuration,
      curve: searchAnimationCurve,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(active ? 28 : 22),
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
          width: active ? 2 : 1,
        ),
        // Em repouso, a pílula flutua sobre a tela.
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: active ? 0 : 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: active ? _searchHint : 'Buscar',
            prefixIcon: const Icon(Icons.search),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 24,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : _ClearButton(onPressed: onClear),
          ),
          onChanged: onChanged,
          // "Buscar" no teclado só o fecha: os resultados ficam.
          onSubmitted: (_) => focusNode.unfocus(),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Limpar busca',
    onPressed: onPressed,
    icon: const Icon(Icons.clear),
  );
}

/// Resultados da busca por [search] (nome ou número) no dex [dexId]. Quem
/// usa faz o debounce: [search] só muda quando o usuário para de digitar.
class SlotSearchResults extends ConsumerWidget {
  const SlotSearchResults({
    required this.dexId,
    required this.search,
    required this.onSelected,
    super.key,
  });

  final int dexId;
  final String search;
  final ValueChanged<Slot> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Um número basta ("6"); por nome, 2 letras evitam listas enormes.
    final ready = int.tryParse(search) != null || search.characters.length >= 2;
    if (!ready) {
      return const EmptyView(
        message: 'Digite o nome (2 letras ou mais) ou o número.',
      );
    }
    final key = (dexId: dexId, search: search);
    return switch (ref.watch(slotSearchProvider(key))) {
      AsyncData(value: final slots) when slots.isEmpty => const EmptyView(
        message: 'Nenhuma forma deste dex encontrada.',
      ),
      AsyncData(value: final slots) => ListView.builder(
        itemCount: slots.length,
        itemBuilder: (context, i) =>
            _SlotResult(slot: slots[i], onTap: () => onSelected(slots[i])),
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
  const _SlotResult({required this.slot, required this.onTap});

  final Slot slot;
  final VoidCallback onTap;

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
      onTap: onTap,
    );
  }
}
