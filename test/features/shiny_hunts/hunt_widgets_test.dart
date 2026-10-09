import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_hunt_repository.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../helpers/helpers.dart';

final _now = DateTime(2026, 10, 9, 12);

const _methods = [
  ShinyMethod(id: 'sr', label: 'Soft reset', units: ['resets'], versions: {}),
  ShinyMethod(
    id: 'random',
    label: 'Encontro aleatório',
    units: ['encounters', 'hours'],
    versions: {},
  ),
];

/// Falha a primeira leitura e as gravações.
class _Failing implements ShinyHuntRepository {
  bool failRead = true;

  @override
  Future<List<ShinyHunt>> fetchShinyHunts() async {
    if (failRead) {
      failRead = false;
      throw const NetworkFailure();
    }
    return const [];
  }

  @override
  Future<ShinyHunt> saveShinyHunt(ShinyHunt hunt) async =>
      throw const ServerFailure();

  @override
  Future<void> deleteShinyHunt(int huntId) async => throw const ServerFailure();
}

void main() {
  late FakeBackend backend;
  late int saveId;

  setUp(() async {
    backend = FakeBackend.seeded();
    final ot = backend.addTrainer(
      name: 'Ash',
      trainerId: '1',
      version: 'scarlet',
    );
    saveId = (await backend.createSave(trainerId: ot)).id;
    final sword = backend.addTrainer(
      name: 'Ash',
      trainerId: '2',
      version: 'sword',
    );
    await backend.createSave(trainerId: sword);
  });

  Future<ShinyHunt> add(ShinyHunt hunt) => backend.saveShinyHunt(hunt);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ShinyHuntRepository? hunts,
  }) => pumpWidgetApp(
    tester,
    child,
    size: const Size(420, 2400),
    hunts: hunts ?? backend,
    overrides: [
      fakeBackendProvider.overrideWithValue(backend),
      clockProvider.overrideWithValue(() => _now),
      shinyMethodsProvider.overrideWithValue((_, {fromGo = false}) => _methods),
      // Nenhuma forma pode ser caçada em Sword.
      huntableInProvider.overrideWithValue((_, version) => version != 'sword'),
    ],
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Finder inCard(int id, Finder finder) => find.descendant(
    of: find.byKey(ValueKey('hunt-card-$id')),
    matching: finder,
  );

  Future<ShinyHunt> hunt(int id) async =>
      (await backend.fetchShinyHunts()).firstWhere((h) => h.id == id);

  testWidgets('em andamento: contador, cronômetro, bloqueio e menu', (
    tester,
  ) async {
    final counter = await add(
      ShinyHunt(
        id: 0,
        form: 1,
        save: saveId,
        method: 'random',
        count: 10,
        startedAt: DateTime(2026, 9),
      ),
    );
    final running = await add(
      ShinyHunt(
        id: 0,
        form: 2,
        unit: 'hours',
        runningSince: _now.subtract(const Duration(hours: 1)),
      ),
    );
    final timed = await add(const ShinyHunt(id: 0, form: 3, unit: 'hours'));
    await pump(tester, const Scaffold(body: HuntCards(paused: false)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hunt-running-banner')), findsOne);
    expect(find.text('Scarlet · Encontro aleatório'), findsOne);
    expect(find.textContaining('sem data de início'), findsWidgets);
    // Bloqueado pelo cronômetro do Ivysaur.
    final plus = inCard(counter.id, find.widgetWithText(FilledButton, '1'));
    expect(tester.widget<FilledButton>(plus).onPressed, isNull);
    expect(find.text('1 h 00 min'), findsOne);
    await tester.pump(const Duration(seconds: 30));

    await tap(tester, inCard(running.id, find.text('Parar')));
    expect((await hunt(running.id)).running, isFalse);
    expect(find.byKey(const ValueKey('hunt-running-banner')), findsNothing);

    await tap(tester, plus);
    expect((await hunt(counter.id)).count, 11);
    await tap(tester, inCard(counter.id, find.byTooltip('Menos um')));
    expect((await hunt(counter.id)).count, 10);
    await tap(
      tester,
      inCard(counter.id, find.byKey(const ValueKey('hunt-count'))),
    );
    await tester.enterText(
      find.byKey(const ValueKey('hunt-count-input')),
      '25',
    );
    await tap(tester, find.text('OK'));
    expect((await hunt(counter.id)).count, 25);
    await tap(
      tester,
      inCard(counter.id, find.byKey(const ValueKey('hunt-count'))),
    );
    await tap(tester, find.text('Cancelar'));
    expect((await hunt(counter.id)).count, 25);

    await tap(tester, inCard(timed.id, find.text('Iniciar')));
    expect((await hunt(timed.id)).running, isTrue);

    // Menu: Editar abre a folha; Desistir pausa.
    await tap(tester, inCard(counter.id, find.byTooltip('Mais ações')));
    await tap(tester, find.text('Editar'));
    expect(find.text('Editar caçada'), findsOne);
    await tap(tester, find.text('Salvar'));
    await tap(tester, inCard(counter.id, find.byTooltip('Mais ações')));
    await tap(tester, find.text('Desistir (pausar)'));
    expect((await hunt(counter.id)).paused, isTrue);

    // Encontrei!: o cadastro preenchido; salvar apaga a caçada.
    await tap(tester, inCard(timed.id, find.byTooltip('Mais ações')));
    await tap(tester, find.text('Encontrei!'));
    expect(find.text('Registro da caçada'), findsOne);
    await tap(tester, find.text('Salvar'));
    expect((await backend.fetchShinyHunts()).map((h) => h.id), [
      counter.id,
      running.id,
    ]);
  });

  testWidgets('pausadas: retomar e excluir com confirmação', (tester) async {
    final paused = await add(
      ShinyHunt(
        id: 0,
        form: 1,
        paused: true,
        count: 5,
        unit: 'resets',
        pausedAt: DateTime(2026, 9, 20),
        startedAt: DateTime(2026, 9),
      ),
    );
    final other = await add(
      ShinyHunt(id: 0, form: 2, paused: true, pausedAt: DateTime(2026, 9, 2)),
    );
    await pump(tester, const Scaffold(body: HuntCards(paused: true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('pausada em'), findsNWidgets(2));
    expect(find.text('5 resets'), findsOne);

    await tap(tester, inCard(paused.id, find.text('Excluir')));
    await tap(tester, find.text('Cancelar'));
    expect(await backend.fetchShinyHunts(), hasLength(2));
    await tap(tester, inCard(paused.id, find.text('Excluir')));
    await tap(tester, find.widgetWithText(FilledButton, 'Excluir'));
    expect(await backend.fetchShinyHunts(), hasLength(1));

    await tap(tester, inCard(other.id, find.text('Retomar')));
    expect((await hunt(other.id)).paused, isFalse);
    expect(find.textContaining('Nenhuma caçada pausada'), findsOne);
  });

  testWidgets('vazia, erro com retry e falha ao gravar', (tester) async {
    final failing = _Failing();
    await pump(
      tester,
      const Scaffold(body: HuntCards(paused: false)),
      hunts: failing,
    );
    await tester.pumpAndSettle();
    expect(find.text(const NetworkFailure().message), findsOne);
    await tap(tester, find.text('Tentar novamente'));
    expect(find.textContaining('Nenhuma caçada em andamento'), findsOne);
  });

  testWidgets('começar: escolhe forma, jogo, método, unidade e início', (
    tester,
  ) async {
    await pump(tester, const Scaffold(floatingActionButton: StartHuntButton()));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Começar caçada'));
    await tester.enterText(find.byType(TextField).last, 'ivysaur');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('form-2')));
    expect(find.text('Começar caçada'), findsWidgets);

    await tap(tester, find.byKey(const ValueKey('field-hunt-save')));
    // Só os saves de jogos onde a forma pode ser caçada.
    expect(find.textContaining('Sword'), findsNothing);
    await tap(tester, find.textContaining('Scarlet').last);
    // Encontro aleatório aceita a unidade padrão (encontros): ela fica.
    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('Encontro aleatório').last);
    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('Soft reset').last);
    expect(find.text('resets'), findsOne);
    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('Encontro aleatório').last);
    await tap(tester, find.text('horas'));
    await tap(tester, find.byTooltip('Limpar o início'));
    expect(find.text('Opcional; dá para preencher depois'), findsOne);
    await tap(tester, find.text('Início'));
    await tap(tester, find.text('Cancelar'));
    await tap(tester, find.text('Início'));
    await tap(tester, find.text('OK'));
    await tap(tester, find.text('Começar'));
    final created = (await backend.fetchShinyHunts()).single;
    expect(created.form, 2);
    expect(created.save, saveId);
    expect(created.method, 'random');
    expect(created.unit, 'hours');
    expect(created.startedAt, DateTime(2026, 10, 9));

    // Com um cronômetro rodando, não começa outra: o botão some.
    await backend.saveShinyHunt(created.copyWith(runningSince: _now));
    await tester.pumpWidget(const SizedBox());
    await pump(tester, const Scaffold(floatingActionButton: StartHuntButton()));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('editar: trocar o início confirma; falha ao gravar', (
    tester,
  ) async {
    await add(
      ShinyHunt(id: 0, form: 1, startedAt: DateTime(2026, 9), count: 3),
    );
    await pump(tester, const Scaffold(body: HuntCards(paused: false)));
    await tester.pumpAndSettle();
    Future<void> editStart() async {
      await tap(tester, find.byTooltip('Mais ações'));
      await tap(tester, find.text('Editar'));
      await tap(tester, find.text('Início'));
      await tap(tester, find.text('2'));
      await tap(tester, find.text('OK'));
      await tap(tester, find.text('Salvar'));
    }

    await editStart();
    expect(find.text('Trocar a data de início?'), findsOne);
    await tap(tester, find.text('Cancelar'));
    expect(find.text('Editar caçada'), findsOne);
    await tap(tester, find.text('Salvar'));
    await tap(tester, find.text('Trocar'));
    expect((await backend.fetchShinyHunts()).single.startedAt?.day, 2);

    // Gravação recusada: a mensagem fica na folha.
    final failing = _Failing()..failRead = false;
    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => startHuntFromPicker(context),
            child: const Text('abrir'),
          ),
        ),
      ),
      hunts: failing,
    );
    await tap(tester, find.text('abrir'));
    await tester.enterText(find.byType(TextField).last, 'ivysaur');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('form-2')));
    await tap(tester, find.text('Começar'));
    expect(find.text(const ServerFailure().message), findsOne);
  });

  testWidgets('falha numa ação do cartão vira mensagem', (tester) async {
    await add(const ShinyHunt(id: 0, form: 1));
    final failing = _FailingSaves(backend);
    await pump(
      tester,
      const Scaffold(body: HuntCards(paused: false)),
      hunts: failing,
    );
    await tester.pumpAndSettle();
    await tap(tester, find.widgetWithText(FilledButton, '1'));
    expect(find.text(const ServerFailure().message), findsOne);
  });
}

/// Lê do [backend], mas recusa gravar.
class _FailingSaves implements ShinyHuntRepository {
  _FailingSaves(this.backend);

  final FakeBackend backend;

  @override
  Future<List<ShinyHunt>> fetchShinyHunts() => backend.fetchShinyHunts();

  @override
  Future<ShinyHunt> saveShinyHunt(ShinyHunt hunt) async =>
      throw const ServerFailure();

  @override
  Future<void> deleteShinyHunt(int huntId) => backend.deleteShinyHunt(huntId);
}
