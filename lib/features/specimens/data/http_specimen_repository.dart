import 'package:dio/dio.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/specimen_repository.dart';

class HttpSpecimenRepository implements SpecimenRepository {
  HttpSpecimenRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Specimen>> fetchAvailable(int formId) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'specimens/',
      queryParameters: {'form_id': formId, 'available': true, 'page_size': 100},
    );
    return Paginated.fromJson(response.data!, Specimen.fromJson).results;
  });

  @override
  Future<Specimen> fetchSpecimen(int specimenId) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'specimens/$specimenId/',
    );
    return Specimen.fromJson(response.data!);
  });

  @override
  Future<Specimen> update(int specimenId, SpecimenDraft draft) =>
      guardRequest(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          'specimens/$specimenId/',
          data: draft.toUpdateJson(),
        );
        return Specimen.fromJson(response.data!);
      });

  @override
  Future<void> release(int specimenId) => guardRequest(() async {
    await _dio.delete<void>('specimens/$specimenId/');
  });

  @override
  Future<Specimen> create(SpecimenDraft draft) => guardRequest(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      'specimens/',
      data: draft.toRequestJson(),
    );
    return Specimen.fromJson(response.data!);
  });

  @override
  Future<FormDetail> fetchForm(int formId) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>('forms/$formId/');
    return FormDetail.fromJson(response.data!);
  });

  @override
  Future<SpecimenOptions> fetchOptions() => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>('specimens/options/');
    return SpecimenOptions.fromJson(response.data!);
  });

  @override
  Future<List<Trainer>> fetchTrainers() => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'trainers/',
      queryParameters: {'page_size': 100},
    );
    return Paginated.fromJson(response.data!, Trainer.fromJson).results;
  });
}
