import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/presentation/specimens_page.dart';

import '../../helpers/helpers.dart';

Finder specimenTile(int id) => find.byKey(ValueKey('specimen-$id'));

/// Specimens do fake na ordem da API (forma, depois id).
Future<List<Specimen>> allSpecimens(FakeBackend backend) async =>
    (await backend.fetchSpecimens(
      emptySpecimenQuery,
      page: 1,
      pageSize: 500,
    )).results;

Future<void> openSpecimensTab(WidgetTester tester) async {
  await tester.tap(find.text('Espécimes').first);
  await tester.pumpAndSettle();
}

/// Busca com debounce: digita e espera a consulta sair.
Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Buscar por apelido ou forma'),
    text,
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Salva o formulário do specimen (o botão fica no fim da lista).
Future<void> saveForm(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.drag(
    find.descendant(
      of: find.byType(SpecimenForm),
      matching: find.byType(ListView),
    ),
    const Offset(0, -3000),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('expandido', () {
    testWidgets('lista, filtros e busca', (tester) async {
      final backend = await pumpFullApp(tester);
      final specimens = await allSpecimens(backend);
      final shinyBulba = specimens.firstWhere((s) => s.form == 1 && s.isShiny);
      final plainBulba = specimens.firstWhere((s) => s.form == 1 && !s.isShiny);
      final saur = specimens.firstWhere((s) => s.nickname == 'Saur');
      await openSpecimensTab(tester);

      expect(find.text('Selecione um espécime na lista.'), findsOneWidget);
      expect(specimenTile(shinyBulba.id), findsOneWidget);
      expect(specimenTile(plainBulba.id), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Shiny'));
      await tester.pumpAndSettle();
      expect(specimenTile(plainBulba.id), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Shiny'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Depositados'));
      await tester.pumpAndSettle();
      expect(specimenTile(saur.id), findsNothing);
      await tester.tap(find.text('Disponíveis'));
      await tester.pumpAndSettle();
      expect(specimenTile(shinyBulba.id), findsNothing);
      expect(specimenTile(saur.id), findsOneWidget);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      // Alfa e GO: só os que têm cada marca (seed: 💢 nas formas 1, 6, 11…;
      // 📱 nas múltiplas de 7).
      await tester.tap(find.widgetWithText(FilterChip, 'Alfa'));
      await tester.pumpAndSettle();
      expect(specimenTile(saur.id), findsNothing); // Saur não é alfa
      expect(find.text(alphaEmoji), findsWidgets);
      await tester.tap(find.widgetWithText(FilterChip, 'Alfa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'GO'));
      await tester.pumpAndSettle();
      expect(specimenTile(shinyBulba.id), findsNothing);
      expect(find.text(goEmoji), findsWidgets);
      await tester.tap(find.widgetWithText(FilterChip, 'GO'));
      await tester.pumpAndSettle();

      await search(tester, 'pidgeotto');
      expect(find.byType(SpecimenListTile), findsNWidgets(2));
      await search(tester, 'zzz');
      expect(find.text('Nenhum espécime encontrado.'), findsOneWidget);
    });

    testWidgets('rolagem carrega as próximas páginas', (tester) async {
      final backend = await pumpFullApp(tester);
      final last = (await allSpecimens(backend)).last;
      await openSpecimensTab(tester);
      expect(specimenTile(last.id), findsNothing);
      await tester.scrollUntilVisible(
        specimenTile(last.id),
        500,
        scrollable: find
            .descendant(
              of: find.byType(SpecimenList),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(specimenTile(last.id), findsOneWidget);
      // Puxar para atualizar recarrega do início.
      await tester.fling(
        find.byType(SpecimenList),
        const Offset(0, 5000),
        3000,
      );
      await tester.pumpAndSettle();
      await tester.fling(find.byType(SpecimenList), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(SpecimenListTile), findsWidgets);
    });

    testWidgets('detalhe, editar e ver no dex', (tester) async {
      final backend = await pumpFullApp(tester);
      final bulba = (await allSpecimens(backend))
          .firstWhere((s) => s.form == 1 && s.isShiny);
      await openSpecimensTab(tester);

      await tester.tap(specimenTile(bulba.id));
      await tester.pumpAndSettle();
      expect(find.text('Depositado'), findsOneWidget);
      expect(find.text('Ver no dex'), findsOneWidget);

      await tester.tap(find.text('Editar espécime'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Bulba');
      await saveForm(tester, 'Salvar');
      expect(find.text('Espécime atualizado.'), findsOneWidget);
      expect(find.text('Bulba'), findsWidgets);

      // Voltar do formulário sem salvar não muda nada.
      await tester.tap(find.text('Editar espécime'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver no dex'));
      await tester.pumpAndSettle();
      // Abriu o dex na box do slot, com o slot selecionado.
      expect(find.text('Shiny Living Dex'), findsWidgets);
      expect(find.text('HOME 1 · 20/30'), findsOneWidget);
      expect(find.text('Registrado'), findsOneWidget);
      expect(find.text('Bulba'), findsWidgets);
    });

    testWidgets('libertar espécime disponível', (tester) async {
      final backend = await pumpFullApp(tester);
      final saur = (await allSpecimens(backend))
          .firstWhere((s) => s.nickname == 'Saur');
      await openSpecimensTab(tester);
      await tester.tap(specimenTile(saur.id));
      await tester.pumpAndSettle();
      expect(find.text('Disponível'), findsOneWidget);

      await tester.tap(find.text('Libertar'));
      await tester.pumpAndSettle();
      expect(find.text('Libertar Saur?'), findsOneWidget);
      expect(find.textContaining('slot ficará faltante'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Libertar'));
      await tester.pumpAndSettle();
      expect(find.text('Espécime libertado.'), findsOneWidget);
      expect(find.text('Selecione um espécime na lista.'), findsOneWidget);
      expect(specimenTile(saur.id), findsNothing);
    });

    testWidgets('novo espécime sem depositar', (tester) async {
      await pumpFullApp(tester);
      await openSpecimensTab(tester);

      await tester.tap(find.text('Novo espécime'));
      await tester.pumpAndSettle();
      expect(find.text('Digite ao menos 2 letras do nome.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'pidgey');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pidgey').last);
      await tester.pumpAndSettle();

      expect(find.text('Novo Pidgey'), findsOneWidget);
      // Cadastro avulso: o botão não fala em depositar.
      expect(find.text('Salvar e depositar'), findsNothing);
      await saveForm(tester, 'Salvar');
      expect(find.text('Espécime cadastrado.'), findsOneWidget);
      expect(find.text('Disponível'), findsOneWidget);
    });

    testWidgets('fechar o seletor ou o formulário não cadastra', (
      tester,
    ) async {
      await pumpFullApp(tester);
      await openSpecimensTab(tester);
      await tester.tap(find.text('Novo espécime'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(SpecimensPage), findsOneWidget);

      await tester.tap(find.text('Novo espécime'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'pidgey');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pidgey').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Espécime cadastrado.'), findsNothing);
    });
  });

  group('compacto', () {
    testWidgets('detalhe em tela própria e libertar volta à lista', (
      tester,
    ) async {
      final backend = await pumpFullApp(tester, size: compactSize);
      final saur = (await allSpecimens(backend))
          .firstWhere((s) => s.nickname == 'Saur');
      await openSpecimensTab(tester);
      // O seletor de forma abre em tela cheia no compacto.
      await tester.tap(find.text('Novo espécime'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      await search(tester, 'saur');
      await tester.tap(specimenTile(saur.id));
      await tester.pumpAndSettle();
      expect(find.text('Espécime'), findsOneWidget);
      expect(find.byType(SpecimensPage), findsNothing);

      await tester.tap(find.text('Libertar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Libertar'));
      await tester.pumpAndSettle();
      expect(find.byType(SpecimensPage), findsOneWidget);
      expect(specimenTile(saur.id), findsNothing);
    });

    testWidgets('filtros avançados: badge, chips e remoção', (tester) async {
      final backend = await pumpFullApp(tester, size: compactSize);
      final saur = (await allSpecimens(backend))
          .firstWhere((s) => s.nickname == 'Saur');
      await openSpecimensTab(tester);
      // Sem filtro avançado: sem badge e sem linha de chips.
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, false);
      expect(find.byType(InputChip), findsNothing);

      // Fechar a folha sem aplicar não muda a lista.
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pokébola'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Sem pokébola'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Filtros').last, const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);

      // Aplicar: só os sem pokébola (entre eles, o Saur).
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pokébola'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Sem pokébola'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostrar resultados'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Badge, '1'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Sem pokébola'), findsOneWidget);
      expect(specimenTile(saur.id), findsOneWidget);
      // O subtítulo mostra a pokébola ("Dream Ball"...): nenhum tem.
      expect(find.textContaining('Ball'), findsNothing);

      // O X do chip remove o filtro.
      await tester.tap(find.byTooltip('Remover filtro'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(find.textContaining('Ball'), findsWidgets);
    });
  });
}
