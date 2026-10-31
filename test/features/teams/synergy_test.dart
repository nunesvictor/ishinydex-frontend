import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/teams/domain/synergy.dart';

SynergyMove _m(String name, String type, String category, [int? power = 90]) =>
    (name: name, label: name, type: type, category: category, power: power);

// O time da #231, como no mock (golpes de dano e velocidade no nível 50).
final _calyrex = SynergyMember(
  name: 'Calyrex Shadow',
  types: const ['psychic', 'ghost'],
  speed: 222,
  moves: [
    _m('astral-barrage', 'ghost', 'special'),
    _m('psyshock', 'psychic', 'special'),
  ],
  tera: 'fairy',
);
final _ogerpon = SynergyMember(
  name: 'Ogerpon Cornerstone Mask',
  types: const ['grass', 'rock'],
  speed: 178,
  moves: [
    // O Ivy Cudgel com a Cornerstone Mask é Rock.
    _m('ivy-cudgel', 'rock', 'physical'),
    _m('horn-leech', 'grass', 'physical'),
  ],
  tera: 'rock',
);
final _urshifu = SynergyMember(
  name: 'Urshifu Rapid Strike',
  types: const ['fighting', 'water'],
  speed: 163,
  moves: [
    _m('surging-strikes', 'water', 'physical'),
    _m('close-combat', 'fighting', 'physical'),
    _m('aqua-jet', 'water', 'physical'),
    _m('u-turn', 'bug', 'physical'),
  ],
  tera: 'water',
);
final _incineroar = SynergyMember(
  name: 'Incineroar',
  types: const ['fire', 'dark'],
  speed: 80,
  moves: [
    _m('fake-out', 'normal', 'physical', 40),
    _m('flare-blitz', 'fire', 'physical'),
    _m('knock-off', 'dark', 'physical'),
  ],
  tera: 'ghost',
);
final _amoonguss = SynergyMember(
  name: 'Amoonguss',
  types: const ['grass', 'poison'],
  speed: 45,
  moves: [_m('pollen-puff', 'bug', 'special')],
  tera: 'water',
);
final _flutter = SynergyMember(
  name: 'Flutter Mane',
  types: const ['ghost', 'fairy'],
  speed: 205,
  moves: [
    _m('moonblast', 'fairy', 'special'),
    _m('shadow-ball', 'ghost', 'special'),
    _m('dazzling-gleam', 'fairy', 'special'),
  ],
  tera: 'fairy',
);
final List<SynergyMember> _teamA = [
  _calyrex,
  _ogerpon,
  _urshifu,
  _incineroar,
  _amoonguss,
  _flutter,
];

