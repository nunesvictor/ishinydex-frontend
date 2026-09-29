import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/generation_progress.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

const _box = BoxRef(id: 1, name: 'HOME 1', position: 1);

void main() {
  late MockPersonalDexRepository repository;

  setUp(() => repository = MockPersonalDexRepository());

  Future<void> pump(WidgetTester tester, {Size size = compactSize}) async {
    await pumpWidgetApp(
      tester,
      const Scaffold(body: GenerationProgressView(dexId: 1)),
      size: size,
      overrides: [personalDexRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
  }

  for (final size in [compactSize, expandedSize]) {
    testWidgets('uma linha por geração (${size.width.toInt()}px)', (
      tester,
    ) async {
      when(() => repository.fetchGenerations(1)).thenAnswer(
        (_) async => const [
          GenerationProgress(
            generation: 'generation-i',
            total: 151,
            registered: 151,
            firstBox: _box,
          ),
          GenerationProgress(
            generation: null,
            total: 3,
            registered: 1,
            firstBox: _box,
          ),
        ],
      );
      await pump(tester, size: size);
      expect(find.text('Geração I'), findsOneWidget);
      expect(find.text('Completa!'), findsOneWidget);
      expect(find.text('151/151 (100%)'), findsOneWidget);
      expect(find.text('Outras formas'), findsOneWidget);
      expect(find.text('Faltam 2'), findsOneWidget);
    });
  }

  testWidgets('vazio e erro com retry', (tester) async {
    var calls = 0;
    when(() => repository.fetchGenerations(1)).thenAnswer((_) async {
      if (calls++ == 0) throw const ServerFailure();
      return const [];
    });
    await pump(tester);
    expect(find.text(const ServerFailure().message), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Este dex ainda não tem formas nas boxes.'),
      findsOneWidget,
    );
  });
}
