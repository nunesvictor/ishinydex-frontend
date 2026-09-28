import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';

DioException _error(int? status, [Object? data]) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  group('mapDioException', () {
    test('sem resposta vira NetworkFailure', () {
      expect(mapDioException(_error(null)), isA<NetworkFailure>());
    });

    test('401, 404 e 5xx', () {
      expect(mapDioException(_error(401)), isA<UnauthorizedFailure>());
      expect(mapDioException(_error(404)), isA<NotFoundFailure>());
      expect(mapDioException(_error(503)), isA<ServerFailure>());
    });

    test('status sem código conhecido vira ServerFailure', () {
      expect(mapDioException(_error(302)), isA<ServerFailure>());
    });

    test('400 com erros por campo', () {
      final failure = mapDioException(
        _error(400, {
          'specimen_id': ['Forma diferente.'],
          'non_field_errors': ['Slot sem forma.'],
          'count': 3,
        }),
      ) as ValidationFailure;
      expect(failure.errorFor('specimen_id'), 'Forma diferente.');
      expect(failure.errorFor('non_field_errors'), 'Slot sem forma.');
      expect(failure.errorFor('count'), '3');
      expect(failure.errorFor('nada'), isNull);
      expect(failure.message, 'Forma diferente.\nSlot sem forma.\n3');
    });

    test('400 com detail usa a mensagem do detail', () {
      final failure = mapDioException(
        _error(400, {'detail': 'Depositado.'}),
      ) as ValidationFailure;
      expect(failure.message, 'Depositado.');
      expect(failure.fieldErrors, isEmpty);
    });

    test('400 sem corpo em mapa', () {
      final failure = mapDioException(_error(400, 'oops')) as ValidationFailure;
      expect(failure.message, 'Dados inválidos.');
    });
  });

  test('toString devolve a mensagem', () {
    expect(const NetworkFailure().toString(), contains('conectar'));
  });

  group('guardRequest', () {
    test('repassa o valor', () async {
      expect(await guardRequest(() async => 1), 1);
    });

    test('converte DioException', () {
      expect(
        guardRequest<int>(() async => throw _error(404)),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
