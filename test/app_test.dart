import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/app.dart';

void main() {
  test('construtor do app registrado na cobertura', () {
    // Os testes usam `const IShinyDexApp()`, criado em tempo de compilação:
    // a cobertura às vezes não marca a linha do construtor (no CI, 99.97%).
    // Instanciar sem const garante que ela execute.
    // ignore: prefer_const_constructors
    expect(IShinyDexApp(), isA<ConsumerWidget>());
  });

  test('noRetry desliga o retry automático', () {
    expect(noRetry(0, Exception()), isNull);
  });
}
