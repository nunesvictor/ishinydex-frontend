import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/core/web/browser.dart' as browser;
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
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

/// Os métodos de shiny do jogo do OT (`Catalog.shinyMethodsFor`); sem o
/// catálogo, nenhum.
final shinyMethodsProvider =
    Provider<List<ShinyMethod> Function(String? version, {bool fromGo})>((ref) {
      final catalog = ref.watch(fakeBackendProvider).catalog;
      return (version, {fromGo = false}) =>
          catalog?.shinyMethodsFor(version, fromGo: fromGo) ?? const [];
    });

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
