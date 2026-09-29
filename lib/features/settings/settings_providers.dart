import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/features/settings/data/date_format_storage.dart';

final dateFormatStorageProvider = Provider<DateFormatStorage>(
  (ref) => PrefsDateFormatStorage(),
);

/// Formato escolhido nos Ajustes; `home` enquanto não houver escolha.
final captureDateFormatProvider =
    AsyncNotifierProvider<CaptureDateFormatController, CaptureDateFormat>(
      CaptureDateFormatController.new,
    );

class CaptureDateFormatController extends AsyncNotifier<CaptureDateFormat> {
  @override
  Future<CaptureDateFormat> build() async =>
      await ref.read(dateFormatStorageProvider).read() ??
      CaptureDateFormat.home;

  Future<void> choose(CaptureDateFormat format) async {
    state = AsyncData(format);
    await ref.read(dateFormatStorageProvider).write(format);
  }
}

/// Formatação e leitura da data de captura no formato escolhido.
class CaptureDatePattern {
  CaptureDatePattern(CaptureDateFormat format, String locale)
    : _format = switch (format) {
        CaptureDateFormat.home => DateFormat('MM/dd/yyyy'),
        CaptureDateFormat.locale => DateFormat.yMd(locale),
      };

  final DateFormat _format;

  /// Primeiro ano aceito (o mesmo do calendário do formulário).
  static const firstYear = 1996;

  String format(DateTime date) => _format.format(date);

  /// Texto de ajuda: `MM/dd/yyyy` → `mm/dd/aaaa`; `dd/MM/y` → `dd/mm/aaaa`.
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
