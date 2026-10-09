import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
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
    required this.onSubmitted,
    required this.onMove,
    required this.onEscape,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool active;
  final ValueChanged<String> onChanged;

  /// O "x" do campo: apaga o texto, mas a busca continua aberta.
  final VoidCallback onClear;

  /// Enter (ou "Buscar" no teclado do celular): abre o resultado destacado.
  final VoidCallback onSubmitted;

  /// ↑ (-1) e ↓ (+1): movem o destaque sem tirar o foco do campo.
  final ValueChanged<int> onMove;

  /// Esc: cancela a busca.
  final VoidCallback onEscape;

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
      // As setas e o Esc chegam aqui antes dos atalhos do campo de texto
      // (que levariam o cursor ao começo ou ao fim do texto): o atalho mais
      // perto do foco ganha.
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => onMove(-1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => onMove(1),
          const SingleActivator(LogicalKeyboardKey.escape): onEscape,
        },
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
            onSubmitted: (_) => onSubmitted(),
          ),
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

/// A busca está pronta para consultar? Um número basta ("6"); por nome, 2
/// letras evitam listas enormes.
bool slotSearchReady(String search) =>
    int.tryParse(search) != null || search.characters.length >= 2;

/// Resultados da busca por [search] (nome ou número) no dex [dexId]. Quem
/// usa faz o debounce: [search] só muda quando o usuário para de digitar.
///
/// O resultado [highlighted] fica destacado: é o que o Enter abre. Passar o
/// mouse por cima de outro chama [onHighlight]. Com [onReady], a lista o
/// chama com o destacado assim que chegar (o Enter veio antes dela).
class SlotSearchResults extends ConsumerWidget {
  const SlotSearchResults({
    required this.dexId,
    required this.search,
    required this.onSelected,
    this.highlighted = 0,
    this.onHighlight,
    this.onReady,
    super.key,
  });

  final int dexId;
  final String search;
  final ValueChanged<Slot> onSelected;
  final int highlighted;
  final ValueChanged<int>? onHighlight;
  final ValueChanged<Slot>? onReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!slotSearchReady(search)) {
      return const EmptyView(
        message: 'Digite o nome (2 letras ou mais) ou o número.',
      );
    }
    final key = (dexId: dexId, search: search);
    return switch (ref.watch(slotSearchProvider(key))) {
      AsyncData(value: final slots) when slots.isEmpty => const EmptyView(
        message: 'Nenhuma forma deste dex encontrada.',
      ),
      AsyncData(value: final slots) => _results(context, slots),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(slotSearchProvider(key)),
      ),
      _ => const LoadingView(),
    };
  }

  Widget _results(BuildContext context, List<Slot> slots) {
    // No PC, a dica é a tecla (e uma linha com os atalhos); no celular, o
    // nome da tecla do teclado do sistema.
    final desktop = isDesktopPlatform(Theme.of(context).platform);
    final current = highlighted.clamp(0, slots.length - 1);
    final ready = onReady;
    // Depois do quadro: abrir muda a tela, o que não pode acontecer no meio
    // de um build.
    if (ready != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ready(slots[current]),
      );
    }
    final list = ListView.builder(
      itemCount: slots.length,
      itemBuilder: (context, i) => _SlotResult(
        slot: slots[i],
        highlighted: i == current,
        desktop: desktop,
        onTap: () => onSelected(slots[i]),
        onHover: onHighlight == null ? null : () => onHighlight!(i),
      ),
    );
    if (!desktop) return list;
    return Column(
      children: [
        Expanded(child: list),
        const Padding(padding: EdgeInsets.all(12), child: _KeyHints()),
      ],
    );
  }
}

class _SlotResult extends StatelessWidget {
  const _SlotResult({
    required this.slot,
    required this.highlighted,
    required this.desktop,
    required this.onTap,
    this.onHover,
  });

  final Slot slot;
  final bool highlighted;
  final bool desktop;
  final VoidCallback onTap;
  final VoidCallback? onHover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A busca só devolve slots com forma.
    final form = slot.form!;
    return MouseRegion(
      onEnter: onHover == null ? null : (_) => onHover!(),
      child: ListTile(
        key: ValueKey('search-slot-${slot.id}'),
        selected: highlighted,
        selectedTileColor: scheme.secondaryContainer,
        selectedColor: scheme.onSecondaryContainer,
        leading: PokemonSprite(url: slot.spriteUrl, size: 40),
        title: Text(form.displayName),
        subtitle: Text(
          '${form.dexNumber} · ${slot.box.name} · '
          'linha ${slot.row + 1}, coluna ${slot.col + 1} · '
          '${slot.isRegistered ? 'registrado' : 'faltante'}',
        ),
        trailing: !highlighted
            ? null
            : desktop
            ? const _Key('Enter')
            : _Tag(text: 'Buscar abre', scheme: scheme),
        onTap: onTap,
      ),
    );
  }
}

/// Etiqueta do resultado destacado no celular: a tecla "Buscar" abre.
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.scheme});

  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: scheme.onPrimaryContainer),
      ),
    ),
  );
}

/// Uma tecla, como o `<kbd>` do HTML.
class _Key extends StatelessWidget {
  const _Key(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

/// Linha de atalhos embaixo da lista (só no PC).
class _KeyHints extends StatelessWidget {
  const _KeyHints();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget hint(List<String> keys, String action) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        for (final key in keys) _Key(key),
        Text(action, style: style),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        hint(['↑', '↓'], 'escolher'),
        hint(['Enter'], 'abrir'),
        hint(['Esc'], 'cancelar'),
      ],
    );
  }
}
