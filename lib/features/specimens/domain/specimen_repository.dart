import 'package:ishinydex/features/specimens/domain/models.dart';

abstract interface class SpecimenRepository {
  /// Specimens da forma [formId] que ainda não estão depositados.
  Future<List<Specimen>> fetchAvailable(int formId);

  Future<Specimen> create(SpecimenDraft draft);

  Future<FormDetail> fetchForm(int formId);

  Future<SpecimenOptions> fetchOptions();

  Future<List<Trainer>> fetchTrainers();
}
