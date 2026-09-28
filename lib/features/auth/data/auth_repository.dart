import 'package:dio/dio.dart';
import 'package:ishinydex/core/network/app_failure.dart';

abstract interface class AuthRepository {
  /// Troca usuário e senha por um token DRF.
  Future<String> login({required String username, required String password});
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<String> login({required String username, required String password}) =>
      guardRequest(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          'auth/token/',
          data: {'username': username, 'password': password},
        );
        return response.data!['token'] as String;
      });
}
