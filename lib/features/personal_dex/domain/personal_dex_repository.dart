import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

abstract interface class PersonalDexRepository {
  Future<List<PersonalDex>> fetchDexes();

  Future<PersonalDex> fetchDex(int dexId);

  /// Simula um dex com o conjunto padrão de formas, sem criar nada.
  Future<DexPreview> previewNewDex({required bool forceNewBox});

  /// Cria um dex com o conjunto padrão de formas nas primeiras boxes livres.
  Future<PersonalDex> createDex({
    required String name,
    required bool isShinyDex,
    required bool forceNewBox,
  });

  /// Renomeia o dex ou troca se é shiny dex (`force_new_box` não muda).
  Future<PersonalDex> updateDex(
    int dexId, {
    required String name,
    required bool isShinyDex,
  });

  /// Apaga o dex e libera os slots dele; os espécimes depositados continuam
  /// no inventário, disponíveis.
  Future<void> deleteDex(int dexId);

  Future<List<BoxSummary>> fetchBoxes(int dexId);

  /// Progresso por geração, na ordem em que as gerações aparecem nas boxes.
  Future<List<GenerationProgress>> fetchGenerations(int dexId);

  /// Os 30 slots de [boxId] pertencentes a [dexId].
  Future<List<Slot>> fetchSlots({required int dexId, required int boxId});

  Future<Slot> fetchSlot(int slotId);

  /// Slots de [dexId] cuja forma casa com [search]: nome ou número (Pokédex
  /// nacional ou o número mostrado no app). Primeiros resultados, na ordem
  /// das boxes.
  Future<List<Slot>> searchSlots({required int dexId, required String search});

  Future<Slot> deposit({required int slotId, required int specimenId});

  /// Uma página da lista de caçadas de um shiny dex, na ordem das boxes.
  Future<Paginated<Hunt>> fetchHunts(
    int dexId,
    HuntQuery query, {
    required int page,
    required int pageSize,
  });
}
