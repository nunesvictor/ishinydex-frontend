import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_labels.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final pt = lookupAppLocalizations(const Locale('pt'));
  final day = DateTime(2026, 9, 14);

  test('em inglês: contagem, duração e "há N dias"', () {
    expect(en.huntCount(4213, 'resets'), '4,213 resets');
    expect(pt.huntCount(4213, 'eggs'), '4.213 ovos');
    expect(en.huntDuration(day, DateTime(2026, 9, 15)), '1 day');
    expect(en.huntDuration(DateTime(2024, 6, 12), day), '2 years');
    expect(en.awayFor(day, today: day), 'today');
    expect(en.awayFor(DateTime(2026, 9, 13), today: day), '1 day ago');
  });

  test('choiceOf: a opção, o valor formatado ou nada', () {
    const choices = [Choice(value: 'eng', label: 'English')];
    expect(pt.choiceOf(choices, 'eng'), 'English');
    expect(pt.choiceOf(choices, 'dream-ball'), 'Dream Ball');
    expect(pt.choiceOf(null, ''), isNull);
  });

  test('todas as unidades, ordens e status têm texto', () {
    for (final unit in [
      'encounters',
      'hours',
      'resets',
      'eggs',
      'chains',
      'runs',
      'raids',
      'hordes',
      'combo',
    ]) {
      expect(en.huntUnit(unit), isNotEmpty, reason: unit);
    }
    expect(en.huntUnit('chains'), 'chain');
    expect(en.huntUnit('laps'), 'laps');
    expect(pt.huntUnit('raids'), 'reides');
    expect({
      for (final o in SpecimenOrdering.values) en.ordering(o),
    }, hasLength(SpecimenOrdering.values.length));
    expect(en.stat('special-attack'), 'Sp. Atk');
  });

  test('o Shiny Charm em cada jogo', () {
    Save of(String version) => Save(
      id: 1,
      trainer: Trainer(id: 1, name: 'A', trainerId: '1', version: version),
    );
    for (final version in ['shining-pearl', 'violet', 'legends-za']) {
      expect(en.shinyCharmHint(of(version)), contains('('), reason: version);
    }
    expect(
      en.shinyCharmHint(of('sword')),
      "Counts in this save's hunts where the Charm applies "
      '(not for the Regis, fossils and raids).',
    );
  });

  test('pokédex: número e DLC', () {
    const entry = PokedexEntry(label: 'Galar', number: 383);
    expect(en.pokedexEntry(entry, 'Galar'), 'Galar #383');
    expect(pt.pokedexEntry(entry, 'Galar'), 'Galar nº 383');
    expect(
      en.pokedexEntry(const PokedexEntry(label: 'x', dlc: true), 'Hyperspace'),
      'Hyperspace (DLC)',
    );
  });

  test('rótulos das pokédex pessoais em inglês', () {
    expect(en.generation('generation-iv'), 'Generation IV');
    expect(en.generation(null), 'Other forms');
    expect(
      [for (final r in HuntReason.values) en.huntReason(r)],
      ['No shiny', 'No alpha', 'Shiny from GO', 'Poké Ball'],
    );
    expect([
      for (final s in HuntSituation.values) en.huntSituationHint(s),
    ], hasLength(3));
    expect(en.huntSituation(HuntSituation.missing), 'Missing');
    expect(en.speciesCategory(SpeciesCategory.baby), 'Baby');
    expect(en.shinyLockType(ShinyLockType.distroOnly), 'Distribution only');
  });
}
