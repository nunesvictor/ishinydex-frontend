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

  /// Formas cujo nome contém [search] (primeiros resultados).
  Future<List<FormRef>> searchForms(String search);

  Future<Specimen> create(SpecimenDraft draft);

  /// Edita o specimen; a forma não muda.
  Future<Specimen> update(int specimenId, SpecimenDraft draft);

  /// Liberta (apaga) o specimen. Se estava depositado, o slot fica faltante.
  Future<void> release(int specimenId);

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
}
