import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/moves/moves_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/domain/synergy.dart';
import 'package:ishinydex/features/teams/domain/team_repository.dart';
import 'package:ishinydex/features/teams/presentation/member_editor.dart';
import 'package:ishinydex/features/teams/presentation/synergy_page.dart';
import 'package:ishinydex/features/teams/teams_providers.dart';

import '../../helpers/helpers.dart';
import 'team_fixture.dart';

class _Ready extends MovesNotifier {
  @override
  MovesState build() => MovesReady(teamMoves());
}

/// Um repositório que recusa gravar (e, com [failFetch], também ler).
class _Failing implements TeamRepository {
  _Failing(this.teams, {this.failFetch = false});

  final List<Team> teams;
  final bool failFetch;
  int fetches = 0;

  static const failure = ValidationFailure({
    'name': [Problem.teamFull()],
  });

  @override
  Future<List<Team>> fetchTeams() async {
    fetches++;
    if (failFetch) throw failure;
    return teams;
  }

  @override
  Future<Team> saveTeam(Team team) async => throw failure;

  @override
  Future<void> deleteTeam(int teamId) async => throw failure;

  @override
  Future<List<Specimen>> fetchSpecimensOfForm(int formId) async => const [];

  @override
  Future<Set<int>> fetchOwnedForms() async => const {};
}

Future<FakeBackend> _pump(
  WidgetTester tester, {
  Size size = compactSize,
  FakeBackend? backend,
  TeamRepository? repository,
  AppLanguage language = AppLanguage.pt,
}) => pumpFullApp(
  tester,
  size: size,
  backend: backend ?? teamBackend(),
  language: language,
  overrides: [
    movesProvider.overrideWith(_Ready.new),
    if (repository != null)
      teamRepositoryProvider.overrideWithValue(repository),
  ],
);

void _go(WidgetTester tester, String location) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);

Future<void> _openTeams(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.groups_outlined));
  await tester.pumpAndSettle();
}

/// A última lista vertical (a do membro, a da sinergia).
Finder get _list => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .last;

/// Rola a lista (a do membro, a última) até [finder] aparecer.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Do topo da lista para baixo.
    await tester.fling(_list, const Offset(0, 5000), 5000);
    await tester.pumpAndSettle();
  }
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 300, scrollable: _list);
  }
  await tester.ensureVisible(finder);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  // Um aviso da ação anterior cobriria o fim da tela.
  for (final messenger in find.byType(ScaffoldMessenger).evaluate()) {
    ((messenger as StatefulElement).state as ScaffoldMessengerState)
        .removeCurrentSnackBar();
  }
  await tester.pumpAndSettle();
  final finder = find.byKey(ValueKey(key));
  await _reveal(tester, finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Digita [text] no seletor de forma e escolhe o primeiro resultado.
Future<void> _pickForm(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

Future<void> _number(WidgetTester tester, String key, String value) async {
  await _tapKey(tester, key);
  await tester.enterText(find.byKey(const ValueKey('number-field')), value);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('number-ok')));
  await tester.pumpAndSettle();
}

const _team = Team(
  id: 0,
  name: 'Regulamento G',
  versionGroup: 'scarlet-violet',
  members: [
    TeamMember(
      form: 1,
      level: 100,
      ability: 'overgrow',
      item: 'focus-sash',
      tera: 'fairy',
      moves: ['tackle', 'vine-whip'],
    ),
  ],
);

