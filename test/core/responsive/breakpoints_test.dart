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
    expect(WindowSize.fromWidth(1439), WindowSize.expanded);
    expect(WindowSize.fromWidth(1440), WindowSize.large);
    expect(WindowSize.compact.isCompact, true);
    expect(WindowSize.medium.isCompact, false);
    // "Expandido" inclui o large; "large" só ele.
    expect(WindowSize.expanded.isExpanded, true);
    expect(WindowSize.large.isExpanded, true);
    expect(WindowSize.medium.isExpanded, false);
    expect(WindowSize.large.isLarge, true);
    expect(WindowSize.expanded.isLarge, false);
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

  test('isDesktopPlatform: só Linux, macOS e Windows', () {
    expect(TargetPlatform.values.where(isDesktopPlatform), [
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]);
  });
}
