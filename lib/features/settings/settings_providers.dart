import 'package:intl/intl.dart';

/// Formatação e leitura da data de captura, sempre no formato do idioma do
/// app (#208): a mesma do seletor de data.
class CaptureDatePattern {
  CaptureDatePattern(String locale) : _format = DateFormat.yMd(locale);

  final DateFormat _format;

  /// Primeiro ano aceito (o mesmo do calendário do formulário).
  static const firstYear = 1996;

  String format(DateTime date) => _format.format(date);

  /// Texto de ajuda: `dd/MM/y` → `dd/mm/aaaa`; `M/d/y` → `M/d/aaaa`.
  String get hint =>
      _format.pattern!.replaceAll('MM', 'mm').replaceAll(RegExp('y+'), 'aaaa');

  /// Lê o texto digitado. Retorna a data, ou uma mensagem de erro.
  ({DateTime? date, String? error}) parse(String text, {DateTime? today}) {
    final value = text.trim();
    if (value.isEmpty) return (date: null, error: null);
    final DateTime date;
    try {
      date = _format.parseStrict(value);
    } on FormatException {
      return (date: null, error: 'Data inválida ($hint)');
    }
    if (date.year < firstYear) {
      return (date: null, error: 'Data inválida ($hint)');
    }
    final now = today ?? DateTime.now();
    if (date.isAfter(DateTime(now.year, now.month, now.day))) {
      return (date: null, error: 'Data no futuro');
    }
    return (date: date, error: null);
  }
}
