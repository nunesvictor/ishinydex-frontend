import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/paginated.dart';

void main() {
  test('lê o formato do DRF', () {
    final page = Paginated.fromJson({
      'count': 2,
      'next': 'http://x/?page=2',
      'previous': null,
      'results': [
        {'v': 1},
        {'v': 2},
      ],
    }, (json) => json['v'] as int);
    expect(page.count, 2);
    expect(page.results, [1, 2]);
    expect(page.hasNext, true);
    expect(
      Paginated.fromJson({
        'count': 0,
        'next': null,
        'results': <dynamic>[],
      }, (json) => json).hasNext,
      false,
    );
  });
}
