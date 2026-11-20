import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

void main() {
  test('idioma do save (#411): grava, volta pelos registros e apaga', () async {
    final backend = FakeBackend.seeded();
    final save = await backend.updateSave(1, language: const SetTo('en'));
    expect(save.language, 'en');
    // O resto fica como estava; sem idioma, o registro fica como antes.
    expect(save.label, 'Switch');
    expect(
      backend.records['saves']!.firstWhere((s) => s['id'] == 1)['language'],
      'en',
    );
    expect(
      backend.records['saves']!.firstWhere((s) => s['id'] == 2),
      isNot(contains('language')),
    );

    // Ida e volta: um arquivo com o idioma, lido de novo.
    final copy = FakeBackend.seeded()..replaceRecords(backend.records);
    expect(
      (await copy.fetchSaves()).firstWhere((s) => s.id == 1).language,
      'en',
    );

    // Mudar só o apelido não mexe no idioma; SetTo(null) o apaga.
    expect((await backend.updateSave(1, label: 'OLED')).language, 'en');
    expect(
      (await backend.updateSave(1, language: const SetTo(null))).language,
      isNull,
    );
  });
}
