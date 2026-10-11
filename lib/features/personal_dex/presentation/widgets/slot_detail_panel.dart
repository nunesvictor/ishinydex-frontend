import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/action_sheet.dart';
import 'package:ishinydex/core/widgets/origin_mark_chip.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/detail_body.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_navigation.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/active_hunt_tile.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_headline.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Detalhes do slot selecionado.
///
/// Em cima, rolando, o corpo comum ([DetailBody]: cabeçalho e as abas
/// Espécime e Espécie);
/// embaixo, fixa, a barra com a ação principal (Depositar num slot
/// faltante; Editar num registrado) e "Mais ações": enviar para jogo ou
/// trazer de volta, retirar do slot e libertar.
///
/// O slot traz só o resumo do specimen (`SpecimenSummary`); gênero,
/// natureza e Pokémon GO vêm do specimen completo (`GET /specimens/{id}/`),
/// carregado à parte. Enquanto ele não chega (ou se falhar), o painel mostra
/// o resumo e as ações normalmente.
class SlotDetailPanel extends ConsumerWidget {
  const SlotDetailPanel({
    required this.slot,
    required this.onDeposit,
    required this.onEdit,
    required this.onRelease,
    required this.onWithdraw,
    this.onOpenSlot,
    this.onShowHunts,
    this.navigation,
    this.fillHeight = false,
    super.key,
  });

  final Slot? slot;
  final VoidCallback onDeposit;
  final VoidCallback onEdit;
  final VoidCallback onRelease;
  final VoidCallback onWithdraw;

  /// Abre outro slot do dex (uma forma da linha evolutiva, na aba Espécie).
  final ValueChanged<Slot>? onOpenSlot;

  /// Abre as caçadas ativas (a linha "Caçada em andamento"); `null` fora de
  /// um shiny dex, onde a linha não aparece.
  final VoidCallback? onShowHunts;

  /// A navegação pela box: as setas abaixo do nome e o gesto de deslizar na
  /// horizontal. `null` = sem navegação, só a posição do slot.
  final SlotNavigation? navigation;

  /// Painel lateral: ocupa a altura toda, com a barra presa embaixo. No
  /// bottom sheet (`false`), o painel tem a altura do conteúdo.
  final bool fillHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = slot;
    final form = current?.form;
    if (current == null || form == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Selecione um slot para ver os detalhes.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final specimen = current.specimen;
    final full = specimen == null
        ? null
        : ref.watch(specimenProvider(specimen.id)).value;
    // Como o selo da grade: caçada ativa da forma e o slot ainda precisa do
    // Pokémon (faltante, ou registrado sem ser shiny). Só num shiny dex.
    final hunting =
        onShowHunts != null &&
        ref.watch(huntedFormsProvider).contains(form.id) &&
        !(specimen?.isShiny ?? false);
    return Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          fit: fillHeight ? FlexFit.tight : FlexFit.loose,
          child: _navigable(
            context,
            SingleChildScrollView(
              key: ValueKey('slot-panel-${current.id}'),
              padding: const EdgeInsets.all(16),
              child: DetailBody(
                spriteUrl: current.spriteUrl,
                semanticLabel: form.displayName,
                title: specimen == null
                    ? Text(
                        form.displayName,
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      )
                    : SpecimenHeadline(
                        name: specimen.displayName,
                        pokeballSpriteUrl: specimen.pokeballSpriteUrl,
                        pokeballLabel: specimen.pokeball == null
                            ? null
                            : prettifyName(specimen.pokeball!),
                        gender: full?.gender,
                        isShiny: specimen.isShiny,
                        isAlpha: specimen.isAlpha,
                        style: theme.textTheme.titleLarge,
                        center: true,
                      ),
                subtitle: [
                  if (specimen != null) form.displayName,
                  form.dexNumber,
                  if (form.formName.isNotEmpty) prettifyName(form.formName),
                ].join(' · '),
                caption: navigation == null
                    ? '${current.box.name} · linha ${current.row + 1}, '
                          'coluna ${current.col + 1}'
                    : null,
                position: switch (navigation) {
                  final navigation? => SlotNavigationBar(navigation),
                  null => null,
                },
                formId: form.id,
                // Uma aba por slot: trocar de slot volta para o resumo.
                tabsKey: ValueKey('tabs-${current.id}'),
                summaryLabel: specimen == null ? 'Forma' : 'Espécime',
                highlightAbility: specimen?.ability,
                chips: [
                  if (specimen == null)
                    const Chip(
                      avatar: Icon(Icons.radio_button_unchecked),
                      label: Text('Faltante'),
                    )
                  else ...[
                    const Chip(
                      avatar: Icon(Icons.check_circle, color: Colors.green),
                      label: Text('Registrado'),
                    ),
                    if (OriginMark.fromSlug(full?.originMark) case final mark?)
                      OriginMarkChip(mark),
                  ],
                ],
                footer: switch ((specimen?.location, hunting)) {
                  (null, false) => null,
                  (final save, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (save != null)
                        LocationTile(
                          save: save,
                          since: specimen!.locationSince,
                        ),
                      if (hunting)
                        ActiveHuntTile(formId: form.id, onTap: onShowHunts),
                    ],
                  ),
                },
                nature: full?.nature,
                dexId: current.personalDex,
                onOpenSlot: onOpenSlot,
              ),
            ),
          ),
        ),
        DetailActionBar(
          primary: specimen == null
              ? FilledButton.icon(
                  onPressed: onDeposit,
                  icon: const Icon(Icons.move_to_inbox),
                  label: const Text('Depositar'),
                )
              : FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar espécime'),
                ),
          onMore: specimen == null
              ? null
              : () => showActionSheet(
                  context,
                  title: specimen.displayName,
                  actions: [
                    ...locationActions(
                      context,
                      ref,
                      id: specimen.id,
                      name: specimen.displayName,
                      away: specimen.location != null,
                      visiting: specimen.isVisitingChampions,
                    ),
                    SheetAction(
                      icon: Icons.move_up,
                      label: 'Retirar do slot',
                      subtitle: 'Volta para o inventário, disponível',
                      onSelected: onWithdraw,
                    ),
                    releaseAction(
                      visiting: specimen.isVisitingChampions,
                      onSelected: onRelease,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Com [navigation]: o gesto de deslizar, a transição entre um slot e
  /// outro e o balão da troca de box, por cima do conteúdo.
  ///
  /// O gesto é um `GestureDetector` horizontal, e não um `PageView`: as
  /// páginas vizinhas teriam de estar prontas antes (e a da box vizinha nem
  /// carregou ainda). Como a rolagem do painel é vertical, os dois gestos
  /// não disputam o mesmo toque.
  Widget _navigable(BuildContext context, Widget content) {
    final navigation = this.navigation;
    if (navigation == null) return content;
    final notice = navigation.notice;
    return Stack(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            // Dedo para a esquerda: o próximo slot, como virar uma página.
            if (velocity < -_swipeVelocity) navigation.onNext?.call();
            if (velocity > _swipeVelocity) navigation.onPrevious?.call();
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            // O slot novo entra pelo lado de onde veio o passo, por cima do
            // antigo, que só some.
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(0.15 * navigation.direction, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: content,
          ),
        ),
        if (notice != null)
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(child: BoxNoticeBalloon(notice)),
          ),
      ],
    );
  }

  /// Velocidade mínima (px/s) para o gesto contar como deslizar.
  static const _swipeVelocity = 200.0;
}
