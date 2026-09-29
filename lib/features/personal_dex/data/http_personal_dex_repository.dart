import 'package:dio/dio.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';

class HttpPersonalDexRepository implements PersonalDexRepository {
  HttpPersonalDexRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<PersonalDex>> fetchDexes() => guardRequest(() async {
    final dexes = <PersonalDex>[];
    var page = 1;
    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        'personal-dexes/',
        queryParameters: {'page': page, 'page_size': 100},
      );
      final result = Paginated.fromJson(response.data!, PersonalDex.fromJson);
      dexes.addAll(result.results);
      if (!result.hasNext) return dexes;
      page++;
    }
  });

  @override
  Future<PersonalDex> fetchDex(int dexId) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'personal-dexes/$dexId/',
    );
    return PersonalDex.fromJson(response.data!);
  });

  @override
  Future<List<BoxSummary>> fetchBoxes(int dexId) => guardRequest(() async {
    final response = await _dio.get<List<dynamic>>(
      'personal-dexes/$dexId/boxes/',
    );
    return [
      for (final item in response.data!)
        BoxSummary.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<List<Slot>> fetchSlots({required int dexId, required int boxId}) =>
      guardRequest(() async {
        final response = await _dio.get<List<dynamic>>(
          'slots/',
          queryParameters: {'personal_dex': dexId, 'box': boxId},
        );
        return [
          for (final item in response.data!)
            Slot.fromJson(item as Map<String, dynamic>),
        ];
      });

  @override
  Future<Slot> deposit({required int slotId, required int specimenId}) =>
      guardRequest(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          'slots/$slotId/deposit/',
          data: {'specimen_id': specimenId},
        );
        return Slot.fromJson(response.data!);
      });
}
