import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/auth/auth_providers.dart';
import 'package:ishinydex/features/personal_dex/data/http_personal_dex_repository.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';

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

typedef BoxKey = ({int dexId, int boxId});

final FutureProviderFamily<List<Slot>, BoxKey> slotsProvider = FutureProvider
    .autoDispose
    .family<List<Slot>, BoxKey>(
      (ref, key) => ref
          .watch(personalDexRepositoryProvider)
          .fetchSlots(dexId: key.dexId, boxId: key.boxId),
    );

final slotActionsProvider = Provider<SlotActions>(SlotActions.new);

/// Depositar/retirar e invalidar as contagens afetadas.
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

  Future<Slot> withdraw(Slot slot) async {
    final updated = await _repository.withdraw(slot.id);
    _refresh(slot);
    return updated;
  }

  void _refresh(Slot slot) {
    final dexId = slot.personalDex;
    _ref.invalidate(dexListProvider);
    if (dexId == null) return;
    _ref
      ..invalidate(slotsProvider((dexId: dexId, boxId: slot.box.id)))
      ..invalidate(boxesProvider(dexId))
      ..invalidate(dexProvider(dexId));
  }
}
