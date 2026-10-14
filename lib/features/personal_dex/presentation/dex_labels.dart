import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/l10n/app_localizations.dart';

/// Os textos dos modelos das pokédex pessoais no idioma da tela
/// (ishinydex-frontend#178): o domínio guarda só os valores.
extension DexLabels on AppLocalizations {
  /// `"generation-iv"` → `"Geração IV"`; `null` (formas sem pokémon) →
  /// `"Outras formas"`.
  String generation(String? generation) => switch (generation) {
    null => generationOther,
    final gen => generationNumber(
      gen.replaceFirst('generation-', '').toUpperCase(),
    ),
  };

  String huntReason(HuntReason reason) => switch (reason) {
    HuntReason.noShiny => huntReasonNoShiny,
    HuntReason.fromGo => huntReasonFromGo,
    HuntReason.pokeball => huntReasonPokeball,
  };

  String huntSituation(HuntSituation situation) => switch (situation) {
    HuntSituation.all => huntSituationAll,
    HuntSituation.missing => huntSituationMissing,
    HuntSituation.registered => huntSituationRegistered,
  };

  /// O que entra em cada situação, embaixo do nome.
  String huntSituationHint(HuntSituation situation) => switch (situation) {
    HuntSituation.all => huntSituationAllHint,
    HuntSituation.missing => huntSituationMissingHint,
    HuntSituation.registered => huntSituationRegisteredHint,
  };

  String speciesCategory(SpeciesCategory category) => switch (category) {
    SpeciesCategory.legendary => categoryLegendary,
    SpeciesCategory.mythical => categoryMythical,
    SpeciesCategory.ultraBeast => categoryUltraBeast,
    SpeciesCategory.baby => categoryBaby,
    SpeciesCategory.regular => categoryRegular,
  };

  String shinyLockType(ShinyLockType type) => switch (type) {
    ShinyLockType.distroOnly => shinyLockDistroOnly,
    ShinyLockType.unobtainable => shinyLockUnobtainable,
  };
}
