import 'package:ishinydex/features/personal_dex/domain/models.dart';

abstract interface class PersonalDexRepository {
  Future<List<PersonalDex>> fetchDexes();

  Future<PersonalDex> fetchDex(int dexId);

  Future<List<BoxSummary>> fetchBoxes(int dexId);

  /// Os 30 slots de [boxId] pertencentes a [dexId].
  Future<List<Slot>> fetchSlots({required int dexId, required int boxId});

  Future<Slot> fetchSlot(int slotId);

  /// Slots de [dexId] cuja forma casa com [search]: nome ou número (Pokédex
  /// nacional ou o número mostrado no app). Primeiros resultados, na ordem
  /// das boxes.
  Future<List<Slot>> searchSlots({required int dexId, required String search});

  Future<Slot> deposit({required int slotId, required int specimenId});
}
