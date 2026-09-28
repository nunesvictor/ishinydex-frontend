import 'package:dio/dio.dart';

/// Falha de domínio exibível ao usuário.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Não foi possível conectar ao servidor.',
  ]);
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([
    super.message = 'Sessão expirada. Entre novamente.',
  ]);
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Recurso não encontrado.']);
}

class ServerFailure extends AppFailure {
  const ServerFailure([super.message = 'Erro no servidor. Tente novamente.']);
}

/// Erros de validação do DRF: `{campo: [msgs]}` ou `{detail: msg}`.
class ValidationFailure extends AppFailure {
  ValidationFailure(this.fieldErrors, {String? detail})
    : super(detail ?? _joinMessages(fieldErrors));

  static const nonFieldKey = 'non_field_errors';

  final Map<String, List<String>> fieldErrors;

  String? errorFor(String field) => fieldErrors[field]?.join('\n');

  static String _joinMessages(Map<String, List<String>> errors) {
    final messages = errors.values.expand((m) => m).toList();
    return messages.isEmpty ? 'Dados inválidos.' : messages.join('\n');
  }
}

/// Converte uma [DioException] na [AppFailure] correspondente.
AppFailure mapDioException(DioException error) {
  final response = error.response;
  if (response == null) return const NetworkFailure();
  final status = response.statusCode ?? 0;
  final detail = _detailOf(response.data);
  if (status == 401) return const UnauthorizedFailure();
  if (status == 404) return const NotFoundFailure();
  if (status >= 500) return const ServerFailure();
  if (status >= 400) {
    return ValidationFailure(_fieldErrorsOf(response.data), detail: detail);
  }
  return const ServerFailure();
}

String? _detailOf(Object? data) {
  if (data is Map && data['detail'] is String) return data['detail'] as String;
  return null;
}

Map<String, List<String>> _fieldErrorsOf(Object? data) {
  if (data is! Map) return const {};
  return {
    for (final entry in data.entries)
      if (entry.key != 'detail')
        '${entry.key}': switch (entry.value) {
          final List<dynamic> list => [for (final item in list) '$item'],
          final Object? other => ['$other'],
        },
  };
}

/// Executa [request] convertendo [DioException] em [AppFailure].
Future<T> guardRequest<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (error) {
    throw mapDioException(error);
  }
}
