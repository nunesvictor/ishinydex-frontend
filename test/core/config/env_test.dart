import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';

void main() {
  test('valores padrão sem --dart-define', () {
    final env = ProviderContainer().read(envProvider);
    expect(env.apiBaseUrl, 'http://localhost:8008/api');
    expect(env.useFakeApi, false);
  });
}
