import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/shiny_locks/data/http_shiny_lock_repository.dart';
import 'package:ishinydex/features/shiny_locks/shiny_lock_providers.dart';

import '../../helpers/helpers.dart';

void main() {
  test('repositório HTTP quando USE_FAKE_API=false', () {
    final container = createContainer(
      overrides: [
        envProvider.overrideWithValue(
          const Env(apiBaseUrl: 'http://x/api', useFakeApi: false),
        ),
      ],
    );
    expect(
      container.read(shinyLockRepositoryProvider),
      isA<HttpShinyLockRepository>(),
    );
  });
}
