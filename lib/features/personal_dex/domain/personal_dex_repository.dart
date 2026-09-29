import 'package:ishinydex/features/personal_dex/domain/models.dart';

abstract interface class PersonalDexRepository {
  Future<List<PersonalDex>> fetchDexes();

  Future<PersonalDex> fetchDex(int dexId);

  Future<List<BoxSummary>> fetchBoxes(int dexId);

  /// Os 30 slots de [boxId] pertencentes a [dexId].
  Future<List<Slot>> fetchSlots({required int dexId, required int boxId});

  Future<Slot> deposit({required int slotId, required int specimenId});
}
