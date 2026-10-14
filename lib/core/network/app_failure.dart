import 'package:ishinydex/core/l10n/problem.dart';

export 'package:ishinydex/core/l10n/problem.dart';

/// Falha de domínio exibível ao usuário: os [problems] que a tela traduz
/// (`context.failureText`).
sealed class AppFailure implements Exception {
  const AppFailure();

  /// O que mostrar, sem campo: um ou mais problemas.
  List<Problem> get problems;

  @override
  String toString() => problems.join('\n');
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure();

  @override
  List<Problem> get problems => const [Problem.notFound()];
}

/// Um arquivo (de dados ou o catálogo) que o app não lê, pelo [problem].
class DataFailure extends AppFailure {
  const DataFailure(this.problem);

  final Problem problem;

  @override
  List<Problem> get problems => [problem];
}

/// Erros de validação: `{campo: [problemas]}` ou um [detail] geral.
class ValidationFailure extends AppFailure {
  const ValidationFailure(this.fieldErrors, {this.detail});

  static const nonFieldKey = 'non_field_errors';

  final Map<String, List<Problem>> fieldErrors;
  final Problem? detail;

  /// Os problemas do campo [field], se houver.
  List<Problem>? errorsFor(String field) => fieldErrors[field];

  @override
  List<Problem> get problems {
    if (detail case final detail?) return [detail];
    final all = [for (final list in fieldErrors.values) ...list];
    return all.isEmpty ? const [Problem.invalidData()] : all;
  }
}
