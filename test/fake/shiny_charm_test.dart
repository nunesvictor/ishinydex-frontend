import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';

/// Os textos em pt-BR, sem montar uma tela.
final AppLocalizations _pt = lookupAppLocalizations(const Locale('pt'));

void main() {
  test(
    'Shiny Charm no save: grava, volta pelos registros e recusa FRLG',
    () async {
      final backend = FakeBackend.seeded();
      final save = await backend.updateSave(1, hasShinyCharm: true);
      expect(save.hasShinyCharm, isTrue);
      // O apelido fica como estava.
      expect(save.label, 'Switch');
      expect(
        backend.records['saves']!.firstWhere((s) => s['id'] == 1)['shinyCharm'],
        isTrue,
      );
      // Sem o Charm, o registro fica como antes (sem a chave).
      expect(
        backend.records['saves']!.firstWhere((s) => s['id'] == 2),
        isNot(contains('shinyCharm')),
      );

      final copy = FakeBackend.seeded()..replaceRecords(backend.records);
      final saves = await copy.fetchSaves();
      expect(saves.firstWhere((s) => s.id == 1).hasShinyCharm, isTrue);
      expect(saves.firstWhere((s) => s.id == 2).hasShinyCharm, isFalse);

      // Desligar e mudar só o apelido.
      expect(
        (await backend.updateSave(1, hasShinyCharm: false)).hasShinyCharm,
        isFalse,
      );

      // FRLG não tem o Charm: recusa ligar, aceita desligar.
      final ot = backend.addTrainer(
        name: 'Red',
        trainerId: '1',
        version: 'firered',
      );
      final frlg = await backend.createSave(trainerId: ot);
      await expectLater(
        backend.updateSave(frlg.id, hasShinyCharm: true),
        throwsA(
          isA<ValidationFailure>().having((f) => f.fieldErrors.keys, 'campos', [
            'shinyCharm',
          ]),
        ),
      );
      expect(
        (await backend.updateSave(frlg.id, hasShinyCharm: false)).hasShinyCharm,
        isFalse,
      );
    },
  );

  test('onde o Charm existe e a explicação', () {
    Save of(String version) => Save(
      id: 1,
      trainer: Trainer(id: 1, name: 'A', trainerId: '1', version: version),
    );
    expect(of('sword').canHaveShinyCharm, isTrue);
    expect(of('ultra-moon').canHaveShinyCharm, isTrue);
    expect(of('firered').canHaveShinyCharm, isFalse);
    expect(of('red').canHaveShinyCharm, isFalse);
    expect(
      _pt.shinyCharmHint(of('sword')),
      'Vale nas caçadas deste save em que o Charm conta '
      '(não vale nos Regis, nos fósseis e nas reides).',
    );
    expect(
      _pt.shinyCharmHint(of('legends-arceus')),
      'Vale nas caçadas deste save em que o Charm conta.',
    );
  });
}
