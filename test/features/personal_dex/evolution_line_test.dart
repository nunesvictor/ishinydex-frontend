import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/evolution_line.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/species_info.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../helpers/helpers.dart';

FormRef _ref(int id, String name) => FormRef(
  id: id,
  name: name,
  pokeapiId: id,
  spriteUrl: 'https://img/$id.png',
  shinySpriteUrl: 'https://img/shiny/$id.png',
);

final FormRef _bulba = _ref(1, 'bulbasaur');
final FormRef _ivy = _ref(2, 'ivysaur');
final FormRef _venu = _ref(3, 'venusaur');
final FormRef _eevee = _ref(133, 'eevee');
final FormRef _vapor = _ref(134, 'vaporeon');
final FormRef _leaf = _ref(470, 'leafeon');
final FormRef _qwil = _ref(10234, 'qwilfish-hisui');
final FormRef _overqwil = _ref(904, 'overqwil');

EvolutionMethod _m(
  String trigger, {
  String group = 'scarlet-violet',
  List<String> versions = const ['scarlet', 'violet'],
  bool isDefault = true,
  int? minLevel,
  String? item,
  String? itemSpriteUrl,
  String? usedMove,
  int? minMoveCount,
  String? knownMove,
}) => EvolutionMethod(
  versionGroup: group,
  versions: versions,
  trigger: trigger,
  isDefault: isDefault,
  minLevel: minLevel,
  item: item,
  itemSpriteUrl: itemSpriteUrl,
  usedMove: usedMove,
  minMoveCount: minMoveCount,
  knownMove: knownMove,
);

FormDetail _detail(
  FormRef current,
  List<List<FormRef>> chain,
  List<EvolutionEdge> edges,
) => FormDetail(
  id: current.id,
  name: current.name,
  pokeapiId: current.id,
  spriteUrl: current.spriteUrl,
  shinySpriteUrl: current.shinySpriteUrl,
  evolutionChain: chain,
  evolutionEdges: edges,
);

/// Bulbasaur → Ivysaur (Nv. 16) → Venusaur (Nv. 32): na horizontal.
final FormDetail _bulbaLine = _detail(
  _bulba,
  [
    [_bulba],
    [_ivy],
    [_venu],
  ],
  [
    EvolutionEdge(fromId: 1, toId: 2, methods: [_m('level-up', minLevel: 16)]),
    EvolutionEdge(fromId: 2, toId: 3, methods: [_m('level-up', minLevel: 32)]),
  ],
);

/// Eevee → Vaporeon (pedra) e Leafeon (pedra hoje, perto da pedra antes):
/// com ramos, na vertical.
final FormDetail _eeveeLine = _detail(
  _eevee,
  [
    [_eevee],
    [_vapor, _leaf],
  ],
  [
    EvolutionEdge(
      fromId: 133,
      toId: 134,
      methods: [
        _m(
          'use-item',
          group: 'red-blue',
          versions: ['red', 'blue'],
          item: 'Water Stone',
          itemSpriteUrl: 'https://img/items/water-stone.png',
        ),
      ],
    ),
    EvolutionEdge(
      fromId: 133,
      toId: 470,
      methods: [
        const EvolutionMethod(
          versionGroup: 'diamond-pearl',
          versions: ['diamond', 'pearl'],
          trigger: 'level-up',
          location: 'Eterna Forest',
          nearSpecialRock: true,
        ),
        _m(
          'use-item',
          group: 'sword-shield',
          versions: ['sword', 'shield'],
          item: 'Leaf Stone',
        ),
      ],
    ),
  ],
);

/// Qwilfish de Hisui → Overqwil: um método por jogo, e as DLCs pelo nome.
final FormDetail _qwilLine = _detail(
  _overqwil,
  [
    [_qwil],
    [_overqwil],
  ],
  [
    EvolutionEdge(
      fromId: 10234,
      toId: 904,
      methods: [
        _m(
          'strong-style-move',
          group: 'legends-arceus',
          versions: ['legends-arceus'],
          isDefault: false,
          usedMove: 'Barb Barrage',
          minMoveCount: 20,
        ),
        _m('level-up', knownMove: 'Barb Barrage'),
        _m(
          'use-move',
          group: 'legends-za',
          versions: ['legends-za'],
          isDefault: false,
          usedMove: 'Barb Barrage',
          minMoveCount: 20,
        ),
      ],
    ),
  ],
);

