import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/clock.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';
import 'package:ishinydex/features/specimens/domain/home_cutoff.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/home_cutoff_notice.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

final _until = DateTime.utc(2027, 2, 26, 3);
final _before = DateTime(2026, 10, 13, 12);
final _closing = DateTime(2027, 2, 14, 12);
final _after = DateTime(2027, 3, 1, 12);

class _MemoryNotice implements HomeNoticeStorage {
  String? day;

  @override
  Future<String?> read() async => day;

  @override
  Future<void> write(String value) async => day = value;
}

Catalog _catalog() {
  final json = catalogJson();
  return Catalog.fromJson({
    ...json,
    'versions': [
      for (final v in json['versions'] as List)
        if ((v as Map<String, dynamic>)['name'] == 'x')
          {...v, 'homeUntil': '2027-02-26T03:00:00Z'}
        else
          v,
    ],
  }, spriteBase: Env.defaultSpritesBaseUrl);
}

void main() {
  test('HomeCutoff: antes, últimos 30 dias e depois', () {
    final before = HomeCutoff(until: _until, now: _before);
    expect((before.passed, before.closing), (false, false));
    final closing = HomeCutoff(until: _until, now: _closing);
    expect(
      (closing.passed, closing.closing, closing.daysLeft),
      (false, true, 11),
    );
    final after = HomeCutoff(until: _until, now: _after);
    expect((after.passed, after.closing), (true, false));
  });

  test('catálogo e provider: a data de corte do jogo', () {
    final catalog = _catalog();
    expect(catalog.homeCutoffs, {'x': _until});
    final container = createContainer(
      overrides: [
        fakeBackendProvider.overrideWithValue(FakeBackend(catalog: catalog)),
        clockProvider.overrideWithValue(() => _after),
      ],
    );
    final cutoffOf = container.read(homeCutoffProvider);
    expect(cutoffOf('x')?.passed, isTrue);
    expect(cutoffOf('scarlet'), isNull);
    expect(cutoffOf(null), isNull);
    // Sem catálogo: nenhum corte.
    final plain = createContainer(
      overrides: [fakeBackendProvider.overrideWithValue(FakeBackend())],
    );
    expect(plain.read(homeCutoffProvider)('x'), isNull);
  });

  test('o dia dispensado fica no aparelho', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = createContainer().read(homeNoticeStorageProvider);
    expect(storage, isA<PrefsHomeNoticeStorage>());
    expect(await storage.read(), isNull);
    await storage.write('2027-02-14');
    expect(await storage.read(), '2027-02-14');
  });

  test('backend: depois do corte, o espécime não volta ao HOME', () async {
    final backend = FakeBackend.fromCatalog(_catalog());
    final forms = _catalog().formIds.take(2);
    final ids = [for (final id in forms) backend.addSpecimen(formId: id)];
    final x = backend.addSave(
      trainerId: backend.addTrainer(name: 'Ash', trainerId: '1', version: 'x'),
    );
    final scarlet = backend.addSave(
      trainerId: backend.addTrainer(
        name: 'Ash',
        trainerId: '2',
        version: 'scarlet',
      ),
    );
    backend
      ..moveTo(ids[0], x)
      ..moveTo(ids[1], scarlet)
      ..now = () => _before;
    expect(await backend.transfer([ids[0]], saveId: null), 1);
    backend
      ..moveTo(ids[0], x)
      ..now = () => _after;
    await expectLater(
      backend.transfer([ids[0]], saveId: null),
      throwsA(
        isA<ValidationFailure>().having(
          (f) => f.fieldErrors['save'],
          'problema',
          [const Problem.gameCutOff('X')],
        ),
      ),
    );
    // No lote, quem pode volta.
    expect(await backend.transfer(ids, saveId: null), 1);
    expect((await backend.fetchSpecimen(ids[0])).location?.id, x);
  });

  group('telas', () {
    late FakeBackend backend;
    late int specimen;
    late int xSave;
    late _MemoryNotice notice;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      notice = _MemoryNotice();
      backend = FakeBackend.seeded();
      final x = xSave = backend.addSave(
        trainerId: backend.addTrainer(
          name: 'Ash',
          trainerId: '2013',
          version: 'x',
        ),
      );
      specimen = backend.addSpecimen(formId: 1, isShiny: true);
      backend.moveTo(specimen, x);
    });

    Future<void> pump(WidgetTester tester, DateTime now, {Size? size}) =>
        pumpFullApp(
          tester,
          backend: backend,
          size: size ?? compactSize,
          overrides: [
            clockProvider.overrideWithValue(() => now),
            homeNoticeStorageProvider.overrideWithValue(notice),
            homeCutoffProvider.overrideWithValue(
              (version) => {'x', 'y'}.contains(version)
                  ? HomeCutoff(until: _until, now: now)
                  : null,
            ),
          ],
        );

    Future<void> go(WidgetTester tester, String route) async {
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(routerProvider)
          .go(route);
      await tester.pumpAndSettle();
    }

    for (final size in [compactSize, expandedSize]) {
      testWidgets('antes do corte: aviso, etiqueta e a lista Fora do HOME '
          '(${size.width.toInt()}px)', (tester) async {
        await pump(tester, _before, size: size);
        await go(tester, Routes.saves);
        expect(find.text('1 espécime em X'), findsOne);
        expect(find.text('Só envia para o HOME'), findsOne);
        expect(find.byKey(const ValueKey('home-tag')), findsOne);
        expect(find.text('HOME 26/02'), findsOne);
        expect(find.byTooltip('Chega ao HOME até 26/02/2027'), findsOne);
        await tester.tap(find.text('Ver o espécime'));
        await tester.pumpAndSettle();
        expect(find.text('Fora do HOME'), findsOne);
        // Na lista, o aviso sem o botão.
        expect(find.text('1 espécime em X'), findsOne);
        expect(find.text('Ver o espécime'), findsNothing);
        expect(find.byTooltip('Trazer de volta ao HOME'), findsWidgets);
      });
    }

    testWidgets('últimos 30 dias: aviso forte; "Entendi" esconde no dia', (
      tester,
    ) async {
      await pump(tester, _closing);
      await go(tester, Routes.saves);
      expect(find.text('Faltam 11 dias para o fim do Pokémon Bank'), findsOne);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-cutoff-notice')), findsNothing);
      expect(notice.day, '2027-02-14');
    });

    testWidgets('último dia e plural', (tester) async {
      final y = backend.addSave(
        trainerId: backend.addTrainer(
          name: 'Ash',
          trainerId: '7',
          version: 'y',
        ),
      );
      final other = backend.addSpecimen(formId: 2);
      backend.moveTo(other, y);
      await pump(tester, DateTime(2027, 2, 25, 20));
      await go(tester, Routes.saves);
      expect(find.text('Último dia do Pokémon Bank'), findsOne);
      expect(
        find.textContaining(RegExp('2 espécimes em (X e Y|Y e X) não chegam')),
        findsOne,
      );
      expect(find.text('Ver os 2 espécimes'), findsOne);
    });

    testWidgets('depois do corte: seção própria, preso, sem volta', (
      tester,
    ) async {
      await pump(tester, _after);
      await go(tester, Routes.saves);
      expect(find.text('Sem caminho para o HOME'), findsOne);
      expect(find.byKey(const ValueKey('home-cutoff-notice')), findsNothing);
      expect(find.text('Só envia para o HOME'), findsNothing);
      expect(find.byTooltip('Não chega mais ao HOME'), findsOne);

      await go(tester, Routes.away);
      expect(find.byTooltip('X não envia mais para o HOME'), findsOne);

      await go(tester, Routes.specimen(specimen));
      expect(find.byTooltip('Não chega mais ao HOME'), findsOne);
      await tapMoreAction(tester, 'Trazer de volta ao HOME');
      expect(find.text('X não envia mais para o HOME'), findsOne);
    });

    testWidgets('caçada no save do 3DS segue, com a etiqueta', (tester) async {
      await backend.saveShinyHunt(ShinyHunt(id: 0, form: 1, save: xSave));
      await pumpWidgetApp(
        tester,
        const Scaffold(body: HuntCards(paused: false)),
        hunts: backend,
        overrides: [
          fakeBackendProvider.overrideWithValue(backend),
          homeCutoffProvider.overrideWithValue(
            (version) =>
                version == 'x' ? HomeCutoff(until: _until, now: _after) : null,
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Não chega mais ao HOME'), findsOne);
      expect(find.widgetWithText(FilledButton, '1'), findsOne);
    });
  });
}
