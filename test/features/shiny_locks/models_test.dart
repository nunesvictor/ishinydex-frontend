import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('ShinyLock.fromJson/toJson', () {
    final lock = ShinyLock.fromJson(shinyLockJson);
    expect(lock.caption, 'Treasures of Ruin');
    expect(lock.lockType, ShinyLockType.distroOnly);
    expect(lock.description, isNull);
    expect(lock.forms.single.name, 'rattata-alola');
    expect(lock.toJson()['lock_type'], 'distro-only');

    // Tipo desconhecido: o padrão da API.
    final unknown = ShinyLock.fromJson({...shinyLockJson, 'lock_type': 'foo'});
    expect(unknown.lockType, ShinyLockType.unobtainable);
  });

  test('ShinyLockDraft: rascunho de um lock e corpo da API', () {
    final lock = ShinyLock.fromJson({
      ...shinyLockJson,
      'description': 'Só por evento.',
      'active': false,
    });
    final draft = ShinyLockDraft.of(lock);
    expect(draft.description, 'Só por evento.');
    expect(draft.active, false);
    expect(draft.copyWith(caption: '  Ruína  ').toJson(), {
      'caption': 'Ruína',
      'description': 'Só por evento.',
      'lock_type': 'distro-only',
      'active': false,
      'forms': [1218],
    });

    // Sem descrição, o rascunho fica com texto vazio.
    expect(
      ShinyLockDraft.of(ShinyLock.fromJson(shinyLockJson)).description,
      '',
    );
  });
}
