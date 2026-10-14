import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_odds.dart';

/// 1/x arredondado, para comparar com as tabelas da curadoria.
int x(double chance) => (1 / chance).round();

OddsRule rule(Map<String, dynamic> json) => OddsRule.fromJson({
  'method': 'm',
  'versions': ['sword'],
  'base': 4096,
  ...json,
});

final OddsRule sos = rule({
  'kind': 'rolls',
  'rolls': 1,
  'charm': 2,
  'chain': {
    'steps': [
      {'from': 0, 'rolls': 0},
      {'from': 11, 'rolls': 4},
      {'from': 21, 'rolls': 8},
      {'from': 31, 'rolls': 12},
    ],
    'resetAfter': 255,
  },
});

final OddsRule dexnav = rule({
  'kind': 'dexnav',
  'rolls': 1,
  'charm': 2,
  'modifiers': [
    {
      'id': 'searchLevel',
      'label': 'Search Level',
      'type': 'number',
      'min': 0,
      'max': 999,
      'followsCount': true,
    },
  ],
});

void main() {
  test('nota, modificadores e opções em cada idioma (backend#105)', () {
    final labeled = rule({
      'kind': 'rolls',
      'note': 'Nota.',
      'notes': {'en': 'Note.', 'pt-BR': 'Nota.'},
      'modifiers': [
        {
          'id': 'lure',
          'label': 'Lure',
          'labels': {'en': 'Lure', 'pt-BR': 'Lure'},
          'type': 'choice',
          'options': [
            {
              'label': 'Sem',
              'labels': {'en': 'Off', 'pt-BR': 'Sem'},
              'rolls': 0,
            },
          ],
        },
      ],
    });
    expect(labeled.notes['en'], 'Note.');
    final lure = labeled.modifiers.single;
    expect(lure.labels['pt-BR'], 'Lure');
    expect(lure.options.single.labels['en'], 'Off');
    // Catálogo antigo: sem os labels.
    expect(sos.notes, isEmpty);
    expect(dexnav.modifiers.single.labels, isEmpty);
  });

  group('regras', () {
    test('sorteios: base, Charm, exceções e base 8192', () {
      final r = rule({
        'kind': 'rolls',
        'rolls': 1,
        'charm': 2,
        'charmExceptForms': [7],
        'note': 'Nota.',
      });
      expect(x(r.chance(form: 1, hasCharm: false)), 4096);
      expect(x(r.chance(form: 1, hasCharm: true)), 1366);
      // Regidrago: o Charm não vale.
      expect(r.charmApplies(7, hasCharm: true), isFalse);
      expect(x(r.chance(form: 7, hasCharm: true)), 4096);
      expect(r.note, 'Nota.');
      expect(r.hasChain, isFalse);
      final frlg = rule({'kind': 'rolls', 'base': 8192});
      expect(x(frlg.chance(form: 1, hasCharm: true)), 8192);
      expect(frlg.charmCounts, isFalse);
      expect(x(rollsChance(41)), 100);
    });

    test('modificadores: escolha, condição e o padrão', () {
      final swsh = rule({
        'kind': 'rolls',
        'charm': 2,
        'modifiers': [
          {
            'id': 'aura',
            'label': 'Encontros',
            'type': 'choice',
            'options': [
              {'label': 'Todos', 'rolls': 0},
              {'label': 'Só os com aura', 'rolls': 0},
            ],
          },
          {
            'id': 'battled',
            'label': 'Derrotados',
            'type': 'choice',
            'options': [
              {'label': '0', 'rolls': 0},
              {'label': '500+', 'rolls': 6},
            ],
            'when': {'modifier': 'aura', 'option': 1},
          },
        ],
      });
      expect(swsh.visibleModifiers({}).map((m) => m.id), ['aura']);
      // Sem aura, os derrotados não contam, nem se estiverem marcados.
      expect(
        x(swsh.chance(form: 1, hasCharm: true, values: {'battled': 1})),
        1366,
      );
      final aura = {'aura': 1, 'battled': 1};
      expect(swsh.visibleModifiers(aura).map((m) => m.id), ['aura', 'battled']);
      expect(x(swsh.chance(form: 1, hasCharm: true, values: aura)), 456);
      expect(x(swsh.chance(form: 1, hasCharm: false, values: aura)), 586);
      // Valor fora das opções: fica na última.
      expect(swsh.modifiers[1].rollsFor(9), 6);
      expect(swsh.modifiers[1].isNumber, isFalse);
    });

    test('cadeia em sorteios (SOS)', () {
      expect(sos.hasChain, isTrue);
      expect(sos.resetAfter, 255);
      expect(x(sos.chance(form: 1, hasCharm: false, chain: 10)), 4096);
      expect(x(sos.chance(form: 1, hasCharm: false, chain: 11)), 820);
      expect(x(sos.chance(form: 1, hasCharm: true, chain: 34)), 274);
    });

    test('chance: fixa, por cadeia (Radar do XY) e por tabela', () {
      final da = rule({'kind': 'chance', 'odds': 300, 'charmOdds': 100});
      expect(x(da.chance(form: 1, hasCharm: false)), 300);
      expect(x(da.chance(form: 1, hasCharm: true)), 100);
      final tera = rule({'kind': 'chance', 'odds': 4103.05});
      expect(tera.charmCounts, isFalse);
      expect(x(tera.chance(form: 1, hasCharm: true)), 4103);

      final radar = rule({
        'kind': 'chance',
        'chain': {
          'steps': [
            {'from': 0, 'odds': 4096, 'charmOdds': 1365.67},
            {'from': 1, 'odds': 7900},
            {'from': 40, 'odds': 100},
          ],
        },
      });
      expect(radar.charmCounts, isTrue);
      expect(x(radar.chance(form: 1, hasCharm: true)), 1366);
      // Na cadeia, o Charm não vale.
      expect(x(radar.chance(form: 1, hasCharm: true, chain: 5)), 7900);
      expect(x(radar.chance(form: 1, hasCharm: false, chain: 80)), 100);

      final uwr = rule({
        'kind': 'chance',
        'modifiers': [
          {
            'id': 'rings',
            'label': 'Anéis',
            'type': 'choice',
            'options': [
              {'label': '0', 'rolls': 0},
              {'label': '1', 'rolls': 0},
            ],
          },
          {
            'id': 'distance',
            'label': 'Distância',
            'type': 'choice',
            'options': [
              {'label': 'perto', 'rolls': 0},
              {'label': 'longe', 'rolls': 0},
            ],
          },
        ],
        'table': {
          'rows': 'rings',
          'columns': 'distance',
          'odds': [
            [100, 100],
            [null, 10],
          ],
        },
      });
      expect(x(uwr.chance(form: 1, hasCharm: true)), 100);
      expect(
        x(
          uwr.chance(
            form: 1,
            hasCharm: false,
            values: {'rings': 1, 'distance': 1},
          ),
        ),
        10,
      );
      // Combinação que não existe.
      expect(uwr.chance(form: 1, hasCharm: false, values: {'rings': 1}), 0);
    });

    test('DexNav bate com a tabela da curadoria', () {
      int at(int level, int encounter, {bool charm = false}) => x(
        dexNavChance(searchLevel: level, encounter: encounter, charm: charm),
      );
      expect(at(0, 1), 4096);
      expect(at(0, 1, charm: true), 1366);
      expect(
        [at(100, 1), at(100, 5), at(100, 50), at(100, 100)],
        [1064, 309, 161, 109],
      );
      expect([at(200, 1), at(999, 100)], [853, 42]);
      expect(at(100, 100, charm: true), 92);
      expect(dexnav.hasChain, isTrue);
      // A cadeia atual é o número de encontros: o próximo é o 5º.
      expect(
        x(
          dexnav.chance(
            form: 1,
            hasCharm: false,
            values: {'searchLevel': 100},
            chain: 4,
          ),
        ),
        309,
      );
      expect(dexnav.modifiers.single.isNumber, isTrue);
      expect(dexnav.modifiers.single.rollsFor(3), 0);
    });

    test('oddsLabel', () {
      expect(oddsLabel(1 / 1365.67), '1/1366');
      expect(oddsLabel(1 / 5.26), '1/5,3');
      expect(oddsLabel(0), '—');
    });
  });

  group('caçada', () {
    const hunt = ShinyHunt(id: 1, form: 1);

    test('+1 acumula a chance, soma na cadeia e na maior; −1 desfaz', () {
      var h = hunt.advanced(sos, 31, hasCharm: true);
      expect((h.count, h.chain, h.bestChain), (31, 31, 31));
      final miss = h.miss!;
      h = h.advanced(sos, 1, hasCharm: true);
      expect(h.miss, closeTo(miss * (1 - 15 / 4096), 1e-4));
      h = h.advanced(sos, -1, hasCharm: true);
      expect(h.miss, closeTo(miss, 1e-9));
      expect((h.count, h.chain, h.bestChain), (31, 31, 32));
      // "Quebrou": a cadeia volta a 0; total e maior ficam.
      h = h.broken();
      expect((h.count, h.chain, h.bestChain), (31, 0, 32));
      // O −1 para no 0 e zera a chance acumulada.
      h = h.advanced(sos, -99, hasCharm: true);
      expect((h.count, h.chain, h.miss), (0, 0, 1.0));
    });

    test('SOS no Sun/Moon: a cadeia volta a 0 depois de 255', () {
      final h = hunt
          .copyWith(chain: 255, bestChain: 255)
          .advanced(sos, 1, hasCharm: false);
      expect((h.chain, h.bestChain), (0, 255));
    });

    test('o Search Level acompanha a contagem', () {
      var h = hunt
          .copyWith(modifiers: {'searchLevel': 998})
          .advanced(dexnav, 3, hasCharm: false);
      expect(h.modifiers['searchLevel'], 999);
      h = hunt.advanced(dexnav, 2, hasCharm: false);
      expect(h.modifiers['searchLevel'], 2);
      expect(
        h.advanced(dexnav, -1, hasCharm: false).modifiers['searchLevel'],
        1,
      );
    });

    test('sem registro, a conta usa as odds atuais; o múltiplo', () {
      final flat = rule({'kind': 'rolls', 'charm': 2});
      final h = hunt.copyWith(count: 1366);
      expect(h.miss, isNull);
      expect(
        h.missChance(flat, hasCharm: true),
        closeTo(pow(1 - 3 / 4096, 1366), 1e-3),
      );
      expect(h.multiple(flat, hasCharm: true), closeTo(1.0, 0.01));
      expect(
        hunt.copyWith(miss: 0).multiple(flat, hasCharm: true),
        double.infinity,
      );
      // Sem cadeia, o +1 não mexe na cadeia.
      expect(h.advanced(flat, 1, hasCharm: true).chain, 0);
    });

    test('contagem digitada: estimada nos métodos de cadeia', () {
      final flat = rule({'kind': 'rolls'});
      final typed = hunt.withCount(flat, 4096, hasCharm: false);
      expect(typed.estimated, isFalse);
      expect(typed.miss, closeTo(pow(1 - 1 / 4096, 4096), 1e-6));
      expect(typed.withCount(flat, 0, hasCharm: false).miss, 1);
      final chained = hunt.withCount(sos, 50, hasCharm: false);
      expect(chained.estimated, isTrue);
      expect(chained.withCount(sos, 50, hasCharm: false).estimated, isTrue);
      expect(hunt.withCount(sos, 0, hasCharm: false).estimated, isFalse);
    });

    test('registro no fim: odds, múltiplo e maior cadeia', () {
      final now = DateTime(2026, 10, 9);
      final h = hunt.copyWith(method: 'm').advanced(sos, 40, hasCharm: true);
      final record = h.toRecord(now, rule: sos, hasCharm: true);
      expect(record.odds, closeTo(273.53, 0.01));
      expect(record.multiple, closeTo(h.multiple(sos, hasCharm: true), 1e-9));
      expect(record.bestChain, 40);
      // Sem regra, como antes.
      final plain = h.toRecord(now);
      expect((plain.odds, plain.multiple), (null, null));
      // Em horas: odds, sem múltiplo.
      final timed = hunt.copyWith(unit: 'hours', accumulatedSeconds: 3600);
      final record2 = timed.toRecord(now, rule: sos);
      expect(
        (record2.odds, record2.multiple, record2.bestChain),
        (4096, null, null),
      );
    });
  });
}
