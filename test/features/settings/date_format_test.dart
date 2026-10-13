import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ishinydex/features/settings/settings_providers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  final today = DateTime(2026, 9, 29);

  group('CaptureDatePattern: o formato do idioma (#208)', () {
    test('pt-BR: dd/mm/aaaa', () {
      final local = CaptureDatePattern('pt_BR');
      expect(local.hint, 'dd/mm/aaaa');
      expect(local.format(DateTime(2024, 9, 23)), '23/09/2024');
      expect(
        local.parse(' 23/09/2024 ', today: today).date,
        DateTime(2024, 9, 23),
      );
    });

    test('vazio, inválido, antigo demais e no futuro', () {
      final local = CaptureDatePattern('pt_BR');
      expect(local.parse('  ', today: today), (date: null, error: null));
      // 09/23 não existe como dia/mês.
      expect(
        local.parse('09/23/2024', today: today).error,
        contains('inválida'),
      );
      expect(
        local.parse('01/01/1990', today: today).error,
        contains('inválida'),
      );
      expect(local.parse('01/10/2026', today: today).error, 'Data no futuro');
      expect(local.parse('29/09/2026', today: today).date, today);
      // Sem `today`, compara com agora.
      expect(local.parse('01/01/2100').error, 'Data no futuro');
    });
  });
}
