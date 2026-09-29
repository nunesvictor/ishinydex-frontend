import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/auth/auth_providers.dart';
import 'package:ishinydex/features/personal_dex/data/http_personal_dex_repository.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

final personalDexRepositoryProvider = Provider<PersonalDexRepository>((ref) {
  if (ref.watch(envProvider).useFakeApi) return ref.watch(fakeBackendProvider);
  return HttpPersonalDexRepository(ref.watch(dioProvider));
});

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

final slotActionsProvider = Provider<SlotActions>(SlotActions.new);

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
    ..invalidate(dexListProvider)
    ..invalidate(dexProvider)
    ..invalidate(boxesProvider)
    ..invalidate(generationsProvider)
    ..invalidate(slotsProvider);

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
      ..invalidate(slotsProvider((dexId: dexId, boxId: slot.box.id)))
      ..invalidate(boxesProvider(dexId))
      ..invalidate(generationsProvider(dexId))
      ..invalidate(dexProvider(dexId));
  }
}
