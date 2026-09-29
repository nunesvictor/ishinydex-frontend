import 'package:ishinydex/features/specimens/domain/models.dart';

abstract interface class SpecimenRepository {
  /// Specimens da forma [formId] que ainda não estão depositados.
  Future<List<Specimen>> fetchAvailable(int formId);

  Future<Specimen> fetchSpecimen(int specimenId);

  Future<Specimen> create(SpecimenDraft draft);

  /// Edita o specimen; a forma não muda.
  Future<Specimen> update(int specimenId, SpecimenDraft draft);

  /// Liberta (apaga) o specimen. Se estava depositado, o slot fica faltante.
  Future<void> release(int specimenId);

  Future<FormDetail> fetchForm(int formId);

  Future<SpecimenOptions> fetchOptions();

  Future<List<Trainer>> fetchTrainers();
}
