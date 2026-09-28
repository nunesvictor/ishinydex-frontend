import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';

import '../../helpers/helpers.dart';

void main() {
  test('fromWidth', () {
    expect(WindowSize.fromWidth(599), WindowSize.compact);
    expect(WindowSize.fromWidth(600), WindowSize.medium);
    expect(WindowSize.fromWidth(1023), WindowSize.medium);
    expect(WindowSize.fromWidth(1024), WindowSize.expanded);
    expect(WindowSize.compact.isCompact, true);
    expect(WindowSize.medium.isCompact, false);
    expect(WindowSize.expanded.isExpanded, true);
  });

  testWidgets('of usa a largura da tela', (tester) async {
    WindowSize? size;
    await pumpWidgetApp(
      tester,
      Builder(
        builder: (context) {
          size = WindowSize.of(context);
          return const SizedBox();
        },
      ),
      size: mediumSize,
    );
    expect(size, WindowSize.medium);
  });
}
