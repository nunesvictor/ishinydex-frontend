import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/away_page.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
import 'package:ishinydex/features/specimens/presentation/saves_page.dart';
import 'package:ishinydex/features/specimens/presentation/specimens_page.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

Future<void> _go(WidgetTester tester, String location) async {
  ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
      .read(routerProvider)
      .go(location);
  await tester.pumpAndSettle();
}

/// Some com o snackbar da ação anterior (ele cobre o botão flutuante).
Future<void> _dismissSnackBar(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Escolhe uma forma no seletor (busca com debounce).
Future<void> _pickForm(WidgetTester tester, String name, int id) async {
  await tester.enterText(find.byType(TextField).last, name);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('form-$id')));
  await tester.pumpAndSettle();
}

const _save = Save(
  id: 1,
  label: 'Switch',
  trainer: Trainer(id: 1, name: 'Ash', trainerId: '123456', version: 'scarlet'),
);

void main() {
  test('Save: jogo, título e há quanto tempo', () {
    expect(_save.game, 'Scarlet');
    expect(_save.title, 'Scarlet · Switch');
    expect(_save.copyWith(label: '').title, 'Scarlet · Ash (123456)');
    final today = DateTime(2026, 10, 1, 15);
    expect(awayFor(DateTime(2026, 10), today: today), 'hoje');
    expect(awayFor(DateTime(2026, 9, 30), today: today), 'há 1 dia');
    expect(awayFor(DateTime(2026, 3, 12), today: today), 'há 203 dias');
    expect(daysSince(DateTime(2026, 9, 30)), greaterThan(0));
    expect(locationLabel('99', const [_save]), 'Em save #99');
    expect(locationLabel('1', const [_save]), 'Em Scarlet · Switch');
  });

  test('AwayPage.group: por save, o que saiu há mais tempo primeiro', () {
    final za = _save.copyWith(id: 2, label: 'Z-A');
    Specimen at(int id, Save save, DateTime? since) =>
        Specimen(id: id, form: 1, location: save, locationSince: since);
    final groups = AwayPage.group([
      at(1, _save, DateTime(2026, 5)),
      at(2, za, DateTime(2026, 2)),
      at(3, _save, null),
      at(4, _save, DateTime(2026)),
    ]);
    expect(groups.map((g) => g.$1.id), [1, 2]);
    expect(groups.first.$2.map((s) => s.id), [4, 1, 3]);
  });

  testWidgets('painel do slot: enviar para jogo e trazer de volta', (
    tester,
  ) async {
    final backend = await pumpFullApp(tester);
    await _go(tester, Routes.dex(1, boxId: 1, slotId: 1));

    await tapMoreAction(tester, 'Enviar para jogo…');
    expect(find.text('Enviar para qual save?'), findsOneWidget);
    await _tap(tester, find.text('Scarlet · Switch'));
    expect(find.text('1 espécime enviado para Scarlet · Switch.'), findsOne);
    expect(find.text('Em Scarlet · Switch'), findsOneWidget);
    expect(find.byTooltip('Em Scarlet · Switch'), findsOneWidget); // selo
    expect(find.textContaining('· 1 fora'), findsOneWidget); // box
    final slot = await backend.fetchSlot(1);
    expect(slot.specimen!.location!.id, 1);

    // Desistir do diálogo não muda nada.
    await tapMoreAction(tester, 'Trazer de volta ao HOME');
    await _tap(tester, find.text('Cancelar'));
    expect(find.text('Em Scarlet · Switch'), findsOneWidget);

    await tapMoreAction(tester, 'Trazer de volta ao HOME');
    expect(find.text('Bulbasaur voltou para o HOME'), findsOneWidget);
    await _tap(tester, find.text('Voltou igual'));
    expect(find.text('1 espécime de volta ao HOME.'), findsOneWidget);
    // De volta: na folha, a ação é de novo "Enviar para jogo…".
    await _dismissSnackBar(tester);
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar para jogo…'), findsOneWidget);
    expect((await backend.fetchSlot(1)).specimen!.location, isNull);
  });

  testWidgets('detalhe: voltou evoluído (forma inválida, depois a certa)', (
    tester,
  ) async {
    final backend = await pumpFullApp(tester, size: compactSize);
    // Seed: o Ivysaur do Living Dex (slot 62) está no Scarlet.
    final id = (await backend.fetchSlot(62)).specimen!.id;
    await _go(tester, Routes.specimen(id));
    expect(find.text('Em Scarlet · Switch'), findsOneWidget);
    expect(find.textContaining('Desde '), findsOneWidget);

    // Fechar o seletor de forma não muda nada.
    await tapMoreAction(tester, 'Trazer de volta ao HOME');
    await _tap(tester, find.text('Evoluiu…'));
    await _tap(tester, find.byType(CloseButton));
    expect(find.text('Em Scarlet · Switch'), findsOneWidget);

    await tapMoreAction(tester, 'Trazer de volta ao HOME');
    await _tap(tester, find.text('Evoluiu…'));
    await _pickForm(tester, 'charmander', 4);
    expect(
      find.text('esta forma não é uma evolução do espécime.'),
      findsOneWidget,
    );
    expect((await backend.fetchSpecimen(id)).form, 2);

    await tapMoreAction(tester, 'Trazer de volta ao HOME');
    await _tap(tester, find.text('Evoluiu…'));
    await _pickForm(tester, 'venusaur', 3);
    expect(find.textContaining('Evoluiu para Venusaur'), findsOneWidget);
    final evolved = await backend.fetchSpecimen(id);
    expect((evolved.form, evolved.location, evolved.slot), (3, null, null));
    expect((await backend.fetchSlot(62)).isMissing, true);
  });

  testWidgets('sem saves: explica e abre Meus saves', (tester) async {
    final fake = FakeBackend()..addForm(id: 1, name: 'bulbasaur');
    final dex = fake.addDex(name: 'Dex');
    fake.addBox(dexId: dex, name: 'HOME 1', formIds: [1]);
    final id = fake.addSpecimen(formId: 1);
    await pumpFullApp(tester, size: compactSize, backend: fake);
    await _go(tester, Routes.specimen(id));

    await tapMoreAction(tester, 'Enviar para jogo…');
    expect(find.text('Nenhum save cadastrado'), findsOneWidget);
    await _tap(tester, find.text('Agora não'));
    expect(find.text('Nenhum save cadastrado'), findsNothing);

    await tapMoreAction(tester, 'Enviar para jogo…');
    await _tap(tester, find.text('Abrir Meus saves'));
    expect(find.widgetWithText(AppBar, 'Meus saves'), findsOneWidget);
    expect(find.textContaining('Nenhum save cadastrado.'), findsOneWidget);
  });

  group('Meus saves', () {
    Finder field(String label) => find.widgetWithText(TextField, label);

    Future<void> newTrainer(
      WidgetTester tester,
      String name,
      String id,
      String version,
    ) async {
      await _dismissSnackBar(tester);
      await _tap(tester, find.text('Adicionar save'));
      await _tap(tester, find.text('Novo treinador…'));
      await tester.enterText(field('Nome'), name);
      await tester.enterText(field('ID do treinador'), id);
      await _tap(tester, find.byKey(const ValueKey('field-version')));
      await _tap(tester, find.widgetWithText(MenuItemButton, version));
      await _tap(tester, find.text('Salvar'));
    }

    testWidgets('adicionar, renomear e remover', (tester) async {
      final backend = await pumpFullApp(tester, size: compactSize);
      await _go(tester, Routes.settings);
      await _tap(tester, find.text('Meus saves'));
      expect(find.text('Scarlet · Switch'), findsOneWidget);
      expect(find.text('Legends: Z-A · Ash (222222)'), findsOneWidget);

      // Fechar a folha sem escolher não cria nada.
      await _tap(tester, find.text('Adicionar save'));
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      // Só o Rei (Legends: Arceus) ainda pode virar save.
      await _tap(tester, find.text('Adicionar save'));
      expect(find.text('Ash (654321)'), findsNothing); // sem versão
      await _tap(tester, find.text('Rei (111111) · Legends: Arceus'));
      expect(
        find.text('Legends: Arceus · Rei (111111) adicionado.'),
        findsOneWidget,
      );

      // Sem elegíveis: cadastra um treinador novo.
      await newTrainer(tester, 'Blue', '777', 'Sword');
      expect(find.text('Sword · Blue (777) adicionado.'), findsOneWidget);
      // Jogo que não recebe do HOME: o backend recusa.
      await newTrainer(tester, 'Red', '1', 'Red');
      expect(find.textContaining('só treinadores de jogos'), findsOneWidget);
      // Desistir do cadastro.
      await _dismissSnackBar(tester);
      await _tap(tester, find.text('Adicionar save'));
      expect(
        find.text('Nenhum treinador de jogo que recebe do HOME.'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Novo treinador…'));
      await _tap(tester, find.text('Cancelar'));
      expect((await backend.fetchSaves()).length, 4);

      Finder menuOf(String title) => find.descendant(
        of: find.widgetWithText(ListTile, title),
        matching: find.byTooltip('Ações do save'),
      );

      // Renomear: Salvar, Enter e Cancelar.
      await _tap(tester, menuOf('Scarlet · Switch'));
      await _tap(tester, find.text('Renomear'));
      await tester.enterText(find.byType(TextField), ' OLED ');
      await _tap(tester, find.text('Salvar'));
      expect(find.text('Scarlet · OLED'), findsOneWidget);
      await _tap(tester, menuOf('Scarlet · OLED'));
      await _tap(tester, find.text('Renomear'));
      await tester.enterText(find.byType(TextField), 'Lite');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Scarlet · Lite'), findsOneWidget);
      await _tap(tester, menuOf('Scarlet · Lite'));
      await _tap(tester, find.text('Renomear'));
      await _tap(tester, find.text('Cancelar'));
      expect(find.text('Scarlet · Lite'), findsOneWidget);
      // O espécime fora do HOME mostra o apelido novo.
      final away = (await backend.fetchSlot(62)).specimen!;
      expect(away.location!.title, 'Scarlet · Lite');

      // Remover: com espécime, recusa; sem, some. Cancelar não remove.
      await _tap(tester, menuOf('Scarlet · Lite'));
      await _tap(tester, find.text('Remover'));
      await _tap(tester, find.widgetWithText(TextButton, 'Remover'));
      expect(find.textContaining('ainda tem espécimes'), findsOneWidget);
      await _tap(tester, menuOf('Legends: Z-A · Ash (222222)'));
      await _tap(tester, find.text('Remover'));
      await _tap(tester, find.text('Cancelar'));
      expect(find.text('Legends: Z-A · Ash (222222)'), findsOneWidget);
      await _tap(tester, menuOf('Legends: Z-A · Ash (222222)'));
      await _tap(tester, find.text('Remover'));
      await _tap(tester, find.widgetWithText(TextButton, 'Remover'));
      expect(find.text('Legends: Z-A · Ash (222222)'), findsNothing);
    });

    testWidgets('falhas: lista, treinadores e renomear', (tester) async {
      final repository = MockSpecimenRepository();
      var fail = true;
      when(repository.fetchSaves).thenAnswer((_) async {
        if (fail) throw const NetworkFailure();
        return const [_save];
      });
      when(repository.fetchTrainers).thenThrow(const ServerFailure());
      when(() => repository.updateSave(any(), label: any(named: 'label')))
          .thenThrow(const ServerFailure());
      await pumpWidgetApp(
        tester,
        const SavesPage(),
        overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);

      fail = false;
      await _tap(tester, find.text('Tentar novamente'));
      expect(find.text('Scarlet · Switch'), findsOneWidget);
      await _tap(tester, find.text('Adicionar save'));
      expect(find.text(const ServerFailure().message), findsOneWidget);
      await _tap(tester, find.byTooltip('Ações do save'));
      await _tap(tester, find.text('Renomear'));
      await _tap(tester, find.text('Salvar'));
      expect(find.text(const ServerFailure().message), findsOneWidget);
    });

    for (final size in [compactSize, expandedSize]) {
      testWidgets('lista vazia explica o que é um save '
          '(${size.width.toInt()}px)', (tester) async {
        final repository = MockSpecimenRepository();
        when(repository.fetchSaves).thenAnswer((_) async => const []);
        await pumpWidgetApp(
          tester,
          const SavesPage(),
          size: size,
          overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Nenhum save cadastrado.'), findsOneWidget);
      });
    }
  });

  group('Fora do HOME', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('lista por save, abre o detalhe e traz de volta '
          '(${size.width.toInt()}px)', (tester) async {
        await pumpFullApp(tester, size: size);
        await _go(tester, Routes.specimens);
        await _tap(tester, find.byTooltip('Fora do HOME'));
        expect(find.text('Scarlet · Switch'), findsOneWidget);
        expect(find.text('1 Pokémon'), findsOneWidget);
        expect(find.textContaining('#0002 · Saiu há'), findsOneWidget);

        await _tap(tester, find.text('Ivysaur'));
        expect(find.text('Em Scarlet · Switch'), findsOneWidget);
        await _tap(tester, find.byType(BackButton));

        await tester.fling(
          find.byType(ListView),
          const Offset(0, 400),
          1000,
        ); // refresh
        await tester.pumpAndSettle();
        await _tap(tester, find.byTooltip('Trazer de volta ao HOME'));
        await _tap(tester, find.text('Voltou igual'));
        expect(find.text('Todos os seus Pokémon estão no HOME.'), findsOne);
      });
    }

    testWidgets('mais de um no save e erro com "Tentar novamente"', (
      tester,
    ) async {
      final repository = MockSpecimenRepository();
      registerFallbackValue(emptySpecimenQuery);
      var fail = true;
      when(
        () => repository.fetchSpecimens(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async {
        if (fail) throw const NetworkFailure();
        final fake = FakeBackend.seeded();
        final away = (await fake.fetchSlot(62)).specimen!.id;
        final other = (await fake.fetchSlot(61)).specimen!.id;
        await fake.transfer([other], saveId: 1);
        final page = await fake.fetchSpecimens(
          const SpecimenQuery(location: SpecimenQuery.locationAway),
          page: 1,
          pageSize: 500,
        );
        expect(page.results.map((s) => s.id), containsAll([away, other]));
        return page;
      });
      await pumpWidgetApp(
        tester,
        const AwayPage(),
        overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      fail = false;
      await _tap(tester, find.text('Tentar novamente'));
      expect(find.text('2 Pokémon'), findsOneWidget);
      expect(find.textContaining('Saiu hoje'), findsOneWidget);
    });
  });

  testWidgets('inventário: enviar e trazer em lote; filtro "Onde está"', (
    tester,
  ) async {
    final backend = await pumpFullApp(tester, size: compactSize);
    await _go(tester, Routes.specimens);
    final first = (await backend.fetchSpecimens(
      emptySpecimenQuery,
      page: 1,
      pageSize: 1,
    )).results.single;
    final tile = find.byKey(ValueKey('specimen-${first.id}'));

    /// Abre os filtros e escolhe [label] em "Onde está".
    Future<void> filterBy(String label) async {
      await _dismissSnackBar(tester);
      await _tap(tester, find.byTooltip('Filtros'));
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.scrollUntilVisible(
        chip,
        200,
        scrollable: find
            .descendant(
              of: find.byType(SpecimenFiltersPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _tap(tester, chip);
      await _tap(tester, find.text('Mostrar resultados'));
    }

    Future<void> menu(String label) async {
      await _tap(tester, find.byTooltip('Ações da seleção'));
      await _tap(tester, find.text(label));
    }

    // Desistir na escolha do save mantém a seleção.
    await tester.longPress(tile);
    await tester.pumpAndSettle();
    await menu('Enviar para jogo…');
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(find.text('1 selecionado'), findsOneWidget);

    await menu('Enviar para jogo…');
    await _tap(tester, find.text('Scarlet · Switch'));
    expect(find.text('1 espécime enviado para Scarlet · Switch.'), findsOne);
    expect(find.text('1 selecionado'), findsNothing);

    // Filtro: fora do HOME (o do seed e o enviado agora).
    await filterBy('Fora do HOME');
    expect(find.widgetWithText(InputChip, 'Fora do HOME'), findsOneWidget);
    expect(find.byType(SpecimenListTile), findsNWidgets(2));

    await tester.longPress(tile);
    await tester.pumpAndSettle();
    await menu('Trazer de volta ao HOME');
    expect(find.text('1 espécime de volta ao HOME.'), findsOneWidget);
    expect(find.byType(SpecimenListTile), findsOneWidget);

    // Um save específico; o X do chip limpa.
    await filterBy('Scarlet · Switch');
    expect(
      find.widgetWithText(InputChip, 'Em Scarlet · Switch'),
      findsOneWidget,
    );
    await _tap(tester, find.byTooltip('Remover filtro'));
    expect(find.byType(InputChip), findsNothing);
  });

  group('falhas do fluxo', () {
    late MockSpecimenRepository repository;

    setUp(() {
      repository = MockSpecimenRepository();
      registerFallbackValue(<int>[]);
    });

    Future<void> pump(WidgetTester tester, {required bool away}) =>
        pumpWidgetApp(
          tester,
          // A ação da folha "Mais ações", num botão.
          Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final action = locationAction(
                  context,
                  ref,
                  specimenId: 7,
                  name: 'Bulba',
                  away: away,
                );
                return TextButton(
                  onPressed: action.onSelected,
                  child: Text(action.label),
                );
              },
            ),
          ),
          overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
        );

    testWidgets('plural e save sem marca de origem', (tester) async {
      final noMark = _save.copyWith(
        trainer: _save.trainer.copyWith(version: 'red'),
      );
      when(repository.fetchSaves).thenAnswer((_) async => [noMark]);
      when(() => repository.transfer(any(), saveId: any(named: 'saveId')))
          .thenAnswer((_) async => 3);
      await pump(tester, away: false);

      await _tap(tester, find.text('Enviar para jogo…'));
      expect(find.byIcon(Icons.flight_takeoff), findsWidgets);
      await _tap(tester, find.text('Red · Switch'));
      expect(find.text('3 espécimes enviados para Red · Switch.'), findsOne);

      await pump(tester, away: true);
      await _tap(tester, find.text('Trazer de volta ao HOME'));
      await _tap(tester, find.text('Voltou igual'));
      expect(find.text('3 espécimes de volta ao HOME.'), findsOneWidget);
    });

    testWidgets('enviar: saves e transferência', (tester) async {
      var savesFail = true;
      when(repository.fetchSaves).thenAnswer((_) async {
        if (savesFail) throw const NetworkFailure();
        return const [_save];
      });
      when(() => repository.transfer(any(), saveId: any(named: 'saveId')))
          .thenThrow(const ServerFailure());
      await pump(tester, away: false);

      await _tap(tester, find.text('Enviar para jogo…'));
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      savesFail = false;
      await _tap(tester, find.text('Enviar para jogo…'));
      await _tap(tester, find.text('Scarlet · Switch'));
      expect(find.text(const ServerFailure().message), findsOneWidget);
    });

    testWidgets('trazer de volta: igual e evoluído', (tester) async {
      when(() => repository.transfer(any(), saveId: any(named: 'saveId')))
          .thenThrow(const ServerFailure());
      when(() => repository.evolve(any(), formId: any(named: 'formId')))
          .thenThrow(const NetworkFailure());
      when(() => repository.searchForms(any()))
          .thenAnswer((_) => FakeBackend.seeded().searchForms('ivysaur'));
      await pump(tester, away: true);

      await _tap(tester, find.text('Trazer de volta ao HOME'));
      await _tap(tester, find.text('Voltou igual'));
      expect(find.text(const ServerFailure().message), findsOneWidget);

      await _tap(tester, find.text('Trazer de volta ao HOME'));
      await _tap(tester, find.text('Evoluiu…'));
      await _pickForm(tester, 'ivysaur', 2);
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      // Só o "Voltou igual" transferiu: a evolução falhou antes.
      verify(() => repository.transfer([7], saveId: null)).called(1);
    });
  });
}
