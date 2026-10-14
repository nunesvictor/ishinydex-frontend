import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';

void main() {
  test('NotFoundFailure e DataFailure: um problema', () {
    expect(const NotFoundFailure().problems, [const Problem.notFound()]);
    expect(const DataFailure(Problem.notADataFile()).problems, [
      const Problem.notADataFile(),
    ]);
  });

  group('ValidationFailure', () {
    test('erros por campo', () {
      const failure = ValidationFailure({
        'name': [Problem.blank()],
        ValidationFailure.nonFieldKey: [Problem.slotWithoutForm()],
      });
      expect(failure.errorsFor('name'), [const Problem.blank()]);
      expect(failure.errorsFor('nada'), isNull);
      expect(failure.problems, [
        const Problem.blank(),
        const Problem.slotWithoutForm(),
      ]);
    });

    test('o detail vence os campos', () {
      const failure = ValidationFailure({
        'name': [Problem.blank()],
      }, detail: Problem.saveHasSpecimens());
      expect(failure.problems, [const Problem.saveHasSpecimens()]);
    });

    test('sem nada: dados inválidos', () {
      expect(const ValidationFailure({}).problems, [
        const Problem.invalidData(),
      ]);
    });
  });

  test('toString lista os problemas (para os logs)', () {
    const failure = ValidationFailure({
      'a': [Problem.blank(), Problem.emptyList()],
    });
    expect('$failure', 'Problem.blank()\nProblem.emptyList()');
  });
}
