import 'package:dio/dio.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/domain/shiny_lock_repository.dart';

class HttpShinyLockRepository implements ShinyLockRepository {
  HttpShinyLockRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<ShinyLock>> fetchShinyLocks() => guardRequest(() async {
    final response = await _dio.get<List<dynamic>>('shiny-locks/');
    return [
      for (final json in response.data!)
        ShinyLock.fromJson(json as Map<String, dynamic>),
    ];
  });

  @override
  Future<ShinyLock> createShinyLock(ShinyLockDraft draft) =>
      guardRequest(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          'shiny-locks/',
          data: draft.toJson(),
        );
        return ShinyLock.fromJson(response.data!);
      });

  @override
  Future<ShinyLock> updateShinyLock(int id, ShinyLockDraft draft) =>
      guardRequest(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          'shiny-locks/$id/',
          data: draft.toJson(),
        );
        return ShinyLock.fromJson(response.data!);
      });

  @override
  Future<void> deleteShinyLock(int id) => guardRequest(() async {
    await _dio.delete<void>('shiny-locks/$id/');
  });
}