const _runerigusLink =
    'https://bulbapedia.bulbagarden.net/wiki/Runerigus_(Pok%C3%A9mon)';

/// Yamask de Galar → Runerigus: a frase curada e o link.
final FormDetail _yamaskLine = _detail(
  _ref(10179, 'yamask-galar'),
  [
    [_ref(10179, 'yamask-galar')],
    [_ref(867, 'runerigus')],
  ],
  [
    const EvolutionEdge(
      fromId: 10179,
      toId: 867,
      methods: [
        EvolutionMethod(
          versionGroup: 'the-crown-tundra',
          versions: ['the-crown-tundra'],
          trigger: 'take-damage',
          isDefault: true,
          location: 'Dusty Bowl',
          minDamageTaken: 49,
        ),
      ],
      texts: {
        'en': 'Walk under the stone arch in the Dusty Bowl',
        'pt-BR': 'Passar sob o arco de pedra do Dusty Bowl',
      },
      link: _runerigusLink,
    ),
  ],
);

Widget _line(FormDetail form) => Scaffold(
  body: SingleChildScrollView(child: SpeciesInfo(form: form)),
);

void main() {
  group('modelos', () {
    test('o método mostrado e o ⓘ', () {
      final qwil = _qwilLine.evolutionEdges.single;
      expect(qwil.main?.versionGroup, 'scarlet-violet');
      expect(qwil.hasMore, true);
      expect(_eeveeLine.evolutionEdges.last.main?.versionGroup, 'sword-shield');
      // Sem padrão, o primeiro; sem métodos, nenhum.
      final noDefault = EvolutionEdge(
        fromId: 1,
        toId: 2,
        methods: [
          _m('trade', isDefault: false, group: 'x-y'),
          _m('trade', isDefault: false),
        ],
      );
      expect(noDefault.main?.versionGroup, 'x-y');
      expect(const EvolutionEdge(fromId: 1, toId: 2).main, isNull);
      expect(const EvolutionEdge(fromId: 1, toId: 2).hasMore, false);
      expect(
        const EvolutionEdge(fromId: 1, toId: 2, link: 'https://x').hasMore,
        true,
      );
    });

    test('curto: só o nível, só o item ou só a troca', () {
      expect(_m('level-up', minLevel: 16).isShort, true);
      expect(_m('level-up').isShort, false);
      expect(_m('level-up', minLevel: 16, knownMove: 'X').isShort, false);
      expect(_m('use-item', item: 'Water Stone').isShort, true);
      expect(_m('trade').isShort, true);
      expect(
        const EvolutionMethod(
          versionGroup: 'g',
          trigger: 'trade',
          heldItem: 'Metal Coat',
        ).isShort,
        false,
      );
      expect(_m('spin').isShort, false);
      // Todas as condições contam.
      const all = EvolutionMethod(
        versionGroup: 'g',
        trigger: 'use-item',
        item: 'i',
        heldItem: 'h',
        knownMove: 'k',
        knownMoveType: 'fairy',
        usedMove: 'u',
        minMoveCount: 1,
        location: 'l',
        nearSpecialRock: true,
        timeOfDay: 'day',
        minHappiness: 1,
        minAffection: 1,
        minBeauty: 1,
        gender: 'female',
        region: 'galar',
        relativePhysicalStats: 0,
        allowedNatures: ['hardy'],
        needsOverworldRain: true,
        needsMultiplayer: true,
        turnUpsideDown: true,
        tradeSpecies: 's',
        partySpecies: 'p',
        partyType: 'dark',
        minSteps: 1,
        minDamageTaken: 1,
        chance: 1,
      );
      expect(all.isShort, false);
    });

    test('ida e volta em JSON', () {
      final edge = _eeveeLine.evolutionEdges.last;
      expect(EvolutionEdge.fromJson(edge.toJson()), edge);
    });
  });

  group('a frase do método', () {
    String en(EvolutionMethod m) => evolutionMethodText(enText, m);
    String pt(EvolutionMethod m) => evolutionMethodText(ptText, m);
    EvolutionMethod lv({
      String trigger = 'level-up',
      int? minLevel,
      int? minHappiness,
      int? minAffection,
      int? minBeauty,
    }) => EvolutionMethod(
      versionGroup: 'g',
      trigger: trigger,
      minLevel: minLevel,
      minHappiness: minHappiness,
      minAffection: minAffection,
      minBeauty: minBeauty,
    );

    test('gatilhos', () {
      expect(pt(lv(minLevel: 16)), 'Nv. 16');
      expect(en(lv(minLevel: 16)), 'Lv. 16');
      expect(pt(lv(minHappiness: 160)), 'Amizade alta');
      expect(pt(lv(minAffection: 2)), 'Afeto alto');
      expect(pt(lv(minBeauty: 170)), 'Beleza alta');
      expect(pt(lv()), 'Subir de nível');
      expect(pt(_m('use-item', item: 'Water Stone')), 'Water Stone');
      expect(pt(_m('use-item')), 'Use Item');
      expect(pt(_m('trade')), 'Troca');
      expect(
        pt(
          const EvolutionMethod(
            versionGroup: 'g',
            trigger: 'trade',
            heldItem: 'Prism Scale',
          ),
        ),
        'Troca segurando Prism Scale',
      );
      expect(
        pt(
          const EvolutionMethod(
            versionGroup: 'g',
            trigger: 'trade',
            tradeSpecies: 'Shelmet',
          ),
        ),
        'Troca por Shelmet',
      );
      expect(pt(_m('spin')), 'Girar o personagem');
      expect(
        pt(lv(trigger: 'in-battle-level-up', minLevel: 25)),
        'Nv. 25 durante uma batalha',
      );
      expect(
        pt(lv(trigger: 'in-battle-level-up')),
        'Nv. 1 durante uma batalha',
      );
      expect(
        pt(
          const EvolutionMethod(
            versionGroup: 'g',
            trigger: 'recoil-damage',
            minDamageTaken: 294,
          ),
        ),
        'Perder 294 de HP por recuo, sem desmaiar',
      );
      expect(
        pt(lv(trigger: 'recoil-damage')),
        'Perder 0 de HP por recuo, sem desmaiar',
      );
      expect(pt(lv(trigger: 'take-damage')), 'Perder 0 de HP sem desmaiar');
      expect(
        pt(_m('use-move', usedMove: 'Rage Fist', minMoveCount: 20)),
        'Usar Rage Fist 20 vezes',
      );
      expect(pt(_m('use-move')), 'Usar  1 vezes');
      expect(
        pt(
          _m('agile-style-move', usedMove: 'Psyshield Bash', minMoveCount: 20),
        ),
        'Usar Psyshield Bash 20 vezes no estilo ágil',
      );
      expect(pt(_m('agile-style-move')), 'Usar  1 vezes no estilo ágil');
      expect(
        en(_m('strong-style-move', usedMove: 'Barb Barrage', minMoveCount: 20)),
        'Use Barb Barrage 20 times in Strong Style',
      );
      expect(pt(_m('strong-style-move')), 'Usar  1 vezes no estilo forte');
      for (final (trigger, text) in [
        ('gimmighoul-coins', 'Juntar 999 Gimmighoul Coins'),
        ('tower-of-darkness', 'Vencer a Tower of Darkness'),
        ('tower-of-waters', 'Vencer a Tower of Waters'),
        ('meltan-candies', '400 Meltan Candy no Pokémon GO'),
        ('three-critical-hits', 'Acertar 3 golpes críticos numa batalha'),
        (
          'three-defeated-bisharp',
          "Derrotar 3 Bisharp que seguram Leader's Crest",
        ),
        ('shed', 'Espaço livre no grupo e uma Poké Ball'),
        // Gatilho novo: pelo nome.
        ('dance-battle', 'Dance Battle'),
      ]) {
        expect(pt(_m(trigger)), text, reason: trigger);
      }
    });

    test('condições', () {
      expect(
        pt(
          const EvolutionMethod(
            versionGroup: 'g',
            trigger: 'level-up',
            minHappiness: 160,
            timeOfDay: 'day',
          ),
        ),
        'Amizade alta, de dia',
      );
      // Sem vírgula depois do genérico.
      expect(
        pt(_m('level-up', knownMove: 'Barb Barrage')),
        'Subir de nível sabendo Barb Barrage',
      );
      expect(
        pt(
          const EvolutionMethod(
            versionGroup: 'g',
            trigger: 'level-up',
            minLevel: 20,
            minHappiness: 220,
            heldItem: 'Oval Stone',
            knownMoveType: 'fairy',
            timeOfDay: 'night',
            location: 'Eterna Forest',
            nearSpecialRock: true,
            region: 'hisui',
            gender: 'female',
            relativePhysicalStats: 1,
            allowedNatures: ['hardy', 'docile'],
            needsOverworldRain: true,
            needsMultiplayer: true,
            turnUpsideDown: true,
            partySpecies: 'Remoraid',
            partyType: 'dark',
            minSteps: 1000,
            chance: 50,
          ),
        ),
        'Nv. 20, amizade alta, segurando Oval Stone, sabendo um golpe do tipo '
        'Fairy, à noite, em Eterna Forest, perto de uma pedra especial, em '
        'Hisui, só fêmea, Ataque > Defesa, natureza Hardy, Docile, com chuva, '
        'jogando com outra pessoa, com o console de cabeça para baixo, com '
        'Remoraid no grupo, com um Pokémon do tipo Dark no grupo, depois de '
        'andar 1.000 passos, 50% de chance',
      );
      String time(String t) => en(
        EvolutionMethod(versionGroup: 'g', trigger: 'level-up', timeOfDay: t),
      );
      expect(time('dusk'), 'Level up at dusk');
      expect(time('full-moon'), 'Level up under a full moon');
      expect(time('eclipse'), 'Level up Eclipse');
      String stats(int s, {String gender = 'male'}) => en(
        EvolutionMethod(
          versionGroup: 'g',
          trigger: 'level-up',
          minLevel: 20,
          gender: gender,
          relativePhysicalStats: s,
        ),
      );
      expect(stats(-1), 'Lv. 20, male only, Attack < Defense');
      expect(stats(0), 'Lv. 20, male only, Attack = Defense');
      expect(
        en(
          const EvolutionMethod(
            versionGroup: 'g',
            trigger: 'use-item',
            item: 'Thunder Stone',
            chance: 1.5,
          ),
        ),
        'Thunder Stone, 1.5% chance',
      );
    });

    test('o jogo: as versões do grupo; nas DLCs, o nome do grupo', () {
      expect(evolutionGameLabel(_m('trade')), 'Scarlet / Violet');
      expect(
        evolutionGameLabel(
          _m('trade', group: 'legends-za', versions: ['legends-za']),
        ),
        'Legends: Z-A',
      );
      expect(
        evolutionGameLabel(
          _m('trade', group: 'the-teal-mask', versions: ['the-teal-mask']),
        ),
        'The Teal Mask',
      );
      expect(
        evolutionGameLabel(_m('trade', group: 'champions', versions: [])),
        'Champions',
      );
    });
  });

  group('a linha', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('sem ramos e curta: na horizontal, o método na seta '
          '(${size.width.toInt()}px)', (tester) async {
        await pumpWidgetApp(tester, _line(_bulbaLine), size: size);

        expect(find.text('Linha evolutiva'), findsOneWidget);
        expect(find.text('Nv. 16'), findsOneWidget);
        expect(find.text('Nv. 32'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward), findsNWidgets(2));
        expect(find.byIcon(Icons.info_outline), findsNothing);
      });

      testWidgets('com ramos: na vertical, o item e o ⓘ '
          '(${size.width.toInt()}px)', (tester) async {
        await pumpWidgetApp(tester, _line(_eeveeLine), size: size);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.subdirectory_arrow_right), findsNWidgets(2));
        expect(find.text('Water Stone'), findsOneWidget);
        expect(find.text('Leaf Stone'), findsOneWidget);
        // O ícone do item (que falha no teste e cai no espaço vazio).
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is NetworkImage &&
                (w.image as NetworkImage).url.contains('items/water-stone'),
          ),
          findsOneWidget,
        );
        // Só a Leafeon tem outros jogos.
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });
    }

    testWidgets('sem métodos (catálogo antigo): a linha de antes', (
      tester,
    ) async {
      await pumpWidgetApp(
        tester,
        _line(
          _bulbaLine.copyWith(
            evolutionEdges: const [
              EvolutionEdge(fromId: 1, toId: 2),
              EvolutionEdge(fromId: 2, toId: 3),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('linha longa na vertical: a forma atual em destaque e '
        'os estágios recuados', (tester) async {
      // Bulbasaur → Ivysaur → Venusaur com um método longo: vertical.
      final line = _bulbaLine.copyWith(
        id: 2,
        evolutionEdges: [
          _bulbaLine.evolutionEdges.first,
          EvolutionEdge(
            fromId: 2,
            toId: 3,
            methods: [_m('level-up', knownMove: 'Petal Dance')],
          ),
          // Uma ligação que não está na linha fica de fora.
          const EvolutionEdge(fromId: 3, toId: 99),
          // E uma repetida, também.
          const EvolutionEdge(fromId: 1, toId: 2),
        ],
      );
      final opened = <int>[];
      await pumpWidgetApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: SpeciesInfo(form: line, onOpenForm: (f) => opened.add(f.id)),
          ),
        ),
      );

      expect(find.text('Subir de nível sabendo Petal Dance'), findsOneWidget);
      final rows = tester.widgetList<Padding>(
        find.ancestor(
          of: find.byIcon(Icons.subdirectory_arrow_right),
          matching: find.byType(Padding),
        ),
      );
      expect(
        rows.map((p) => p.padding).toSet(),
        containsAll([
          const EdgeInsets.only(left: 12),
          const EdgeInsets.only(left: 40),
        ]),
      );
      await tester.tap(find.text('Venusaur'));
      await tester.tap(find.text('Bulbasaur'));
      expect(opened, [3, 1]);
    });

    testWidgets('o ⓘ: o mostrado primeiro, depois do mais novo ao mais '
        'antigo', (tester) async {
      await pumpWidgetApp(tester, _line(_qwilLine));
      expect(find.text('Subir de nível sabendo Barb Barrage'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('evolution-info-904')));
      await tester.pumpAndSettle();

      expect(find.text('Como evolui'), findsOneWidget);
      expect(find.text('Mostrado'), findsOneWidget);
      final games = [
        for (final t in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(EvolutionSheet),
            matching: find.byType(Text),
          ),
        ))
          t.data,
      ];
      expect(
        games.where(
          (g) => const [
            'Scarlet / Violet',
            'Legends: Z-A',
            'Legends: Arceus',
          ].contains(g),
        ),
        ['Scarlet / Violet', 'Legends: Z-A', 'Legends: Arceus'],
      );
      expect(
        find.text('Usar Barb Barrage 20 vezes no estilo forte'),
        findsOneWidget,
      );
      expect(find.text('Veja mais na Bulbapedia'), findsNothing);
    });

    testWidgets('frase curada e o link "Veja mais", nos dois idiomas', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpWidgetApp(
        tester,
        _line(_yamaskLine),
        overrides: [openLinkProvider.overrideWithValue(opened.add)],
      );
      expect(
        find.text('Passar sob o arco de pedra do Dusty Bowl'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('evolution-info-867')));
      await tester.pumpAndSettle();
      // No ⓘ, o jogo da DLC pelo nome e a mesma frase curada.
      expect(find.text('The Crown Tundra'), findsOneWidget);
      expect(
        find.text('Passar sob o arco de pedra do Dusty Bowl'),
        findsNWidgets(2),
      );
      await tester.tap(find.text('Veja mais na Bulbapedia'));
      expect(opened, [_runerigusLink]);
    });

    testWidgets('frase curada em inglês', (tester) async {
      await pumpWidgetApp(tester, _line(_yamaskLine), locale: english);
      expect(
        find.text('Walk under the stone arch in the Dusty Bowl'),
        findsOneWidget,
      );
    });
  });
}
