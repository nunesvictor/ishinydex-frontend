import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// O backend local: os dados do aparelho (modo local) ou de exemplo
/// (demonstração).
final personalDexRepositoryProvider = Provider<PersonalDexRepository>(
  (ref) => ref.watch(fakeBackendProvider),
);

/// O catálogo diz em que jogos cada espécie está: sem isso (a demonstração
/// fixa, um catálogo antigo), as caçadas ficam sem o filtro "Jogo".
final knowsGamesProvider = Provider<bool>(
  (ref) => ref.watch(fakeBackendProvider).catalog?.hasPokedexes ?? false,
);

final lastDexStorageProvider = Provider<LastDexStorage>(
  (ref) => PrefsLastDexStorage(),
);

final FutureProvider<List<PersonalDex>> dexListProvider =
    FutureProvider.autoDispose<List<PersonalDex>>(
      (ref) => ref.watch(personalDexRepositoryProvider).fetchDexes(),
    );

final FutureProviderFamily<PersonalDex, int> dexProvider = FutureProvider
    .autoDispose
    .family<PersonalDex, int>(
      (ref, dexId) => ref.watch(personalDexRepositoryProvider).fetchDex(dexId),
    );

final FutureProviderFamily<List<BoxSummary>, int> boxesProvider = FutureProvider
    .autoDispose
    .family<List<BoxSummary>, int>(
      (ref, dexId) =>
          ref.watch(personalDexRepositoryProvider).fetchBoxes(dexId),
    );

final FutureProviderFamily<List<GenerationProgress>, int> generationsProvider =
    FutureProvider.autoDispose.family<List<GenerationProgress>, int>(
      (ref, dexId) =>
          ref.watch(personalDexRepositoryProvider).fetchGenerations(dexId),
    );

/// Simulação do dex padrão, por opção de "nova box a cada geração".
final FutureProviderFamily<DexPreview, bool> dexPreviewProvider = FutureProvider
    .autoDispose
    .family<DexPreview, bool>(
      (ref, forceNewBox) => ref
          .watch(personalDexRepositoryProvider)
          .previewNewDex(forceNewBox: forceNewBox),
    );

typedef BoxKey = ({int dexId, int boxId});

final FutureProviderFamily<List<Slot>, BoxKey> slotsProvider = FutureProvider
    .autoDispose
    .family<List<Slot>, BoxKey>(
      (ref, key) => ref
          .watch(personalDexRepositoryProvider)
          .fetchSlots(dexId: key.dexId, boxId: key.boxId),
    );

typedef SlotSearchKey = ({int dexId, String search});

/// Resultados da busca no dex (nome ou número da forma).
final FutureProviderFamily<List<Slot>, SlotSearchKey> slotSearchProvider =
    FutureProvider.autoDispose.family<List<Slot>, SlotSearchKey>(
      (ref, key) => ref
          .watch(personalDexRepositoryProvider)
          .searchSlots(dexId: key.dexId, search: key.search),
    );

const huntPageSize = 20;

typedef HuntPageKey = ({int dexId, HuntQuery query, int page});

/// Uma página da lista de caçadas. Como no inventário, cada item observa só
/// a página em que está (rolagem infinita sem estado extra).
final FutureProviderFamily<Paginated<Hunt>, HuntPageKey> huntPageProvider =
    FutureProvider.autoDispose.family<Paginated<Hunt>, HuntPageKey>(
      (ref, key) => ref
          .watch(personalDexRepositoryProvider)
          .fetchHunts(
            key.dexId,
            key.query,
            page: key.page,
            pageSize: huntPageSize,
          ),
    );

typedef FormSlotsKey = ({int dexId, String formIds});

/// Slots de um dex com estas formas (`formIds` da chave: ids por
/// vírgula, para a chave do provider comparar por valor). A aba Espécie do
/// painel usa para saber quais formas da linha evolutiva estão no dex.
final FutureProviderFamily<List<Slot>, FormSlotsKey> formSlotsProvider =
    FutureProvider.autoDispose.family<List<Slot>, FormSlotsKey>(
      (ref, key) => ref
          .watch(personalDexRepositoryProvider)
          .fetchSlotsByForms(
            dexId: key.dexId,
            formIds: [for (final id in key.formIds.split(',')) int.parse(id)],
          ),
    );

typedef LinkPreviewKey = ({int dexId, bool strict});