void main() {
  test('o time da #231: 85 (28 + 27 + 30)', () {
    final s = Synergy.of(_teamA);
    expect((s.defense, s.attack, s.balance, s.score), (28, 27, 30, 85));
    final hole = s.issues.whereType<HoleIssue>().single;
    expect((hole.type, hole.resisted), ('flying', false));
    expect(hole.weak, ['Urshifu Rapid Strike', 'Amoonguss']);
    expect(
      [for (final q in s.issues.whereType<QuadIssue>()) q.type],
      ['ghost', 'dark'],
    );
    final uncovered = s.issues.whereType<UncoveredIssue>().single;
    expect(uncovered.types, ['electric', 'fairy']);
    expect(uncovered.points, 3);
    expect(s.issues.whereType<WallIssue>(), isEmpty);
    expect((s.physical, s.special, s.trickRoom), (3, 3, false));
    final flying = s.rows.firstWhere((r) => r.type == 'flying');
    expect((flying.weak, flying.resist, flying.hole), (2, 0, true));
    expect(s.coverage['electric'], isEmpty);
    expect(s.coverage['dragon'], [
      (5, _flutter.moves.first),
      (5, _flutter.moves.last),
    ]);
  });

  test('o Tera de cada membro, sozinho', () {
    final s = Synergy.of(_teamA);
    final urshifu = s.teraOf(2, 'water');
    expect(urshifu.delta, 8);
    expect(urshifu.closes, ['flying']);
    expect(urshifu.opens, isEmpty);
    final calyrex = s.teraOf(0, 'fairy');
    expect(calyrex.delta, -4);
    expect(calyrex.opens, ['steel']);
    expect(calyrex.better, (type: 'water', delta: 4));
    expect(s.teraOf(5, 'fairy').delta, 0);
    expect(s.teraOf(3, 'ghost').delta, -8);
    // O Stellar não muda os tipos.
    expect(s.teraOf(5, 'stellar').delta, 0);
  });

  test('as sugestões de golpes e de formas', () {
    final s = Synergy.of(_teamA);
    final moves = s.moveSuggestions(
      (i) => switch (i) {
        4 => [
          _m('sludge-bomb', 'poison', 'special'),
          _m('giga-drain', 'grass', 'special', 75),
          // Fraco demais, ou da outra categoria.
          _m('mega-drain', 'grass', 'special', 40),
          _m('earthquake', 'ground', 'physical'),
        ],
        3 => [
          _m('earthquake', 'ground', 'physical', 100),
          _m('knock-off', 'dark', 'physical'),
        ],
        _ => const [],
      },
    );
    expect(
      [for (final m in moves) (m.index, m.move.name, m.gain, m.stab)],
      [(4, 'sludge-bomb', 2, true), (3, 'earthquake', 2, false)],
    );
    expect(
      [for (final m in moves) m.hits],
      [
        ['fairy'],
        ['electric'],
      ],
    );
    expect(s.moveSuggestions((i) => const [], limit: 1), isEmpty);

    final forms = s.formSuggestions({
      823: ['flying', 'steel'],
      227: ['steel', 'flying'],
      383: ['ground'],
      9999: ['grass', 'poison'],
    }, limit: 2);
    final best = forms.first;
    expect(best.types, ['flying', 'steel']);
    expect((best.replaces, best.gain), (0, 12));
    expect(best.closes, ['flying']);
    expect(best.forms, [823, 227]);
    expect(forms, hasLength(2));
    // Uma forma que não soma nada fica de fora.
    expect(
      s.formSuggestions({
        1: ['bug', 'grass'],
      }),
      isEmpty,
    );
  });

  test('o time incompleto e sem golpes de dano', () {
    final s = Synergy.of([_amoonguss, _incineroar, _calyrex]);
    expect((s.defense, s.attack, s.balance, s.score), (36, 18, 14, 68));
    expect(s.issues.whereType<EmptySlotsIssue>().single.count, 3);
    final speed = s.issues.whereType<SpeedIssue>().single;
    expect((speed.count, speed.points, speed.trickRoom), (1, 5, false));
    final mix = s.issues.whereType<MixIssue>().single;
    expect((mix.physical, mix.special, mix.points), (1, 2, 5));

    // Com Trick Room, contam os lentos (80 ou menos).
    final room = Synergy.of([
      SynergyMember(
        name: 'Amoonguss',
        types: _amoonguss.types,
        speed: 45,
        moves: _amoonguss.moves,
        trickRoom: true,
      ),
      _incineroar,
      _calyrex,
    ]);
    expect(room.balance, 19);
    expect(room.issues.whereType<SpeedIssue>(), isEmpty);
    // A forma numa vaga.
    expect(
      room
          .formSuggestions({
            473: ['ice', 'ground'],
          })
          .single
          .replaces,
      isNull,
    );

    final empty = Synergy.of(const [
      SynergyMember(name: 'A', types: ['normal']),
      SynergyMember(name: 'B', types: ['normal']),
      SynergyMember(name: 'C', types: ['normal']),
      SynergyMember(name: 'D', types: ['normal']),
      SynergyMember(name: 'E', types: ['normal']),
      SynergyMember(name: 'F', types: ['normal']),
    ]);
    expect(empty.issues.whereType<RepeatedTypeIssue>().single.count, 6);
    expect(empty.issues.whereType<NoDamageIssue>(), hasLength(6));
    expect(empty.balance, 0);
    // Sem golpe, todos os tipos "resistem" e nada é coberto.
    expect(empty.attack, 0);
    expect(empty.issues.whereType<WallIssue>().single.points, 6);
  });

  test('a habilidade e as gerações sem Fairy', () {
    const levitate = SynergyMember(
      name: 'Rotom',
      types: ['electric'],
      ability: 'levitate',
    );
    final s = Synergy.of([levitate]);
    expect(s.rows.firstWhere((r) => r.type == 'ground').multipliers, [0]);
    const old = SynergyRules(withFairy: false);
    expect(old.types, isNot(contains('fairy')));
    final steel = Synergy.of(const [
      SynergyMember(name: 'Steelix', types: ['steel']),
    ], rules: old);
    expect(steel.rows.firstWhere((r) => r.type == 'ghost').multipliers, [0.5]);
    // 3 fracos é buraco, mesmo com alguém que resiste.
    final three = Synergy.of(const [
      SynergyMember(name: 'A', types: ['grass']),
      SynergyMember(name: 'B', types: ['grass']),
      SynergyMember(name: 'C', types: ['grass']),
      SynergyMember(name: 'D', types: ['fire']),
    ]);
    expect(
      three.issues
          .whereType<HoleIssue>()
          .firstWhere((h) => h.type == 'fire')
          .resisted,
      isTrue,
    );
    expect(
      three.issues
          .whereType<HoleIssue>()
          .firstWhere((h) => h.type == 'flying')
          .resisted,
      isFalse,
    );
  });
}
