import 'package:ishinydex/core/l10n/problem.dart';
import 'package:ishinydex/l10n/app_localizations.dart';

/// O texto de cada [Problem] no idioma da tela. O `switch` não tem `_`: um
/// problema novo sem texto não compila.
extension ProblemText on AppLocalizations {
  String problem(Problem problem) => switch (problem) {
    BlankProblem() => problemBlank,
    EmptyListProblem() => problemEmptyList,
    NotFoundProblem() => problemNotFound,
    InvalidDataProblem() => problemInvalidData,
    NothingToChangeProblem() => problemNothingToChange,
    DexNameTakenProblem() => problemDexNameTaken,
    NoFreeBoxesProblem(:final needed, :final largest, :final max) =>
      problemNoFreeBoxes(needed, largest, max),
    SlotWithoutFormProblem() => problemSlotWithoutForm,
    SlotFormMismatchProblem() => problemSlotFormMismatch,
    AlreadyDepositedProblem() => problemAlreadyDeposited,
    SlotReservedProblem() => problemSlotReserved,
    HuntsNeedShinyDexProblem() => problemHuntsNeedShinyDex,
    SpecimenNotFoundProblem() => problemSpecimenNotFound,
    SpecimensNotFoundProblem(:final ids) => problemSpecimensNotFound(
      ids.join(', '),
    ),
    InvalidFormProblem() => problemInvalidForm,
    FormUnchangeableProblem() => problemFormUnchangeable,
    NotAnEvolutionProblem() => problemNotAnEvolution,
    InvalidAbilityProblem() => problemInvalidAbility,
    ImpossibleGenderProblem(:final count) => problemImpossibleGender(count),
    ChampionsHomeOnlyProblem() => problemChampionsHomeOnly,
    ChampionsNoReleaseProblem() => problemChampionsNoRelease,
    UnknownHuntMethodProblem() => problemUnknownHuntMethod,
    HuntCountNotPositiveProblem() => problemHuntCountNotPositive,
    HuntUnitNotOfMethodProblem() => problemHuntUnitNotOfMethod,
    HuntStartAfterCaptureProblem() => problemHuntStartAfterCapture,
    AlphaNotAllowedProblem() => problemAlphaNotAllowed,
    InvalidLinkProblem() => problemInvalidLink,
    NegativeCountProblem() => problemNegativeCount,
    InvalidChainProblem() => problemInvalidChain,
    TimerRunningProblem() => problemTimerRunning,
    TeamFullProblem() => problemTeamFull,
    NoTeamsInGameProblem() => problemNoTeamsInGame,
    InvalidLevelProblem() => problemInvalidLevel,
    InvalidEvsProblem() => problemInvalidEvs,
    InvalidIvsProblem() => problemInvalidIvs,
    InvalidMovesProblem() => problemInvalidMoves,
    TrainerNotFoundProblem() => problemTrainerNotFound,
    TrainerTakenProblem() => problemTrainerTaken,
    UnknownVersionProblem(:final version) => problemUnknownVersion(version),
    SaveNeedsHomeGameProblem() => problemSaveNeedsHomeGame,
    TrainerAlreadySaveProblem() => problemTrainerAlreadySave,
    SaveNotFoundProblem() => problemSaveNotFound,
    NoShinyCharmProblem() => problemNoShinyCharm,
    SaveHasSpecimensProblem() => problemSaveHasSpecimens,
    GameCutOffProblem(:final game) => problemGameCutOff(game),
    OneWaySaveProblem() => problemOneWaySave,
    VisitingChampionsProblem() => problemVisitingChampions,
    LetsGoOnlyProblem() => problemLetsGoOnly,
    FormStaysInHomeProblem() => problemFormStaysInHome,
    SpindaNotInBdspProblem() => problemSpindaNotInBdsp,
    NincadaBdspOnlyProblem() => problemNincadaBdspOnly,
    NincadaBackToBdspProblem() => problemNincadaBackToBdsp,
    GoNeedsFormProblem() => problemGoNeedsForm,
    ShinyLockNameTakenProblem() => problemShinyLockNameTaken,
    NotADataFileProblem() => problemNotADataFile,
    DataFromNewerAppProblem() => problemDataFromNewerApp,
    UnreadableFileProblem(:final name) => problemUnreadableFile(name),
    CatalogTooNewProblem(:final schema, :final supported) =>
      problemCatalogTooNew(schema, supported),
    DropboxAccessExpiredProblem() => problemDropboxAccessExpired,
    DropboxOfflineProblem() => problemDropboxOffline,
    // O motivo vem do Dropbox, sem tradução.
    DropboxLoginRefusedProblem(:final reason) =>
      reason ?? problemDropboxLoginRefused,
    DropboxLoginElsewhereProblem() => problemDropboxLoginElsewhere,
    SyncFailedProblem(:final detail) => problemSyncFailed(detail),
    InvalidDateProblem(:final hint) => problemInvalidDate(hint),
    FutureDateProblem() => problemFutureDate,
  };

  /// Vários problemas, um por linha.
  String problems(Iterable<Problem> problems) =>
      problems.map(problem).join('\n');
}
