import 'package:dio/dio.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
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
  Future<Paginated<Specimen>> fetchSpecimens(
    SpecimenQuery query, {
    required int page,
    required int pageSize,
  }) => guardRequest(() async {
    final search = query.search.trim();
    final response = await _dio.get<Map<String, dynamic>>(
      'specimens/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search.isNotEmpty) 'search': search,
        'available': ?query.status.availableParam,
        if (query.shinyOnly) 'is_shiny': true,
      },
    );
    return Paginated.fromJson(response.data!, Specimen.fromJson);
  });

  @override
  Future<List<FormRef>> searchForms(String search) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'forms/',
      queryParameters: {'search': search.trim(), 'page_size': 30},
    );
    return Paginated.fromJson(response.data!, FormRef.fromJson).results;
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

  @override
  Future<Trainer> createTrainer({
    required String name,
    required String trainerId,
    String? version,
  }) => guardRequest(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      'trainers/',
      data: {'name': name, 'trainer_id': trainerId, 'version': ?version},
    );
    return Trainer.fromJson(response.data!);
  });

  @override
  Future<List<GameVersion>> fetchVersions() => guardRequest(() async {
    final response = await _dio.get<List<dynamic>>('versions/');
    return [
      for (final item in response.data!)
        GameVersion.fromJson(item as Map<String, dynamic>),
    ];
  });
}
