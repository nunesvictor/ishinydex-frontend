import 'package:freezed_annotation/freezed_annotation.dart';

part 'problem.freezed.dart';

/// Um problema que o domínio relata à interface: o quê, com os dados que a
/// mensagem precisa (ishinydex-frontend#178). O domínio não monta texto; a
/// tela traduz com `AppLocalizations.problem` (`problem_text.dart`), cujo
/// `switch` exaustivo obriga cada problema novo a ter texto nos dois
/// idiomas.
@freezed
sealed class Problem with _$Problem {
  // Gerais.
  const factory Problem.blank() = BlankProblem;
  const factory Problem.emptyList() = EmptyListProblem;
  const factory Problem.notFound() = NotFoundProblem;
  const factory Problem.invalidData() = InvalidDataProblem;
  const factory Problem.nothingToChange() = NothingToChangeProblem;

  // Pokédex pessoais.
  const factory Problem.dexNameTaken() = DexNameTakenProblem;

  /// Faltam [needed] boxes seguidas; a maior sequência livre tem [largest]
  /// e o HOME tem no máximo [max].
  const factory Problem.noFreeBoxes({
    required int needed,
    required int largest,
    required int max,
  }) = NoFreeBoxesProblem;
  const factory Problem.slotWithoutForm() = SlotWithoutFormProblem;
  const factory Problem.slotFormMismatch() = SlotFormMismatchProblem;
  const factory Problem.alreadyDeposited() = AlreadyDepositedProblem;
  const factory Problem.slotReserved() = SlotReservedProblem;
  const factory Problem.huntsNeedShinyDex() = HuntsNeedShinyDexProblem;

  // Espécimes.
  const factory Problem.specimenNotFound() = SpecimenNotFoundProblem;

  /// Os espécimes [ids] não existem.
  const factory Problem.specimensNotFound(List<int> ids) =
      SpecimensNotFoundProblem;
  const factory Problem.invalidForm() = InvalidFormProblem;
  const factory Problem.formUnchangeable() = FormUnchangeableProblem;
  const factory Problem.notAnEvolution() = NotAnEvolutionProblem;
  const factory Problem.invalidAbility() = InvalidAbilityProblem;

  /// O gênero pedido no lote não é possível para [count] espécimes.
  const factory Problem.impossibleGender(int count) = ImpossibleGenderProblem;
  const factory Problem.championsHomeOnly() = ChampionsHomeOnlyProblem;
  const factory Problem.championsNoRelease() = ChampionsNoReleaseProblem;

  // Registro da caçada no espécime.
  const factory Problem.unknownHuntMethod() = UnknownHuntMethodProblem;
  const factory Problem.huntCountNotPositive() = HuntCountNotPositiveProblem;
  const factory Problem.huntUnitNotOfMethod() = HuntUnitNotOfMethodProblem;
  const factory Problem.huntStartAfterCapture() = HuntStartAfterCaptureProblem;
  const factory Problem.invalidLink() = InvalidLinkProblem;

  // Caçadas em andamento.
  const factory Problem.negativeCount() = NegativeCountProblem;
  const factory Problem.invalidChain() = InvalidChainProblem;
  const factory Problem.timerRunning() = TimerRunningProblem;

  // Treinadores e saves.
  const factory Problem.trainerNotFound() = TrainerNotFoundProblem;
  const factory Problem.trainerTaken() = TrainerTakenProblem;

  /// O jogo [version] não existe no catálogo.
  const factory Problem.unknownVersion(String version) = UnknownVersionProblem;
  const factory Problem.saveNeedsHomeGame() = SaveNeedsHomeGameProblem;
  const factory Problem.trainerAlreadySave() = TrainerAlreadySaveProblem;
  const factory Problem.saveNotFound() = SaveNotFoundProblem;
  const factory Problem.noShinyCharm() = NoShinyCharmProblem;
  const factory Problem.saveHasSpecimens() = SaveHasSpecimensProblem;

  /// [game] (o nome do jogo) não envia mais para o HOME.
  const factory Problem.gameCutOff(String game) = GameCutOffProblem;

  // Por que um Pokémon não vai para um save (e o aviso de quem vai).
  const factory Problem.oneWaySave() = OneWaySaveProblem;
  const factory Problem.visitingChampions() = VisitingChampionsProblem;
  const factory Problem.letsGoOnly() = LetsGoOnlyProblem;
  const factory Problem.formStaysInHome() = FormStaysInHomeProblem;
  const factory Problem.spindaNotInBdsp() = SpindaNotInBdspProblem;
  const factory Problem.nincadaBdspOnly() = NincadaBdspOnlyProblem;
  const factory Problem.nincadaBackToBdsp() = NincadaBackToBdspProblem;
  const factory Problem.goNeedsForm() = GoNeedsFormProblem;

  // Shiny locks.
  const factory Problem.shinyLockNameTaken() = ShinyLockNameTakenProblem;

  // Arquivos de dados e catálogo.
  const factory Problem.notADataFile() = NotADataFileProblem;
  const factory Problem.dataFromNewerApp() = DataFromNewerAppProblem;

  /// O arquivo [name] não pôde ser lido.
  const factory Problem.unreadableFile(String name) = UnreadableFileProblem;

  /// O catálogo está no formato [schema], e o app só lê até o [supported].
  const factory Problem.catalogTooNew({
    required int schema,
    required int supported,
  }) = CatalogTooNewProblem;

  // Sincronização.
  const factory Problem.dropboxAccessExpired() = DropboxAccessExpiredProblem;
  const factory Problem.dropboxOffline() = DropboxOfflineProblem;

  /// O Dropbox recusou o login; [reason] é o motivo que ele mandou (em
  /// inglês), quando mandou.
  const factory Problem.dropboxLoginRefused([String? reason]) =
      DropboxLoginRefusedProblem;
  const factory Problem.dropboxLoginElsewhere() = DropboxLoginElsewhereProblem;

  /// O sync falhou por [detail] (o erro técnico).
  const factory Problem.syncFailed(String detail) = SyncFailedProblem;

  // Datas digitadas.
  /// Data que não segue o formato [hint] (`dd/mm/aaaa`).
  const factory Problem.invalidDate(String hint) = InvalidDateProblem;
  const factory Problem.futureDate() = FutureDateProblem;
}
