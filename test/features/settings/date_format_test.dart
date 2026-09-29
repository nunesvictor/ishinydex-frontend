import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ishinydex/features/settings/data/date_format_storage.dart';
import 'package:ishinydex/features/settings/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  final today = DateTime(2026, 9, 29);

  group('CaptureDatePattern', () {
    test('HOME: mm/dd/aaaa', () {
      final home = CaptureDatePattern(CaptureDateFormat.home, 'pt_BR');
      expect(home.hint, 'mm/dd/aaaa');
      expect(home.format(DateTime(2024, 9, 3)), '09/03/2024');
      expect(
        home.parse('09/23/2024', today: today).date,
        DateTime(2024, 9, 23),
      );
    });

    test('localização pt-BR: dd/mm/aaaa', () {
      final local = CaptureDatePattern(CaptureDateFormat.locale, 'pt_BR');
      expect(local.hint, 'dd/mm/aaaa');
      expect(local.format(DateTime(2024, 9, 23)), '23/09/2024');
      expect(
        local.parse(' 23/09/2024 ', today: today).date,
        DateTime(2024, 9, 23),
      );
    });

    test('vazio, inválido, antigo demais e no futuro', () {
      final home = CaptureDatePattern(CaptureDateFormat.home, 'pt_BR');
      expect(home.parse('  ', today: today), (date: null, error: null));
      // 23/09 não existe como mês/dia no formato HOME.
      expect(
        home.parse('23/09/2024', today: today).error,
        contains('inválida'),
      );
      expect(
        home.parse('01/01/1990', today: today).error,
        contains('inválida'),
      );
      expect(home.parse('10/01/2026', today: today).error, 'Data no futuro');
      expect(home.parse('09/29/2026', today: today).date, today);
      // Sem `today`, compara com agora.
      expect(home.parse('01/01/2100').error, 'Data no futuro');
    });
  });

  group('armazenamento e preferência', () {
    test('PrefsDateFormatStorage grava e lê', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PrefsDateFormatStorage();
      expect(await storage.read(), isNull);
      await storage.write(CaptureDateFormat.locale);
      expect(await storage.read(), CaptureDateFormat.locale);
    });

    test('provider padrão usa shared_preferences', () {
      expect(
        createContainer().read(dateFormatStorageProvider),
        isA<PrefsDateFormatStorage>(),
      );
    });

    test('padrão HOME; a escolha é guardada', () async {
      final storage = InMemoryDateFormatStorage();
      final container = createContainer(
        overrides: [dateFormatStorageProvider.overrideWithValue(storage)],
      );
      expect(
        await container.read(captureDateFormatProvider.future),
        CaptureDateFormat.home,
      );
      await container
          .read(captureDateFormatProvider.notifier)
          .choose(CaptureDateFormat.locale);
      expect(
        container.read(captureDateFormatProvider).value,
        CaptureDateFormat.locale,
      );
      expect(await storage.read(), CaptureDateFormat.locale);
    });
  });
}
