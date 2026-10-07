import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

void main() {
  test('com o catálogo, a regra dele; sem, sempre serve', () {
    final catalog = Catalog.fromJson(
      catalogJson(),
      spriteBase: Env.defaultSpritesBaseUrl,
    );
    final withCatalog = createContainer(
      overrides: [
        fakeBackendProvider.overrideWithValue(FakeBackend.fromCatalog(catalog)),
      ],
    );
    expect(
      withCatalog.read(originFitsProvider)(196, 'brilliant-diamond'),
      isFalse,
    );

    final seeded = createContainer(
      overrides: [fakeBackendProvider.overrideWithValue(FakeBackend.seeded())],
    );
    expect(seeded.read(originFitsProvider)(196, 'brilliant-diamond'), isTrue);
  });
}
