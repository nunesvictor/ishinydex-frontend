import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/format.dart';

void main() {
  test('prettifyName', () {
    expect(prettifyName('mr-mime-galar'), 'Mr Mime Galar');
    expect(prettifyName('nidoran_f'), 'Nidoran F');
    expect(prettifyName('--x'), 'X');
  });

  test('percentOf', () {
    expect(percentOf(1, 3), 33);
    expect(percentOf(5, 0), 0);
    expect(percentOf(3, 3), 100);
  });
}