void main() {
  testWidgets('sem catálogo (demonstração), a aba diz que não há golpes', (
    tester,
  ) async {
    await pumpFullApp(tester, size: compactSize);
    await _openTeams(tester);

    expect(find.text(ptText.movesUnavailable), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('criar o time e montar um membro (celular)', (tester) async {
    final backend = await _pump(tester);
    final specimen = await backend.create(
      const SpecimenDraft(
        form: 1,
        nickname: 'Bulba',
        nature: 'modest',
        ability: 'chlorophyll',
      ),
    );
    await _openTeams(tester);
    expect(find.text('Nenhum time ainda'), findsOneWidget);

    // O time novo: o nome é obrigatório e o jogo vem da lista.
    await tester.tap(find.text('Novo time'));
    await tester.pumpAndSettle();
    final create = find.byKey(const ValueKey('team-create'));
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('team-name')),
      'Regulamento G',
    );
    await tester.pumpAndSettle();
    // O jogo mais novo vem primeiro.
    expect(find.text('Legends: Z-A'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('moves-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('X / Y').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moves-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scarlet / Violet').last);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('Regulamento G'), findsOneWidget);
    expect(
      find.text('Adicione até 6 Pokémon que existem neste jogo.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('team-export')))
          .onPressed,
      isNull,
    );

    // Só as formas do jogo: o Mewtwo não aprende golpes no Scarlet/Violet.
    await _tapKey(tester, 'team-add');
    await tester.enterText(find.byType(TextField).last, 'mewtwo');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text(ptText.noFormFound), findsOneWidget);
    await _pickForm(tester, 'bulb');
    expect(find.text('Membro do time'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsWidgets);

    // Nível (cancelar não muda; o Enter confirma), habilidade, natureza,
    // item e Tera.
    await _tapKey(tester, 'member-level');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'member-level');
    await tester.enterText(find.byKey(const ValueKey('number-field')), '101');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('number-ok')))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const ValueKey('number-field')), '77');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('77'), findsOneWidget);
    await _tapKey(tester, 'member-ability');
    await tester.tap(find.byKey(const ValueKey('option-chlorophyll')));
    await tester.pumpAndSettle();
    expect(find.text('Chlorophyll'), findsOneWidget);
    expect(find.text('Habilidade oculta'), findsOneWidget);
    await _tapKey(tester, 'member-nature');
    await tester.tap(find.byKey(const ValueKey('option-modest')));
    await tester.pumpAndSettle();
    expect(find.text('Modest'), findsOneWidget);
    expect(find.text('+Atq. Esp., −Ataque'), findsOneWidget);
    await _tapKey(tester, 'member-item');
    expect(find.text('2 itens em Scarlet / Violet'), findsOneWidget);
    expect(find.byKey(const ValueKey('item-none')), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'left');
    await tester.pumpAndSettle();
    expect(find.text('Focus Sash'), findsNothing);
    expect(find.byKey(const ValueKey('item-none')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('item-leftovers')));
    await tester.pumpAndSettle();
    expect(find.text('Leftovers'), findsOneWidget);
    await _tapKey(tester, 'member-tera');
    await tester.tap(find.byKey(const ValueKey('option-fire')));
    await tester.pumpAndSettle();
    expect(find.text('Fire'), findsOneWidget);

    // Os golpes: escolher, trocar e tirar.
    await _tapKey(tester, 'member-move-0');
    expect(find.text('Golpe 1 de 4'), findsOneWidget);
    expect(
      find.text('5 golpes que Bulbasaur aprende em Scarlet / Violet'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).last, 'seed');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pick-tackle')), findsNothing);
    expect(find.byKey(const ValueKey('pick-seed-bomb')), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-tackle')));
    await tester.pumpAndSettle();
    expect(find.text('Tackle'), findsOneWidget);
    expect(find.text('Nv. 1 · TM001'), findsOneWidget);
    await _tapKey(tester, 'member-move-1');
    // O Tackle já está num slot.
    expect(find.byKey(const ValueKey('pick-tackle')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pick-vine-whip')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'member-move-0');
    expect(find.text('Golpe atual'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('move-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Tackle'), findsNothing);
    expect(find.text('Vine Whip'), findsOneWidget);
    // Fechar o seletor não muda nada.
    await _tapKey(tester, 'member-move-1');
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Vine Whip'), findsOneWidget);

    // EV pelo controle e IV pelo número.
    final attack = find.descendant(
      of: find.byKey(const ValueKey('stat-attack')),
      matching: find.byType(Slider),
    );
    await _reveal(tester, attack);
    await tester.drag(attack, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('252 de 510 EVs'), findsOneWidget);
    await _number(tester, 'iv-speed', '0');
    final team = (await backend.fetchTeams()).single;
    expect(team.members.single.evs, {'attack': 252});
    expect(team.members.single.ivs, {'speed': 0});

    // Ligar a um espécime puxa a natureza e a habilidade; desligar.
    await _tapKey(tester, 'member-link');
    await tester.tap(find.byKey(ValueKey('link-${specimen.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Ligado a Bulba'), findsOneWidget);
    await _tapKey(tester, 'member-unlink');
    expect(find.text('Ligar a um espécime'), findsOneWidget);

    // Trocar a forma: ficam a habilidade dela e os golpes que ela aprende.
    await _tapKey(tester, 'member-form');
    await _pickForm(tester, 'venu');
    expect(find.text('Venusaur'), findsWidgets);
    expect(find.text('Overgrow'), findsOneWidget);
    expect(find.text('A única desta forma'), findsOneWidget);
    expect(find.text('Vine Whip'), findsOneWidget);
    // Fechar a lista dos espécimes não liga nada.
    await _tapKey(tester, 'member-link');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Ligar a um espécime'), findsOneWidget);

    // De volta ao time: o cartão do membro, o nível de todos e a exportação.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Leftovers · Overgrow'), findsOneWidget);
    expect(find.text('Nível 77'), findsOneWidget);
    await _number(tester, 'team-level', '50');
    expect(find.text('Nível 50'), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await _tapKey(tester, 'team-export');
    expect(find.text('Exportar para o Showdown'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('export-copy')));
    await tester.pumpAndSettle();
    expect(copied, '''
Venusaur @ Leftovers
Ability: Overgrow
Level: 50
Tera Type: Fire
EVs: 252 Atk
Modest Nature
IVs: 0 Spe
- Vine Whip''');
    expect(find.text('Copiado'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Tirar do time volta para o time.
    await tester.tap(find.byKey(const ValueKey('member-0')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'member-remove');
    await tester.tap(find.text('Tirar do time').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Adicione até 6 Pokémon que existem neste jogo.'),
      findsOneWidget,
    );

    // Renomear (cancelar não muda) e excluir.
    await tester.tap(find.byKey(const ValueKey('team-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-rename')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Regulamento G'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('team-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('team-name')), ' ');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('team-name-save')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('team-name')),
      'Trick Room',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-name-save')));
    await tester.pumpAndSettle();
    expect(find.text('Trick Room'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('team-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir “Trick Room”?'), findsOneWidget);
    await tester.tap(find.text('Excluir time').last);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum time ainda'), findsOneWidget);
    expect(await backend.fetchTeams(), isEmpty);
  });

  testWidgets('a lista dos times e o membro ao lado (PC)', (tester) async {
    final backend = teamBackend();
    final specimen = await backend.create(const SpecimenDraft(form: 1));
    final saved = await backend.saveTeam(
      _team.copyWith(
        members: [
          _team.members.single.copyWith(specimen: specimen.id),
          const TeamMember(form: 3),
        ],
      ),
    );
    await backend.saveTeam(
      const Team(id: 0, name: 'Vazio', versionGroup: 'x-y'),
    );
    await _pump(tester, size: expandedSize, backend: backend);
    await _openTeams(tester);

    expect(
      find.text('Scarlet / Violet · 2 de 6 · Níveis variados'),
      findsOneWidget,
    );
    expect(find.text('X / Y · 0 de 6 · Nível 50'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    // O "Novo time" do botão flutuante; cancelar não cria.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('team-${saved.id}')));
    await tester.pumpAndSettle();
    // A lista e o membro escolhido lado a lado; o Tera no cartão.
    expect(find.byType(MemberEditor), findsOneWidget);
    expect(find.text('Focus Sash · Overgrow'), findsOneWidget);
    expect(find.text('Golpes'), findsOneWidget);
    expect(find.byTooltip('Tera Fairy'), findsOneWidget);
    expect(find.text('Espécime'), findsOneWidget);
    // Os seletores num diálogo.
    await _tapKey(tester, 'member-item');
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    // O Venusaur sem habilidade vira Bulbasaur: das duas, nenhuma.
    await tester.tap(find.byKey(const ValueKey('member-1')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'member-form');
    await _pickForm(tester, 'bulb');
    expect((await backend.fetchTeams()).first.members.last.ability, isNull);
    await _tapKey(tester, 'member-remove');
    await tester.tap(find.text('Tirar do time').last);
    await tester.pumpAndSettle();

    // Adicionar seleciona o novo; tirar volta para o primeiro.
    await _tapKey(tester, 'team-add');
    await _pickForm(tester, 'venu');
    expect(find.text('Venusaur'), findsWidgets);
    expect(find.text('Escolher golpe'), findsOneWidget);
    await _tapKey(tester, 'member-remove');
    await tester.tap(find.text('Tirar do time').last);
    await tester.pumpAndSettle();
    expect(find.text('Focus Sash · Overgrow'), findsOneWidget);
    expect((await backend.fetchTeams()).first.members, hasLength(1));

    // Trocar a forma mantém a habilidade que a nova também tem.
    await _tapKey(tester, 'member-form');
    await _pickForm(tester, 'venu');
    final first = (await backend.fetchTeams()).first.members.first;
    expect((first.formRef?.name, first.ability), ('venusaur', 'overgrow'));
  });

  testWidgets('time e membro que não existem', (tester) async {
    await _pump(tester);
    await _openTeams(tester);
    _go(tester, '/teams/999');
    await tester.pumpAndSettle();
    expect(find.text(ptText.problemNotFound), findsOneWidget);
    _go(tester, '/teams/999/members/3');
    await tester.pumpAndSettle();
    expect(find.text(ptText.problemNotFound), findsOneWidget);
  });

  testWidgets('as falhas ao gravar aparecem num aviso', (tester) async {
    final repository = _Failing([_team.copyWith(id: 1)]);
    await _pump(tester, repository: repository);
    await _openTeams(tester);
    final message = ptText.problemTeamFull;

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('team-name')), 'Novo');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('team-1')));
    await tester.pumpAndSettle();
    await _number(tester, 'team-level', '30');
    expect(find.text(message), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('team-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir time').last);
    await tester.pumpAndSettle();
    expect(find.text('Regulamento G'), findsOneWidget);
    await _tapKey(tester, 'team-add');
    await _pickForm(tester, 'venu');
    expect(find.text(message), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('member-0')));
    await tester.pumpAndSettle();
    await _number(tester, 'member-level', '30');
    expect(find.text(message), findsWidgets);
    await _tapKey(tester, 'member-link');
    expect(
      find.text('Nenhum espécime de uma forma que existe neste jogo.'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'member-remove');
    await tester.tap(find.text('Tirar do time').last);
    await tester.pumpAndSettle();
    expect(find.text('Membro do time'), findsOneWidget);
  });

  testWidgets('a lista que não carrega tenta de novo', (tester) async {
    final repository = _Failing(const [], failFetch: true);
    await _pump(tester, repository: repository);
    await _openTeams(tester);
    expect(find.text(ptText.problemTeamFull), findsOneWidget);
    final before = repository.fetches;
    await tester.tap(find.text(ptText.tryAgain));
    await tester.pumpAndSettle();
    expect(repository.fetches, greaterThan(before));
    _go(tester, '/teams/1');
    await tester.pumpAndSettle();
    await tester.tap(find.text(ptText.tryAgain));
    await tester.pumpAndSettle();
    _go(tester, '/teams/1/members/0');
    await tester.pumpAndSettle();
    expect(find.text(ptText.problemTeamFull), findsOneWidget);
  });

  testWidgets('em inglês', (tester) async {
    final backend = teamBackend();
    final saved = await backend.saveTeam(_team);
    await _pump(tester, backend: backend, language: AppLanguage.en);
    await _openTeams(tester);
    expect(find.text('Scarlet / Violet · 1 of 6 · Level 100'), findsOneWidget);
    _go(tester, '/teams/${saved.id}/members/0');
    await tester.pumpAndSettle();
    expect(find.text('Team member'), findsOneWidget);
    await _reveal(tester, find.text('EVs and stats at level 100'));
    expect(find.text('0 of 510 EVs'), findsOneWidget);
    await _tapKey(tester, 'member-nature');
    expect(find.text('Not chosen'), findsWidgets);
    expect(find.text('Neutral'), findsOneWidget);
  });

  testWidgets('no Legends: Z-A: sem habilidade, Tera e exportação', (
    tester,
  ) async {
    final backend = teamBackend();
    final specimen = await backend.create(
      const SpecimenDraft(form: 1, nature: 'modest', ability: 'overgrow'),
    );
    final saved = await backend.saveTeam(
      const Team(
        id: 0,
        name: 'Megas de Lumiose',
        versionGroup: 'legends-za',
        members: [
          // A habilidade e o Tera de outro jogo saem ao gravar.
          TeamMember(
            form: 3,
            ability: 'overgrow',
            tera: 'fire',
            moves: ['tackle'],
          ),
        ],
      ),
    );
    expect(
      (saved.members.single.ability, saved.members.single.tera),
      (null, null),
    );
    await _pump(tester, backend: backend);
    await _openTeams(tester);
    expect(find.text('Legends: Z-A · 1 de 6 · Nível 50'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('team-${saved.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-export')), findsNothing);
    expect(
      find.text(
        'O Showdown não tem o Legends: Z-A, então este time não exporta.',
      ),
      findsOneWidget,
    );

    // Adicionar não escolhe habilidade, mesmo com uma só.
    await _tapKey(tester, 'team-add');
    await _pickForm(tester, 'bulb');
    expect(find.byKey(const ValueKey('member-ability')), findsNothing);
    expect(find.byKey(const ValueKey('member-tera')), findsNothing);
    expect(
      find.text('O Legends: Z-A não tem habilidades nem Terastalização.'),
      findsOneWidget,
    );
    await _reveal(tester, find.text(ptText.movesNoValues));
    // Ligar puxa só a natureza.
    await _tapKey(tester, 'member-link');
    await tester.tap(find.byKey(ValueKey('link-${specimen.id}')));
    await tester.pumpAndSettle();
    var member = (await backend.fetchTeams()).single.members.last;
    expect((member.nature, member.ability), ('modest', null));
    await _tapKey(tester, 'member-unlink');
    expect(
      find.text('Puxa a forma e a natureza do inventário'),
      findsOneWidget,
    );
    // Os golpes do Z-A, sem poder, precisão e PP.
    await _tapKey(tester, 'member-move-0');
    expect(
      find.text('2 golpes que Bulbasaur aprende em Legends: Z-A'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('pick-seed-bomb')));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsNWidgets(3));
    // Trocar a forma não traz habilidade.
    await _tapKey(tester, 'member-form');
    await _pickForm(tester, 'venu');
    member = (await backend.fetchTeams()).single.members.last;
    expect((member.formRef?.name, member.ability), ('venusaur', null));
  });

  group('sinergia (#374)', () {
    // Três Bulbasaur e o Venusaur (Water/Ground, 4× de Grass), com Trick
    // Room: buracos com e sem quem resista, tipos repetidos, sem golpe de
    // dano, só físicos e os lentos contando.
    const crowded = Team(
      id: 0,
      name: 'Trick Room',
      versionGroup: 'scarlet-violet',
      members: [
        TeamMember(form: 1, moves: ['tackle'], tera: 'water'),
        TeamMember(form: 1, moves: ['leech-seed', 'trick-room']),
        TeamMember(form: 1, moves: ['tackle'], tera: 'fire'),
        TeamMember(form: 3, moves: ['vine-whip']),
      ],
    );
    // Dois Bulbasaur: o Venusaur fecha o buraco de Fire numa vaga, e os dois
    // aprendem golpes que cobrem mais tipos.
    const pair = Team(
      id: 0,
      name: 'Dupla',
      versionGroup: 'scarlet-violet',
      members: [
        TeamMember(form: 1, moves: ['tackle']),
        TeamMember(form: 1, moves: ['leech-seed']),
      ],
    );

    testWidgets('o cartão no time e a tela (celular)', (tester) async {
      final backend = teamBackend();
      await backend.create(const SpecimenDraft(form: 3));
      final saved = await backend.saveTeam(pair);
      await _pump(tester, backend: backend);
      await _openTeams(tester);
      await tester.tap(find.byKey(ValueKey('team-${saved.id}')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sinergia '), findsOneWidget);
      expect(find.textContaining('buracos'), findsOneWidget);

      await _tapKey(tester, 'team-synergy');
      expect(find.text('Sinergia'), findsOneWidget);
      expect(find.text('Dupla'), findsOneWidget);
      expect(find.text('O que tira pontos'), findsOneWidget);
      expect(find.text('Buraco'), findsWidgets);
      expect(find.text('Sem golpe de dano'), findsOneWidget);
      expect(find.text('Nenhum membro rápido'), findsOneWidget);
      expect(find.text('4 vagas'), findsOneWidget);

      // Os golpes que o time já aprende levam ao membro.
      await _reveal(tester, find.text('Golpes que o time já aprende'));
      expect(find.text('Petal Dance · Bulbasaur'), findsOneWidget);
      // A forma numa vaga, marcada como do inventário.
      await _reveal(tester, find.text('Formas que fecham buracos'));
      expect(find.text('numa vaga'), findsOneWidget);
      expect(find.text('No inventário'), findsWidgets);
      await _reveal(tester, find.text('Defesa por tipo'));
      await _reveal(tester, find.byKey(const ValueKey('defense-fire')));
      await _reveal(tester, find.text('Cobertura em super efetivo'));
      await _reveal(tester, find.text('Velocidade no nível 50'));
      expect(
        find.text(
          'A linha marca 150: daí para cima o membro conta como rápido.',
        ),
        findsOneWidget,
      );
      await _reveal(
        tester,
        find.byKey(const ValueKey('sug-move-1-petal-dance')),
      );
      await tester.tap(find.byKey(const ValueKey('sug-move-1-petal-dance')));
      await tester.pumpAndSettle();
      expect(find.text('Membro do time'), findsOneWidget);
    });

    testWidgets('todos os descontos, o Tera e o Trick Room (PC)', (
      tester,
    ) async {
      final backend = teamBackend();
      final saved = await backend.saveTeam(crowded);
      await _pump(tester, size: expandedSize, backend: backend);
      await _openTeams(tester);
      _go(tester, '/teams/${saved.id}/synergy');
      await tester.pumpAndSettle();

      expect(find.text('Leva 4×'), findsOneWidget);
      expect(find.text('Tipo repetido'), findsWidgets);
      expect(find.text('Resistem a tudo'), findsOneWidget);
      expect(find.text('3 físicos · 0 especiais'), findsWidgets);
      expect(find.text('Se um membro terastalizar'), findsOneWidget);
      expect(find.textContaining('Bulbasaur · Tera Water'), findsOneWidget);
      expect(
        find.text(
          'A linha marca 80: com Trick Room, daí para baixo o membro conta.',
        ),
        findsOneWidget,
      );
      expect(find.text('Nenhuma sugestão aumenta a nota.'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('synergy-how')));
      await tester.pumpAndSettle();
      expect(find.text('Como a nota é feita'), findsWidgets);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('time que não existe e lista que não carrega', (tester) async {
      await _pump(tester);
      await _openTeams(tester);
      _go(tester, '/teams/999/synergy');
      await tester.pumpAndSettle();
      expect(find.text(ptText.problemNotFound), findsOneWidget);
    });

    testWidgets('a lista que não carrega', (tester) async {
      await _pump(tester, repository: _Failing(const [], failFetch: true));
      await _openTeams(tester);
      _go(tester, '/teams/1/synergy');
      await tester.pumpAndSettle();
      expect(find.text(ptText.problemTeamFull), findsOneWidget);
    });

    testWidgets('em inglês', (tester) async {
      final backend = teamBackend();
      final saved = await backend.saveTeam(pair);
      await _pump(tester, backend: backend, language: AppLanguage.en);
      await _openTeams(tester);
      _go(tester, '/teams/${saved.id}/synergy');
      await tester.pumpAndSettle();
      expect(find.text('Synergy'), findsOneWidget);
      expect(find.text('What lowers the score'), findsOneWidget);
      expect(find.text('No fast member'), findsOneWidget);
    });

    testWidgets(
      'Trick Room com um lento, o Tera que abre buraco e o time cheio',
      (tester) async {
        final backend = teamBackend();
        await backend.create(const SpecimenDraft(form: 133));
        // O Espeon sem espécime: fica depois das do inventário.
        for (final specimen in await backend.fetchSpecimensOfForm(196)) {
          await backend.release(specimen.id);
        }
        final room = await backend.saveTeam(
          const Team(
            id: 0,
            name: 'Um lento',
            versionGroup: 'scarlet-violet',
            members: [
              // O Stellar não muda a defesa: 0.
              TeamMember(
                form: 1,
                moves: ['tackle'],
                evs: {'speed': 252},
                tera: 'stellar',
              ),
              TeamMember(
                form: 3,
                moves: ['vine-whip', 'trick-room'],
                tera: 'grass',
              ),
            ],
          ),
        );
        final full = await backend.saveTeam(
          Team(
            id: 0,
            name: 'Seis',
            versionGroup: 'scarlet-violet',
            members: List.filled(
              6,
              const TeamMember(form: 1, moves: ['tackle']),
            ),
          ),
        );
        await _pump(tester, size: expandedSize, backend: backend);
        await _openTeams(tester);
        _go(tester, '/teams/${room.id}/synergy');
        await tester.pumpAndSettle();
        expect(find.text('Só um membro lento'), findsOneWidget);
        expect(find.textContaining('Tera Stellar'), findsOneWidget);
        expect(find.textContaining('Abre Fire'), findsOneWidget);
        expect(find.text('−8'), findsWidgets);

        _go(tester, '/teams/${full.id}/synergy');
        await tester.pumpAndSettle();
        expect(find.text('no lugar de Bulbasaur'), findsOneWidget);
        // As do inventário primeiro, e o resto em "mais".
        expect(find.text('mais 2'), findsOneWidget);
        final owned = await backend.fetchOwnedForms();
        final ids = [2, 3, 133, 134, 172, 196]
          ..sort((a, b) {
            final owns = (owned.contains(b) ? 1 : 0).compareTo(
              owned.contains(a) ? 1 : 0,
            );
            return owns != 0 ? owns : a.compareTo(b);
          });
        expect(
          readingOrder(tester, [
            for (final id in ids.take(4)) find.byKey(ValueKey('sug-form-$id')),
          ]),
          [0, 1, 2, 3],
        );
        expect(owned.contains(ids.first), isTrue);
        expect(owned.contains(ids.last), isFalse);
      },
    );

    testWidgets('sem nada que tire pontos', (tester) async {
      SynergyMember member(
        String name,
        List<String> types,
        List<String> moves,
        String category,
      ) => SynergyMember(
        name: name,
        types: types,
        speed: 200,
        moves: [
          for (final type in moves)
            (
              name: type,
              label: type,
              type: type,
              category: category,
              power: 90,
            ),
        ],
      );
      final synergy = Synergy.of([
        member('A', ['water'], ['fighting', 'ground'], 'physical'),
        member('B', ['steel'], ['flying', 'ice'], 'physical'),
        member('C', ['fairy'], ['fairy', 'fire'], 'special'),
        member('D', ['dragon'], ['ghost', 'electric'], 'special'),
        member('E', ['ground'], ['water', 'bug'], 'special'),
        member('F', ['ghost'], ['poison', 'rock'], 'physical'),
      ]);
      await pumpWidgetApp(
        tester,
        Scaffold(body: SynergyIssues(synergy: synergy)),
      );
      expect(synergy.issues, isEmpty);
      expect(find.text('Nada tira pontos.'), findsOneWidget);
    });
  });
}
