import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';

/// Um exemplo de cada [Problem] (o `switch` do `problem_text.dart` garante
/// que todos têm texto; aqui, que nenhum sai vazio ou com `{` sobrando).
const _all = <Problem>[
  Problem.blank(),
  Problem.emptyList(),
  Problem.notFound(),
  Problem.invalidData(),
  Problem.nothingToChange(),
  Problem.dexNameTaken(),
  Problem.noFreeBoxes(needed: 12, largest: 3, max: 200),
  Problem.slotWithoutForm(),
  Problem.slotFormMismatch(),
  Problem.alreadyDeposited(),
  Problem.slotReserved(),
  Problem.huntsNeedShinyDex(),
  Problem.specimenNotFound(),
  Problem.specimensNotFound([4, 7]),
  Problem.invalidForm(),
  Problem.formUnchangeable(),
  Problem.notAnEvolution(),
  Problem.invalidAbility(),
  Problem.impossibleGender(1),
  Problem.impossibleGender(3),
  Problem.championsHomeOnly(),
  Problem.championsNoRelease(),
  Problem.unknownHuntMethod(),
  Problem.huntCountNotPositive(),
  Problem.huntUnitNotOfMethod(),
  Problem.huntStartAfterCapture(),
  Problem.invalidLink(),
  Problem.negativeCount(),
  Problem.invalidChain(),
  Problem.timerRunning(),
  Problem.trainerNotFound(),
  Problem.trainerTaken(),
  Problem.unknownVersion('x'),
  Problem.saveNeedsHomeGame(),
  Problem.trainerAlreadySave(),
  Problem.saveNotFound(),
  Problem.noShinyCharm(),
  Problem.saveHasSpecimens(),
  Problem.gameCutOff('Sun'),
  Problem.oneWaySave(),
  Problem.visitingChampions(),
  Problem.letsGoOnly(),
  Problem.formStaysInHome(),
  Problem.spindaNotInBdsp(),
  Problem.nincadaBdspOnly(),
  Problem.nincadaBackToBdsp(),
  Problem.goNeedsForm(),
  Problem.shinyLockNameTaken(),
  Problem.notADataFile(),
  Problem.dataFromNewerApp(),
  Problem.unreadableFile('a.json'),
  Problem.catalogTooNew(schema: 2, supported: 1),
  Problem.dropboxAccessExpired(),
  Problem.dropboxOffline(),
  Problem.dropboxLoginRefused(),
  Problem.dropboxLoginElsewhere(),
  Problem.syncFailed('timeout'),
  Problem.invalidDate('dd/mm/aaaa'),
  Problem.futureDate(),
];

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final pt = lookupAppLocalizations(const Locale('pt'));

  test('todo problema tem texto nos dois idiomas', () {
    for (final problem in _all) {
      for (final l10n in [en, pt]) {
        final text = l10n.problem(problem);
        expect(text, isNotEmpty, reason: '$problem');
        expect(text, isNot(contains('{')), reason: '$problem');
      }
      expect(en.problem(problem), isNot(pt.problem(problem)));
    }
  });

  test('parâmetros e plural', () {
    expect(
      pt.problem(const Problem.specimensNotFound([4, 7])),
      'Espécimes não encontrados: 4, 7',
    );
    expect(
      en.problem(const Problem.impossibleGender(1)),
      "This gender isn't possible for 1 specimen.",
    );
    expect(
      pt.problem(const Problem.impossibleGender(3)),
      'Este gênero não é possível para 3 espécimes.',
    );
    expect(
      en.problem(const Problem.gameCutOff('Sun')),
      'Sun no longer sends to HOME.',
    );
  });

  test('o motivo do Dropbox sai como veio', () {
    expect(
      pt.problem(const Problem.dropboxLoginRefused('access_denied')),
      'access_denied',
    );
    expect(
      pt.problem(const Problem.dropboxLoginRefused()),
      'O login no Dropbox foi recusado.',
    );
  });

  test('vários problemas: um por linha', () {
    expect(
      en.problems(const [Problem.blank(), Problem.emptyList()]),
      "This field can't be blank.\nThis list can't be empty.",
    );
  });

  testWidgets('context.failureText e context.fieldError', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    const failure = ValidationFailure({
      'name': [Problem.blank()],
    });
    expect(context.failureText(const NotFoundFailure()), 'Not found.');
    expect(context.fieldError(failure, 'name'), "This field can't be blank.");
    expect(context.fieldError(failure, 'other'), isNull);
    expect(context.fieldError(null, 'name'), isNull);
  });
}
