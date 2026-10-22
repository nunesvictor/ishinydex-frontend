import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/chip_icons.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Aba "Espécie": linha evolutiva, outras formas, os jogos do HOME em cuja
/// pokédex ela está e uma grade com gênero, captura, ciclos de ovo, estreia,
/// altura e peso.
///
/// Num dex ([dexId]), cada forma da linha evolutiva e das outras formas leva
/// ao slot dela ([onOpenSlot]); a que não está no dex fica esmaecida. Fora
/// de um dex (inventário, ficha da forma), não há slot: com [onOpenForm],
/// tocar abre a ficha da forma.
class SpeciesInfo extends ConsumerWidget {
  const SpeciesInfo({
    required this.form,
    this.dexId,
    this.onOpenSlot,
    this.onOpenForm,
    this.beforeFacts,
    super.key,
  });

  final FormDetail form;

  /// Entra entre "Pokédex dos jogos" e os dados da espécie: o quadro Tipos em
  /// batalha (#274).
  final Widget? beforeFacts;
  final int? dexId;
  final ValueChanged<Slot>? onOpenSlot;
  final ValueChanged<FormRef>? onOpenForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final related = [
      for (final stage in form.evolutionChain) ...stage,
      ...form.otherForms,
    ];
    final dexId = this.dexId;
    // Formas relacionadas → slot no dex. `null` = ainda não se sabe (ou fora
    // de um dex): nada esmaecido nem tocável.
    final slots = dexId == null || related.isEmpty
        ? null
        : ref
              .watch(
                formSlotsProvider((
                  dexId: dexId,
                  formIds: related.map((f) => f.id).toSet().join(','),
                )),
              )
              .value;
    final slotOf = {
      for (final slot in slots ?? const <Slot>[])
        if (slot.form case final f?) f.id: slot,
    };
    Widget item(FormRef ref, {required Widget child}) {
      final slot = slotOf[ref.id];
      final openSlot = onOpenSlot;
      final openForm = onOpenForm;
      final onTap = ref.id == form.id
          ? null
          : dexId != null
          ? (slot == null || openSlot == null ? null : () => openSlot(slot))
          : (openForm == null ? null : () => openForm(ref));
      return Opacity(
        opacity: slots != null && slot == null ? 0.45 : 1,
        child: InkWell(
          key: ValueKey('species-form-${ref.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: child,
        ),
      );
    }

    final facts = _facts(context.l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (form.evolutionChain.isNotEmpty) ...[
          Text(context.l10n.evolutionLine, style: theme.textTheme.titleSmall),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (i, stage) in form.evolutionChain.indexed) ...[
                if (i > 0) const Icon(Icons.chevron_right, size: 18),
                for (final ref in stage)
                  item(
                    ref,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // A forma atual em destaque.
                        color: ref.id == form.id
                            ? theme.colorScheme.secondaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          PokemonSprite(url: ref.spriteUrl, size: 44),
                          Text(
                            ref.displayName,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
        if (form.otherForms.isNotEmpty) ...[
          Text(
            context.l10n.speciesOtherForms,
            style: theme.textTheme.titleSmall,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ref in form.otherForms)
                item(
                  ref,
                  child: Chip(
                    avatar: PokemonSprite(url: ref.spriteUrl, size: 24),
                    label: Text(
                      ref.formName.isEmpty
                          ? ref.displayName
                          : prettifyName(ref.formName),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (form.pokedexes.isNotEmpty) ...[
          Text(context.l10n.inPokedexOf, style: theme.textTheme.titleSmall),
          _Pokedexes(form.pokedexes),
        ],
        ?beforeFacts,
        if (facts.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              // Três por linha no celular; mais nas telas largas.
              final columns = constraints.maxWidth >= 480 ? 6 : 3;
              final width =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, value) in facts)
                    SizedBox(
                      width: width,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: theme.textTheme.labelSmall),
                              Text(
                                value,
                                style: theme.textTheme.labelLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  List<(String, String)> _facts(AppLocalizations l10n) => [
    if (form.genderRate case final rate?)
      (l10n.factGender, genderRatio(l10n, rate)),
    if (form.captureRate case final rate?) (l10n.factCatchRate, '$rate'),
    if (form.hatchCounter case final cycles?) (l10n.factEggCycles, '$cycles'),
    if (form.debutVersions.isNotEmpty)
      (
        l10n.factDebut,
        joinLabels(l10n, [...form.debutVersions.map(prettifyName)]),
      ),
    if (form.height case final height?)
      (l10n.factHeight, '${decimal(l10n, height / 10)} m'),
    if (form.weight case final weight?)
      (l10n.factWeight, '${decimal(l10n, weight / 10)} kg'),
  ];
}

/// Os jogos em cuja pokédex a espécie está, com cada pokédex e o número
/// (#322). O estado de cada versão fica no próprio ícone: colorido, você tem
/// save; cinza, não tem; um contorno tracejado, a forma não aparece nela
/// (exclusiva da outra); e um cadeado no canto, shiny lock. Tocar no ícone
/// explica por extenso. Os jogos com save vêm primeiro, com fundo.
class _Pokedexes extends ConsumerWidget {
  const _Pokedexes(this.games);

  final List<GamePokedex> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final owned = {
      for (final save in ref.watch(savesProvider).value ?? const <Save>[])
        ?save.trainer.version,
    };
    // Os saves do usuário em que a forma aparece: num exclusivo (o
    // Koraidon só no Scarlet), o save da outra versão não conta.
    List<String> mine(GamePokedex game) => [
      ...(game.exclusiveTo.isEmpty ? game.versions : game.exclusiveTo).where(
        owned.contains,
      ),
    ];
    final ordered = [
      ...games.where((g) => mine(g).isNotEmpty),
      ...games.where((g) => mine(g).isEmpty),
    ];
    // Um pouco maiores que os 22 de antes: agora carregam o estado. Com o
    // texto aumentado, crescem até 15%.
    final size =
        26 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.15);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        for (final game in ordered)
          DecoratedBox(
            decoration: BoxDecoration(
              color: mine(game).isEmpty
                  ? null
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                spacing: 12,
                children: [
                  // Largura de dois ícones: os nomes ficam alinhados. Um jogo
                  // só (Legends: Arceus, Z-A) fica no meio dessa largura.
                  SizedBox(
                    width: size * 2 + 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 4,
                      children: [
                        for (final version in game.versions)
                          PokedexGameIcon(
                            version,
                            size: size,
                            present:
                                game.exclusiveTo.isEmpty ||
                                game.exclusiveTo.contains(version),
                            exclusive: game.exclusiveTo.contains(version),
                            locked: game.shinyLockedIn.contains(version),
                            owned: owned.contains(version),
                            ring: mine(game).isEmpty
                                ? theme.colorScheme.surface
                                : theme.colorScheme.surfaceContainerHigh,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          game.versions.map(versionLabel).join(' / '),
                          style: theme.textTheme.bodyLarge,
                        ),
                        // Fora das pokédex, pelo HOME (#314): explica.
                        if (game.viaHomeEgg)
                          Text(
                            context.l10n.pokedexViaHomeEgg,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          Text(
                            game.entries
                                .map(
                                  (e) => context.l10n.pokedexEntry(
                                    e,
                                    context.catalogText(e.label, e.labels),
                                  ),
                                )
                                .join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        _Legend(version: ordered.first.versions.first),
        Text(context.l10n.pokedexNoGuarantee, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// O ícone de uma versão na Pokédex dos jogos (#322): colorido com save,
/// cinza sem; um contorno tracejado quando a forma não aparece nela; o
/// cadeado no canto com shiny lock. Tocar mostra tudo por extenso, que é
/// também o rótulo do leitor de tela.
class PokedexGameIcon extends StatelessWidget {
  const PokedexGameIcon(
    this.version, {
    required this.present,
    required this.owned,
    this.exclusive = false,
    this.locked = false,
    this.size = 26,
    this.ring,
    super.key,
  });

  final String version;
  final double size;

  /// A forma aparece nesta versão (não é exclusiva da outra).
  final bool present;
  final bool exclusive;
  final bool locked;
  final bool owned;

  /// A cor em volta do cadeado: a do fundo da linha.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final description = [
      versionLabel(version),
      if (!present)
        l10n.pokedexIconAbsent
      else if (exclusive)
        l10n.pokedexIconExclusive,
      if (present && locked) l10n.pokedexIconLocked,
      if (owned) l10n.pokedexIconOwned else l10n.pokedexIconNoSave,
    ].join(' · ');
    return Tooltip(
      message: description,
      triggerMode: TooltipTriggerMode.tap,
      excludeFromSemantics: true,
      child: Semantics(
        label: description,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (present)
                ClipRRect(
                  borderRadius: BorderRadius.circular(size * 0.27),
                  child: GameIcon(version, size: size, muted: !owned),
                )
              else
                CustomPaint(
                  key: const ValueKey('pokedex-icon-absent'),
                  size: Size.square(size),
                  painter: _DashedBox(scheme.outline, size * 0.27),
                ),
              if (present && locked)
                Positioned(
                  key: const ValueKey('pokedex-icon-lock'),
                  right: -5,
                  bottom: -5,
                  child: LockBadge(color: scheme.error, ring: ring),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O cadeado vermelho do shiny lock, num círculo (#322).
class LockBadge extends StatelessWidget {
  const LockBadge({required this.color, this.ring, this.size = 15, super.key});

  final Color color;
  final Color? ring;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: ring == null ? null : Border.all(color: ring!, width: 2),
    ),
    child: Icon(Icons.lock, size: size * 0.55, color: Colors.white),
  );
}

/// Um quadrado de cantos redondos com o contorno tracejado.
class _DashedBox extends CustomPainter {
  _DashedBox(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 3.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox old) =>
      old.color != color || old.radius != radius;
}

/// A legenda de uma linha dos ícones (#322), com o primeiro jogo da lista.
class _Legend extends StatelessWidget {
  const _Legend({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    Widget item(Widget icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        icon,
        Text(text, style: style),
      ],
    );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            item(
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: GameIcon(version, size: 16),
              ),
              context.l10n.pokedexLegendOwned,
            ),
            item(
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: GameIcon(version, size: 16, muted: true),
              ),
              context.l10n.pokedexLegendNoSave,
            ),
            item(
              CustomPaint(
                size: const Size.square(16),
                painter: _DashedBox(theme.colorScheme.outline, 4),
              ),
              context.l10n.pokedexLegendAbsent,
            ),
            item(
              LockBadge(color: theme.colorScheme.error, size: 13),
              context.l10n.pokedexLegendLocked,
            ),
          ],
        ),
      ),
    );
  }
}

/// Proporção de gênero a partir do `gender_rate` (oitavos de fêmea; -1 =
/// sem gênero): "♂ 87,5% · ♀ 12,5%", "Só macho", "Só fêmea".
String genderRatio(AppLocalizations l10n, int rate) => switch (rate) {
  < 0 => l10n.genderless,
  0 => l10n.maleOnly,
  >= 8 => l10n.femaleOnly,
  _ =>
    '♂ ${decimal(l10n, (8 - rate) * 12.5)}% · '
        '♀ ${decimal(l10n, rate * 12.5)}%',
};

/// Número no formato do idioma, sem ",0": 1.7 → "1,7" (en: "1.7");
/// 50.0 → "50".
String decimal(AppLocalizations l10n, num value) =>
    NumberFormat('0.###', l10n.localeName).format(value);
