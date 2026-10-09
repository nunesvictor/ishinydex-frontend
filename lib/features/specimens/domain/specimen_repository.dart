import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

abstract interface class SpecimenRepository {
  /// Specimens da forma [formId] que ainda não estão depositados.
  Future<List<Specimen>> fetchAvailable(int formId);

  Future<Specimen> fetchSpecimen(int specimenId);

  /// Página [page] do inventário, filtrada por [query].
  Future<Paginated<Specimen>> fetchSpecimens(
    SpecimenQuery query, {
    required int page,
    required int pageSize,
  });

  /// Ids de todos os specimens do filtro, na ordem da lista (para
  /// "selecionar todos os resultados").
  Future<List<int>> fetchSpecimenIds(SpecimenQuery query);

  /// Aplica [changes] a todos os [ids], tudo ou nada. Devolve quantos foram
  /// atualizados. Gênero impossível para algum → [GenderConflictFailure].
  Future<int> bulkUpdate({
    required List<int> ids,
    required SpecimenChanges changes,
  });

  /// Formas cujo nome contém [search] (primeiros resultados).
  Future<List<FormRef>> searchForms(String search);

  Future<Specimen> create(SpecimenDraft draft);

  /// Edita o specimen; a forma não muda.
  Future<Specimen> update(int specimenId, SpecimenDraft draft);

  /// Começa ([visiting]) ou encerra a visita ao Pokémon Champions (#174).
  Future<Specimen> setChampionsVisit(int specimenId, {required bool visiting});

  /// Liberta (apaga) o specimen. Se estava depositado, o slot fica faltante.
  Future<void> release(int specimenId);

  /// Liberta todos os [ids], tudo ou nada; os depositados deixam o slot
  /// faltante. Devolve quantos foram libertados.
  Future<int> bulkRelease(List<int> ids);

  Future<FormDetail> fetchForm(int formId);

  Future<SpecimenOptions> fetchOptions();

  Future<List<Trainer>> fetchTrainers();

  /// Cria um treinador original; [version] é o `name` de uma [GameVersion].
  Future<Trainer> createTrainer({
    required String name,
    required String trainerId,
    String? version,
  });

  /// Versões de jogo em ordem de lançamento.
  Future<List<GameVersion>> fetchVersions();

  /// Saves do usuário.
  Future<List<Save>> fetchSaves();

  /// Torna o treinador [trainerId] um save. Só treinadores de jogos que
  /// recebem do HOME ([Save.transferVersions]).
  Future<Save> createSave({required int trainerId, String label = ''});

  Future<Save> updateSave(int saveId, {required String label});

  /// Apaga o save; com espécimes nele, falha (`ValidationFailure`).
  Future<void> deleteSave(int saveId);

  /// Leva os [ids] para o save [saveId] (`null` = de volta ao HOME), tudo
  /// ou nada. Devolve quantos mudaram de lugar.
  Future<int> transfer(List<int> ids, {required int? saveId});

  /// O espécime evoluiu fora do HOME: passa a ser a forma [formId] e sai do
  /// slot da forma antiga.
  Future<Specimen> evolve(int specimenId, {required int formId});
}
