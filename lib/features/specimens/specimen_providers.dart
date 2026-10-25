import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/core/clock.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/core/web/browser.dart' as browser;
import 'package:ishinydex/core/web/share_outcome.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/home_cutoff.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/specimen_repository.dart';
import 'package:ishinydex/features/specimens/domain/transfer_rules.dart';

/// O backend local: os dados do aparelho (modo local) ou de exemplo
/// (demonstração).
final specimenRepositoryProvider = Provider<SpecimenRepository>(
  (ref) => ref.watch(fakeBackendProvider),
);

final FutureProviderFamily<List<Specimen>, int> availableSpecimensProvider =
    FutureProvider.autoDispose.family<List<Specimen>, int>(
      (ref, formId) =>
          ref.watch(specimenRepositoryProvider).fetchAvailable(formId),
    );

final FutureProviderFamily<Specimen, int> specimenProvider = FutureProvider
    .autoDispose
    .family<Specimen, int>(
      (ref, specimenId) =>
          ref.watch(specimenRepositoryProvider).fetchSpecimen(specimenId),
    );

const specimenPageSize = 20;

typedef SpecimenPageKey = ({SpecimenQuery query, int page});

/// Uma página do inventário. A lista observa só as páginas dos itens que
/// aparecem na tela: rolagem infinita sem estado extra.
final FutureProviderFamily<Paginated<Specimen>, SpecimenPageKey>
specimenPageProvider = FutureProvider.autoDispose
    .family<Paginated<Specimen>, SpecimenPageKey>(
      (ref, key) => ref
          .watch(specimenRepositoryProvider)
          .fetchSpecimens(
            key.query,
            page: key.page,
            pageSize: specimenPageSize,
          ),
    );

/// Formas cujo nome contém o texto (seletor de forma do cadastro avulso).
/// Ids de todos os resultados de uma consulta (sem paginação): o modo de
/// seleção usa para contar os marcados que estão fora da lista.
final FutureProviderFamily<List<int>, SpecimenQuery> specimenIdsProvider =
    FutureProvider.autoDispose.family<List<int>, SpecimenQuery>(
      (ref, query) =>
          ref.watch(specimenRepositoryProvider).fetchSpecimenIds(query),
    );

final FutureProviderFamily<List<FormRef>, String> formSearchProvider =
    FutureProvider.autoDispose.family<List<FormRef>, String>(
      (ref, search) =>
          ref.watch(specimenRepositoryProvider).searchForms(search),
    );

final FutureProviderFamily<FormDetail, int> formDetailProvider = FutureProvider
    .autoDispose
    .family<FormDetail, int>(
      (ref, formId) => ref.watch(specimenRepositoryProvider).fetchForm(formId),
    );

final specimenOptionsProvider = FutureProvider<SpecimenOptions>(
  (ref) => ref.watch(specimenRepositoryProvider).fetchOptions(),
);

final FutureProvider<List<Trainer>> trainersProvider =
    FutureProvider.autoDispose<List<Trainer>>(
      (ref) => ref.watch(specimenRepositoryProvider).fetchTrainers(),
    );

/// A data de corte do HOME do jogo (#222), com o relógio; `null` para os
/// jogos sem corte (e em catálogo antigo).
final homeCutoffProvider = Provider<HomeCutoff? Function(String? version)>((
  ref,
) {
  final cutoffs =
      ref.watch(fakeBackendProvider).catalog?.homeCutoffs ??
      const <String, DateTime>{};
  final clock = ref.watch(clockProvider);
  return (version) => switch (cutoffs[version]) {
    final until? => HomeCutoff(until: until, now: clock()),
    null => null,
  };
});

/// O próximo corte do HOME que ainda não passou (#316): a data do filtro
/// "Fim do Pokémon Bank" das caçadas. `null` sem corte (catálogo antigo) ou
/// depois de todos.
final nextHomeCutoffProvider = Provider<DateTime?>((ref) {
  final cutoffs =
      ref.watch(fakeBackendProvider).catalog?.homeCutoffs ??
      const <String, DateTime>{};
  final now = ref.watch(clockProvider)();
  return ([
    for (final until in cutoffs.values)
      if (now.isBefore(until)) until,
  ]..sort()).firstOrNull;
});

/// Os métodos de shiny do jogo do OT (`Catalog.shinyMethodsFor`); sem o
/// catálogo, nenhum.
final shinyMethodsProvider =
    Provider<
      List<ShinyMethod> Function(String? version, {bool fromGo, int? formId})
    >((ref) {
      final catalog = ref.watch(fakeBackendProvider).catalog;
      return (version, {fromGo = false, formId}) =>
          catalog?.shinyMethodsFor(version, fromGo: fromGo, formId: formId) ??
          const [];
    });

/// Se a forma pode ser alfa com a marca de origem (#362); sem um catálogo
/// que diga quais formas podem ser alfa, sem restrição.
final alphaAllowedProvider = Provider<bool Function(int formId, String? mark)>((
  ref,
) {
  final catalog = ref.watch(fakeBackendProvider).catalog;
  return (formId, mark) =>
      catalog == null ||
      !catalog.hasAlphaForms ||
      catalog.canBeAlpha(formId, mark);
});

