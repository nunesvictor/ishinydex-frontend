import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_headline.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Espécimes fora do HOME, agrupados por save. Dentro de cada save, quem
/// saiu há mais tempo vem primeiro: é a lista que evita esquecer um Pokémon
/// num jogo.
class AwayPage extends ConsumerWidget {
  const AwayPage({super.key});

  /// Saves com seus espécimes; o save com o espécime mais antigo primeiro.
  static List<(Save, List<Specimen>)> group(List<Specimen> specimens) {
    DateTime since(Specimen s) => s.locationSince ?? DateTime(9999);
    final bySave = <int, (Save, List<Specimen>)>{};
    for (final s in [
      ...specimens,
    ]..sort((a, b) => since(a).compareTo(since(b)))) {
      final save = s.location!;
      bySave.putIfAbsent(save.id, () => (save, []));
      bySave[save.id]!.$2.add(s);
    }
    return [...bySave.values];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Fora do HOME')),
    body: Center(
      // No PC, uma lista de 1.400 px de largura só espalharia o texto.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: switch (ref.watch(awaySpecimensProvider)) {
          AsyncData(value: final specimens) when specimens.isEmpty =>
            const EmptyView(message: 'Todos os seus Pokémon estão no HOME.'),
          AsyncData(value: final specimens) => RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(awaySpecimensProvider.future),
            child: ListView(
              children: [
                for (final (save, items) in group(specimens)) ...[
                  ListTile(
                    leading: SaveIcon(save, size: 28),
                    title: Text(
                      save.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      items.length == 1
                          ? '1 Pokémon'
                          : '${items.length} Pokémon',
                    ),
                  ),
                  for (final specimen in items) _AwayTile(specimen: specimen),
                  const Divider(),
                ],
              ],
            ),
          ),
          AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(awaySpecimensProvider),
          ),
          _ => const LoadingView(),
        },
      ),
    ),
  );
}

class _AwayTile extends ConsumerWidget {
  const _AwayTile({required this.specimen});

  final Specimen specimen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = specimen.locationSince;
    final form = specimen.formRef;
    return ListTile(
      key: ValueKey('away-${specimen.id}'),
      leading: PokemonSprite(url: specimen.spriteUrl, size: 48),
      title: SpecimenHeadline(
        name: specimen.displayName,
        pokeballSpriteUrl: specimen.pokeballSpriteUrl,
        pokeballLabel: specimen.pokeball == null
            ? null
            : prettifyName(specimen.pokeball!),
        gender: specimen.gender,
        isShiny: specimen.isShiny,
        isAlpha: specimen.isAlpha,
        isFromGo: specimen.isFromGo,
      ),
      // Uma linha só: nº da dex e há quanto tempo saiu.
      subtitle: Text(
        [
          ?form?.dexNumber,
          if (since != null) 'Saiu ${awayFor(since)}',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Trazer de volta ao HOME',
        icon: const Icon(Icons.flight_land),
        onPressed: () => bringBack(
          context,
          ref,
          specimenId: specimen.id,
          name: specimen.displayName,
        ),
      ),
      onTap: () => context.push(Routes.specimen(specimen.id)),
    );
  }
}
