import 'package:dio/dio.dart';

/// Adiciona o token DRF às requisições e avisa quando a API responde 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.readToken, required this.onUnauthorized});

  final String? Function() readToken;
  final void Function() onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = readToken();
    if (token != null) options.headers['Authorization'] = 'Token $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) onUnauthorized();
    handler.next(err);
  }
}

Dio createDio({
  required String baseUrl,
  required String? Function() readToken,
  required void Function() onUnauthorized,
}) {
  final normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  return Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    )
    ..interceptors.add(
      AuthInterceptor(readToken: readToken, onUnauthorized: onUnauthorized),
    );
}