/// As pré-evoluções de uma forma, da mais básica à anterior (#315).
final preEvolutionsProvider = Provider<List<FormRef> Function(int formId)>(
  (ref) => ref.watch(fakeBackendProvider).preEvolutionsOf,
);

/// A forma pelo id (a forma caçada do registro, #315); `null` se não
/// existir.
final formRefOfProvider = Provider<FormRef? Function(int formId)>(
  (ref) => ref.watch(fakeBackendProvider).formRefOf,
);

/// Abre um link externo (o post da caçada) numa aba nova.
final openLinkProvider = Provider<void Function(String url)>(
  (ref) => browser.openInNewTab,
);

/// Se o Pokémon (a forma ou uma pré-evolução) está na pokédex do jogo do OT
/// (`Catalog.originFits`); sem o catálogo, sempre.
final originFitsProvider = Provider<bool Function(int formId, String? version)>(
  (ref) {
    final catalog = ref.watch(fakeBackendProvider).catalog;
    return (formId, version) => catalog?.originFits(formId, version) ?? true;
  },
);

/// Se a forma pode ser caçada no jogo (`Catalog.huntableIn`); sem o
/// catálogo, sempre.
final huntableInProvider = Provider<bool Function(int formId, String? version)>(
  (ref) {
    final catalog = ref.watch(fakeBackendProvider).catalog;
    return (formId, version) => catalog?.huntableIn(formId, version) ?? true;
  },
);

/// Compara versões na ordem da série (`Catalog.compareVersions`); sem o
/// catálogo, mantém a ordem recebida.
final versionOrderProvider = Provider<int Function(String a, String b)>((ref) {
  final catalog = ref.watch(fakeBackendProvider).catalog;
  return catalog?.compareVersions ?? (_, _) => 0;
});

/// A geração de cada versão (`scarlet` → `generation-ix`), do catálogo;
/// vazio sem ele.
final versionGenerationProvider = Provider<Map<String, String>>((ref) {
  final catalog = ref.watch(fakeBackendProvider).catalog;
  return {
    for (final v in catalog?.versions ?? const <GameVersion>[])
      v.name: v.generation,
  };
});

/// Quem dos espécimes pode ir para o save, quem fica e os avisos
/// (`FakeBackend.transferCheck`).
final transferCheckProvider =
    Provider<TransferCheck Function(List<int> ids, Save save)>(
      (ref) => ref.watch(fakeBackendProvider).transferCheck,
    );

/// Saves do usuário (Ajustes → Meus saves).
final FutureProvider<List<Save>> savesProvider =
    FutureProvider.autoDispose<List<Save>>(
      (ref) => ref.watch(specimenRepositoryProvider).fetchSaves(),
    );

/// Espécimes fora do HOME (tela "Fora do HOME"); são poucos, então vêm
/// todos de uma vez.
final FutureProvider<List<Specimen>> awaySpecimensProvider =
    FutureProvider.autoDispose<List<Specimen>>(
      (ref) async =>
          (await ref
                  .watch(specimenRepositoryProvider)
                  .fetchSpecimens(
                    const SpecimenQuery(location: SpecimenQuery.locationAway),
                    page: 1,
                    pageSize: 500,
                  ))
              .results,
    );

/// Versões de jogo: mudam só com um novo jogo, então ficam em cache.
final versionsProvider = FutureProvider<List<GameVersion>>(
  (ref) => ref.watch(specimenRepositoryProvider).fetchVersions(),
);

/// Ordena candidatos ao depósito: primeiro os que batem com [preferShiny].
List<Specimen> sortForDeposit(
  List<Specimen> specimens, {
  required bool preferShiny,
}) => [...specimens]
  ..sort((a, b) {
    final aMatches = a.isShiny == preferShiny ? 0 : 1;
    final bMatches = b.isShiny == preferShiny ? 0 : 1;
    if (aMatches != bMatches) return aMatches - bMatches;
    return a.id.compareTo(b.id);
  });

/// Compartilha um arquivo pela folha do sistema (Web Share, #243); os
/// testes trocam.
typedef FileSharer = Future<ShareOutcome> Function(
  Uint8List bytes, {
  required String name,
  required String type,
});

final fileSharerProvider = Provider<FileSharer>((ref) => browser.shareFile);

/// Transforma o que está desenhado em [boundary] num PNG, em [pixelRatio]
/// pixels por ponto (#243); os testes trocam.
typedef PngCapturer = Future<Uint8List> Function(
  RenderRepaintBoundary boundary,
  double pixelRatio,
);

final pngCapturerProvider = Provider<PngCapturer>((ref) => capturePng);

/// O [PngCapturer] de verdade: `toImage` e a conversão para PNG.
Future<Uint8List> capturePng(
  RenderRepaintBoundary boundary,
  double pixelRatio,
) async {
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
