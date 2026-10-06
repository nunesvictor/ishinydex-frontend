import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/shiny_locks/shiny_lock_providers.dart';

import '../../helpers/helpers.dart';

void main() {
  test('o repositório é o backend local', () {
    final backend = FakeBackend.seeded();
    final container = createContainer(
      overrides: [fakeBackendProvider.overrideWithValue(backend)],
    );
    expect(container.read(shinyLockRepositoryProvider), same(backend));
  });
}
