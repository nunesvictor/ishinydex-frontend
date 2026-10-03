import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/menu_chip.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/presentation/specimens_page.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

Finder specimenTile(int id) => find.byKey(ValueKey('specimen-$id'));

/// Specimens do fake na ordem da API (forma, depois id).
Future<List<Specimen>> allSpecimens(FakeBackend backend) async =>
    (await backend.fetchSpecimens(
      emptySpecimenQuery,
      page: 1,
      pageSize: 500,
    )).results;

/// Escolhe a situação [label] no menu do chip "Situação".
Future<void> pickStatus(WidgetTester tester, String label) async {
  await tester.tap(find.byType(MenuChip));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(RadioMenuButton<SpecimenStatus>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// Abre o menu "Ações da seleção" e escolhe [label].
Future<void> openBulkAction(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Ações da seleção'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
}

Future<void> openSpecimensTab(WidgetTester tester) async {
  await tester.tap(find.text('Espécimes').first);
  await tester.pumpAndSettle();
}

/// Busca com debounce: digita e espera a consulta sair.
Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Apelido, forma ou nº da dex'),
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
      // Ordem das boxes (padrão): o Bulbasaur comum está depositado na
      // HOME 3, então só aparece junto dela.
      expect(specimenTile(plainBulba.id), findsNothing);
      // Contador: sem filtro, só o total.
      final total = specimens.length;
      expect(find.text('$total espécimes'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Shiny'));
      await tester.pumpAndSettle();
      expect(specimenTile(plainBulba.id), findsNothing);
      // Com filtro: "filtrados de todos".
      final shiny = specimens.where((s) => s.isShiny).length;
      expect(find.text('$shiny de $total espécimes'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Shiny'));
      await tester.pumpAndSettle();

      await pickStatus(tester, 'Registrados');
      expect(specimenTile(saur.id), findsNothing);
      expect(find.widgetWithText(MenuChip, 'Registrados'), findsOneWidget);
      await pickStatus(tester, 'Disponíveis');
      expect(specimenTile(shinyBulba.id), findsNothing);
      expect(specimenTile(saur.id), findsOneWidget);
      await pickStatus(tester, 'Todos');
      expect(find.widgetWithText(MenuChip, 'Situação'), findsOneWidget);

      // Alfa e GO: só os que têm cada marca (seed: 💢 nas formas 1, 6, 11…;
      // 📱 nas múltiplas de 7).
      await tester.tap(find.widgetWithText(FilterChip, 'Alfa'));
      await tester.pumpAndSettle();
      expect(specimenTile(saur.id), findsNothing); // Saur não é alfa
      expect(find.byType(AlphaIcon), findsWidgets);
      await tester.tap(find.widgetWithText(FilterChip, 'Alfa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'GO'));
      await tester.pumpAndSettle();
      expect(specimenTile(shinyBulba.id), findsNothing);
      expect(find.byType(GoIcon), findsWidgets);
      await tester.tap(find.widgetWithText(FilterChip, 'GO'));
      await tester.pumpAndSettle();

      await search(tester, 'pidgeotto');
      expect(find.byType(SpecimenListTile), findsNWidgets(2));
      expect(find.text('2 de $total espécimes'), findsOneWidget);
      // Número: nº nacional (pidgeotto = 17).
      await search(tester, '17');
      expect(find.byType(SpecimenListTile), findsNWidgets(2));
      await search(tester, 'zzz');
      expect(find.text('Nenhum espécime encontrado.'), findsOneWidget);

      // O "x" apaga o texto e volta à lista completa na hora.
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(find.text('zzz'), findsNothing);
      expect(find.text('$total espécimes'), findsOneWidget);
      expect(find.byTooltip('Limpar busca'), findsNothing);
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

      await tester.tap(find.text('Editar espécime'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Bulba');
      await saveForm(tester, 'Salvar');
      expect(find.text('Espécime atualizado.'), findsOneWidget);
      expect(find.text('Bulba'), findsWidgets);

      // Voltar do formulário sem salvar não muda nada. (A mensagem cobriria
      // a barra de ações.)
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar espécime'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      await tapMoreAction(tester, 'Ver no dex');
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

      await tapMoreAction(tester, 'Libertar');
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
    testWidgets('chips só com o ícone, nome no tooltip; sem rolar de lado', (
      tester,
    ) async {
      final backend = FakeBackend.seeded();
      final specimens = await allSpecimens(backend);
      await pumpFullApp(tester, size: compactSize, backend: backend);
      await openSpecimensTab(tester);

      for (final label in ['Shiny', 'Alfa', 'GO']) {
        expect(find.widgetWithText(FilterChip, label), findsNothing);
      }
      expect(
        find.descendant(
          of: find.byType(FilterChip),
          matching: find.byType(ShinyIcon),
        ),
        findsOneWidget,
      );
      // A linha de filtros quebra em vez de rolar.
      expect(
        find.ancestor(
          of: find.byTooltip('Só shiny'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
        ),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Só shiny'));
      await tester.pumpAndSettle();
      final shiny = specimens.where((s) => s.isShiny).length;
      expect(
        find.text('$shiny de ${specimens.length} espécimes'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Só shiny'));
      await tester.pumpAndSettle();
      expect(find.text('${specimens.length} espécimes'), findsOneWidget);
    });

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

      // Sem texto, sem "x"; digitando, ele aparece.
      expect(find.byTooltip('Limpar busca'), findsNothing);
      await search(tester, 'saur');
      expect(find.byTooltip('Limpar busca'), findsOneWidget);
      await tester.tap(specimenTile(saur.id));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Espécime'), findsOneWidget);
      expect(find.byType(SpecimensPage), findsNothing);

      await tapMoreAction(tester, 'Libertar');
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
      final all = await allSpecimens(backend);
      final noBall = all.where((s) => s.pokeball == null).length;
      expect(find.text('$noBall de ${all.length} espécimes'), findsOneWidget);
      // O cabeçalho mostra a pokébola ("Dream Ball"...): nenhum tem.
      expect(ballSprite('Ball'), findsNothing);

      // O X do chip remove o filtro.
      await tester.tap(find.byTooltip('Remover filtro'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(ballSprite('Ball'), findsWidgets);
    });
  });

  group('edição em lote', () {
    Finder checkbox(int id) =>
        find.descendant(of: specimenTile(id), matching: find.byType(Checkbox));

    Future<void> applyEdit(
      WidgetTester tester,
      Future<void> Function() fill,
    ) async {
      await tester.tap(find.byTooltip('Editar em lote'));
      await tester.pumpAndSettle();
      await fill();
      await tester.tap(find.textContaining('Revisar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
    }

    testWidgets('selecionar, todos os resultados e aplicar', (tester) async {
      final backend = await pumpFullApp(tester, size: compactSize);
      final specimens = await allSpecimens(backend);
      final saur = specimens.firstWhere((s) => s.nickname == 'Saur');
      await openSpecimensTab(tester);
      expect(find.byType(Checkbox), findsNothing);

      // Toque longo entra no modo; tocar marca/desmarca; ✕ sai.
      await tester.longPress(specimenTile(saur.id));
      await tester.pumpAndSettle();
      expect(find.text('1 selecionado'), findsOneWidget);
      expect(find.text('Novo espécime'), findsNothing);
      expect(tester.widget<Checkbox>(checkbox(saur.id)).value, true);
      final other = specimens.first;
      await tester.tap(specimenTile(other.id));
      await tester.pumpAndSettle();
      expect(find.text('2 selecionados'), findsOneWidget);
      await tester.tap(checkbox(other.id));
      await tester.pumpAndSettle();
      expect(find.text('1 selecionado'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancelar seleção'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);

      // A seleção sobrevive à busca: o lote junta resultados de várias
      // buscas, e a AppBar conta os marcados fora da lista.
      final outsider = specimens.firstWhere(
        (s) => !(s.formName ?? '').contains('saur') && s.nickname != 'Saur',
      );
      await tester.longPress(specimenTile(outsider.id));
      await tester.pumpAndSettle();
      await search(tester, 'saur');
      expect(find.text('1 selecionado'), findsOneWidget);
      expect(find.text('1 fora da lista'), findsOneWidget);
      await tester.tap(specimenTile(saur.id));
      await tester.pumpAndSettle();
      expect(find.text('2 selecionados'), findsOneWidget);

      // "Só selecionados" lista só os marcados (filtro id da API); mudar a
      // busca volta para a lista normal.
      await tester.tap(find.widgetWithText(FilterChip, 'Só selecionados (2)'));
      await tester.pumpAndSettle();
      expect(find.byType(SpecimenListTile), findsNWidgets(2));
      expect(specimenTile(outsider.id), findsOneWidget);
      expect(find.text('1 fora da lista'), findsNothing);
      // Desmarcar na visão some com o item; sem nenhum, sai do modo.
      await tester.tap(specimenTile(outsider.id));
      await tester.pumpAndSettle();
      expect(find.byType(SpecimenListTile), findsOneWidget);
      await tester.tap(specimenTile(saur.id));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Só selecionados'), findsNothing);

      // "Selecionar todos" soma os resultados do filtro à seleção.
      await tester.longPress(specimenTile(saur.id));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Só selecionados (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(SpecimenListTile), findsOneWidget);
      // Mudar a busca sai da visão "Só selecionados" (mantendo a seleção).
      await search(tester, 'sau');
      expect(
        tester
            .widget<FilterChip>(
              find.widgetWithText(FilterChip, 'Só selecionados (1)'),
            )
            .selected,
        false,
      );
      await search(tester, 'saur');
      expect(find.textContaining('fora da lista'), findsNothing);
      await tester.tap(find.byTooltip('Selecionar todos os resultados'));
      await tester.pumpAndSettle();
      final matching = specimens
          .where(
            (s) => s.nickname == 'Saur' || (s.formName ?? '').contains('saur'),
          )
          .length;
      expect(find.text('$matching selecionados'), findsOneWidget);

      // Cancelar na confirmação não altera nada.
      await tester.tap(find.byTooltip('Editar em lote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pokébola'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beast Ball'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Revisar'));
      await tester.pumpAndSettle();
      expect(find.text('• Pokébola → Beast Ball'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('$matching selecionados'), findsOneWidget);

      await applyEdit(tester, () async {
        await tester.tap(find.text('Pokébola'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beast Ball'));
        await tester.pumpAndSettle();
      });
      expect(find.text('$matching espécimes atualizados.'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      // A lista recarregou com a pokébola nova.
      expect(ballSprite('Beast Ball'), findsWidgets);
      expect((await backend.fetchSpecimen(saur.id)).pokeball, 'beast-ball');
    });

    testWidgets('conflito de gênero: nada muda; desmarcar e seguir', (
      tester,
    ) async {
      final backend = await pumpFullApp(tester, size: compactSize);
      await openSpecimensTab(tester);
      // Nidoran♀ (só fêmea) e Nidoran♂ (só macho).
      await search(tester, 'nidoran');
      final nidorans = (await backend.fetchSpecimens(
        const SpecimenQuery(search: 'nidoran'),
        page: 1,
        pageSize: 50,
      )).results;
      final females = nidorans.where((s) => s.formName == 'nidoran-f');
      await tester.longPress(specimenTile(nidorans.first.id));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Selecionar todos os resultados'));
      await tester.pumpAndSettle();

      Future<void> editMale() => applyEdit(tester, () async {
        await tester.scrollUntilVisible(
          find.widgetWithText(ChoiceChip, 'Macho'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.widgetWithText(ChoiceChip, 'Macho'));
        await tester.pumpAndSettle();
      });

      await editMale();
      expect(find.text('Gênero impossível'), findsOneWidget);
      expect(find.textContaining('Nenhum espécime foi alterado.'), findsOne);
      expect(
        find.textContaining('Nidoran F (#'),
        findsNWidgets(females.length),
      );
      // Fechar mantém a seleção.
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('${nidorans.length} selecionados'), findsOneWidget);

      await editMale();
      await tester.tap(find.text('Desmarcar estes'));
      await tester.pumpAndSettle();
      final rest = nidorans.length - females.length;
      expect(
        find.text(rest == 1 ? '1 selecionado' : '$rest selecionados'),
        findsOneWidget,
      );
      await editMale();
      expect(
        find.text(
          rest == 1 ? '1 espécime atualizado.' : '$rest espécimes atualizados.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('expandido: no modo de seleção, tocar não abre o detalhe', (
      tester,
    ) async {
      final backend = await pumpFullApp(tester);
      final first = (await allSpecimens(backend)).first;
      await openSpecimensTab(tester);
      await tester.longPress(specimenTile(first.id));
      await tester.pumpAndSettle();
      expect(find.text('1 selecionado'), findsOneWidget);
      expect(find.text('Selecione um espécime na lista.'), findsOneWidget);
      await tester.tap(specimenTile(first.id));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Selecione um espécime na lista.'), findsOneWidget);
    });

    testWidgets('falhas viram mensagem', (tester) async {
      final repository = MockSpecimenRepository();
      final specimen = Specimen.fromJson(specimenJson);
      final fake = FakeBackend.seeded();
      registerFallbackValue(emptySpecimenQuery);
      registerFallbackValue(const SpecimenChanges());
      when(
        () => repository.fetchSpecimens(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => Paginated(count: 1, results: [specimen]));
      when(repository.fetchOptions).thenAnswer((_) async => fake.options);
      when(repository.fetchTrainers).thenAnswer((_) async => const []);
      when(() => repository.fetchSpecimenIds(any()))
          .thenThrow(const NetworkFailure());
      when(
        () => repository.bulkUpdate(
          ids: any(named: 'ids'),
          changes: any(named: 'changes'),
        ),
      ).thenThrow(const ServerFailure());
      await pumpWidgetApp(
        tester,
        const SpecimensPage(),
        overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      await tester.longPress(specimenTile(specimen.id));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Selecionar todos os resultados'));
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);

      // Fechar a folha sem alterar não chega na API.
      await tester.tap(find.byTooltip('Editar em lote'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Editar 1 espécime'), const Offset(0, 800));
      await tester.pumpAndSettle();

      await applyEdit(tester, () async {
        await tester.tap(find.widgetWithText(ChoiceChip, 'Fêmea'));
        await tester.pumpAndSettle();
      });
      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('1 selecionado'), findsOneWidget);
      verify(
        () => repository.bulkUpdate(
          ids: [specimen.id],
          changes: const SpecimenChanges(gender: SetTo('female')),
        ),
      ).called(1);
    });
  });

  group('libertar em lote', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('confirma com os depositados e liberta '
          '(${size.width.toInt()}px)', (tester) async {
        final backend = await pumpFullApp(tester, size: size);
        final specimens = await allSpecimens(backend);
        final deposited = specimens.where((s) => s.isDeposited).take(2);
        final loose = specimens.firstWhere((s) => !s.isDeposited);
        await openSpecimensTab(tester);

        // Só um, não depositado: singular e sem falar de slot. Os soltos
        // ficam no fim da lista: a busca traz o escolhido para a tela.
        await search(tester, loose.nickname ?? loose.formName!);
        await tester.longPress(specimenTile(loose.id));
        await tester.pumpAndSettle();
        await openBulkAction(tester, 'Libertar em lote');
        await tester.pumpAndSettle();
        expect(find.text('Libertar 1 espécime?'), findsOneWidget);
        expect(
          find.text(
            'O cadastro será apagado. Esta ação não pode ser desfeita.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.text('1 selecionado'), findsOneWidget);

        // Mais dois depositados (os primeiros da lista, na ordem das boxes).
        await search(tester, '');
        for (final s in deposited) {
          await tester.tap(specimenTile(s.id));
          await tester.pumpAndSettle();
        }
        expect(find.text('3 selecionados'), findsOneWidget);
        await openBulkAction(tester, 'Libertar em lote');
        await tester.pumpAndSettle();
        expect(find.text('Libertar 3 espécimes?'), findsOneWidget);
        expect(
          find.text(
            'Os cadastros serão apagados. 2 estão depositados e os slots '
            'ficarão faltantes. Esta ação não pode ser desfeita.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Libertar'));
        await tester.pumpAndSettle();

        expect(find.text('3 espécimes libertados.'), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
        final rest = {for (final s in await allSpecimens(backend)) s.id};
        for (final s in [loose, ...deposited]) {
          expect(rest.contains(s.id), false);
        }
      });
    }

    testWidgets('1 depositado; o detalhe aberto do libertado fecha', (
      tester,
    ) async {
      final backend = await pumpFullApp(tester);
      final deposited = (await allSpecimens(backend))
          .firstWhere((s) => s.isDeposited);
      await openSpecimensTab(tester);
      await tester.tap(specimenTile(deposited.id));
      await tester.pumpAndSettle();
      expect(find.text('Selecione um espécime na lista.'), findsNothing);
      await tester.longPress(specimenTile(deposited.id));
      await tester.pumpAndSettle();
      await openBulkAction(tester, 'Libertar em lote');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'O cadastro será apagado. 1 está depositado e o slot ficará '
          'faltante. Esta ação não pode ser desfeita.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Libertar'));
      await tester.pumpAndSettle();
      expect(find.text('1 espécime libertado.'), findsOneWidget);
      expect(find.text('Selecione um espécime na lista.'), findsOneWidget);
    });

    testWidgets('falhas viram mensagem e mantêm a seleção', (tester) async {
      final repository = MockSpecimenRepository();
      final specimen = Specimen.fromJson(specimenJson);
      final fake = FakeBackend.seeded();
      registerFallbackValue(emptySpecimenQuery);
      when(
        () => repository.fetchSpecimens(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => Paginated(count: 1, results: [specimen]));
      when(repository.fetchOptions).thenAnswer((_) async => fake.options);
      when(repository.fetchTrainers).thenAnswer((_) async => const []);
      var idsFail = true;
      when(() => repository.fetchSpecimenIds(any())).thenAnswer((_) async {
        if (idsFail) throw const NetworkFailure();
        return const <int>[];
      });
      when(() => repository.bulkRelease(any()))
          .thenThrow(const ServerFailure());
      await pumpWidgetApp(
        tester,
        const SpecimensPage(),
        overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      await tester.longPress(specimenTile(specimen.id));
      await tester.pumpAndSettle();

      // Sem a contagem de depositados, nem pergunta.
      await openBulkAction(tester, 'Libertar em lote');
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      expect(find.text('Libertar 1 espécime?'), findsNothing);

      idsFail = false;
      await openBulkAction(tester, 'Libertar em lote');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Libertar'));
      await tester.pumpAndSettle();
      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('1 selecionado'), findsOneWidget);
      verify(() => repository.bulkRelease([specimen.id])).called(1);
    });
  });

  testWidgets('contador: singular e separador de milhar', (tester) async {
    await pumpWidgetApp(
      tester,
      const Scaffold(
        body: Column(
          children: [
            ResultCount(query: emptySpecimenQuery, count: 1),
            ResultCount(query: emptySpecimenQuery, count: 1159),
          ],
        ),
      ),
    );
    expect(find.text('1 espécime'), findsOneWidget);
    expect(find.text('1.159 espécimes'), findsOneWidget);
  });
}