/// Prévia de "Depositar automaticamente" (nada é salvo).
final FutureProviderFamily<LinkResult, LinkPreviewKey> linkPreviewProvider =
    FutureProvider.autoDispose.family<LinkResult, LinkPreviewKey>(
      (ref, key) => ref
          .watch(personalDexRepositoryProvider)
          .linkSpecimens(key.dexId, strict: key.strict, dryRun: true),
    );

final slotActionsProvider = Provider<SlotActions>(SlotActions.new);

final dexActionsProvider = Provider<DexActions>(DexActions.new);

/// Renomear e apagar um PersonalDex, invalidando o que mostra o dex.
class DexActions {
  DexActions(this._ref);

  final Ref _ref;

  Future<PersonalDex> update(
    int dexId, {
    required String name,
    required bool isShinyDex,
  }) async {
    final dex = await _ref
        .read(personalDexRepositoryProvider)
        .updateDex(dexId, name: name, isShinyDex: isShinyDex);
    _ref
      ..invalidate(dexProvider(dexId))
      ..invalidate(dexListProvider)
      // Shiny dex muda o sprite dos slots.
      ..invalidate(slotsProvider);
    return dex;
  }

  /// Apaga o dex. Os espécimes que estavam nele ficam disponíveis, então o
  /// inventário também recarrega.
  Future<void> delete(int dexId) async {
    await _ref.read(personalDexRepositoryProvider).deleteDex(dexId);
    _ref.read(slotActionsProvider).specimensChanged();
  }
}

/// Depositar, libertar e editar specimens de um slot, invalidando o que a
/// tela mostra (slots, contagens da box, do dex e da lista).
class SlotActions {
  SlotActions(this._ref);

  final Ref _ref;

  PersonalDexRepository get _repository =>
      _ref.read(personalDexRepositoryProvider);

  Future<Slot> deposit(Slot slot, {required int specimenId}) async {
    final updated = await _repository.deposit(
      slotId: slot.id,
      specimenId: specimenId,
    );
    _refresh(slot);
    return updated;
  }

  /// Retira o specimen do slot sem apagá-lo: ele volta ao inventário,
  /// disponível, e o slot fica faltante. Desfazer = [deposit] de novo.
  Future<void> withdraw(Slot slot) async {
    await _repository.withdraw(slot.id);
    _ref.invalidate(specimenProvider(slot.specimen!.id));
    _refresh(slot);
  }

  /// Depositar automaticamente no dex [dexId]; recarrega tudo que mostra
  /// slots e contagens.
  Future<LinkResult> linkSpecimens(int dexId, {required bool strict}) async {
    final result = await _repository.linkSpecimens(dexId, strict: strict);
    specimensChanged();
    _ref.invalidate(linkPreviewProvider);
    return result;
  }

  /// Liberta (apaga) o specimen do slot; o slot fica faltante.
  Future<void> release(Slot slot) async {
    await _ref.read(specimenRepositoryProvider).release(slot.specimen!.id);
    _refresh(slot);
  }

  /// O specimen do slot foi editado: apelido, bola e shiny/alfa aparecem na
  /// box e no painel de detalhe.
  void specimenEdited(Slot slot) {
    _ref.invalidate(specimenProvider(slot.specimen!.id));
    _refresh(slot);
  }

  /// Specimen criado, editado ou libertado fora da tela do dex (inventário):
  /// recarrega tudo que mostra slots e contagens.
  void specimensChanged() => _ref
    ..invalidate(specimenPageProvider)
    ..invalidate(specimenIdsProvider)
    ..invalidate(specimenProvider)
    ..invalidate(awaySpecimensProvider)
    ..invalidate(dexListProvider)
    ..invalidate(dexProvider)
    ..invalidate(boxesProvider)
    ..invalidate(generationsProvider)
    ..invalidate(slotsProvider)
    ..invalidate(huntPageProvider);

  /// Liberta um specimen pelo id (inventário), esteja depositado ou não.
  Future<void> releaseSpecimen(int specimenId) async {
    await _ref.read(specimenRepositoryProvider).release(specimenId);
    specimensChanged();
  }

  void _refresh(Slot slot) {
    final dexId = slot.personalDex;
    // O inventário (outra aba, viva em segundo plano) mostra a situação.
    _ref
      ..invalidate(specimenPageProvider)
      ..invalidate(dexListProvider);
    if (dexId == null) return;
    _ref
      // A lista de caçadas pode estar embaixo, na pilha de navegação.
      ..invalidate(huntPageProvider)
      ..invalidate(slotsProvider((dexId: dexId, boxId: slot.box.id)))
      ..invalidate(boxesProvider(dexId))
      ..invalidate(generationsProvider(dexId))
      ..invalidate(dexProvider(dexId));
  }
}
