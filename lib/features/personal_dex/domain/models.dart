import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
abstract class FormRef with _$FormRef {
  const factory FormRef({
    required int id,
    required String name,
    required int pokeapiId,
    required String spriteUrl,
    required String shinySpriteUrl,
    @Default('') String formName,

    /// Nº da espécie na Pokédex nacional (o mesmo nas formas alternativas,
    /// cujo [pokeapiId] passa de 10000); `null` se a API não souber.
    int? nationalNumber,
  }) = _FormRef;

  const FormRef._();

  factory FormRef.fromJson(Map<String, dynamic> json) =>
      _$FormRefFromJson(json);

  String get displayName => prettifyName(name);

  /// "#0402": nº nacional, ou o [pokeapiId] se não houver.
  String get dexNumber =>
      '#${(nationalNumber ?? pokeapiId).toString().padLeft(4, '0')}';

  String spriteFor({required bool shiny}) => shiny ? shinySpriteUrl : spriteUrl;
}

@freezed
abstract class SpecimenSummary with _$SpecimenSummary {
  const factory SpecimenSummary({
    required int id,
    String? nickname,
    String? formName,
    String? ability,
    @Default(false) bool isShiny,
    @Default(false) bool isAlpha,
    @Default(false) bool isFromGo,
    String? gender,
    String? pokeball,
    String? pokeballSpriteUrl,

    /// Save onde o espécime está; `null` = no HOME. Fora do HOME, ele
    /// continua no slot, que fica reservado para a volta.
    Save? location,
    DateTime? locationSince,

    /// Desde quando visita o Pokémon Champions (#174).
    DateTime? championsSince,
  }) = _SpecimenSummary;

  const SpecimenSummary._();

  factory SpecimenSummary.fromJson(Map<String, dynamic> json) =>
      _$SpecimenSummaryFromJson(json);

  String get displayName {
    final nick = nickname;
    if (nick != null && nick.isNotEmpty) return nick;
    return prettifyName(formName ?? 'Specimen #$id');
  }

  bool get isVisitingChampions => championsSince != null;
}

@freezed
abstract class BoxRef with _$BoxRef {
  const factory BoxRef({
    required int id,
    required String name,
    required int position,
  }) = _BoxRef;

  factory BoxRef.fromJson(Map<String, dynamic> json) => _$BoxRefFromJson(json);
}

@freezed
abstract class Slot with _$Slot {
  const factory Slot({
    required int id,
    required BoxRef box,
    required int row,
    required int col,
    int? personalDex,
    FormRef? form,
    SpecimenSummary? specimen,
    @Default(false) bool isShinyDisplay,
  }) = _Slot;

  const Slot._();

  factory Slot.fromJson(Map<String, dynamic> json) => _$SlotFromJson(json);

  /// Sem forma atribuída pelo esquema.
  bool get isFree => form == null;

  bool get isRegistered => form != null && specimen != null;

  bool get isMissing => form != null && specimen == null;

  String? get spriteUrl => form?.spriteFor(shiny: isShinyDisplay);
}

/// Os atalhos do "Novo PersonalDex" (#34): as combinações das chaves da
/// planilha "Home Living Dex Organizer", de Austin John (Austin John
/// Plays). Todos levam as formas regionais.
enum DexPreset {
  /// O conjunto padrão: regionais, pré-evoluções e formas alternativas.
  livingFormLite,

  /// Sem as formas alternativas.
  living,

  /// Só as formas que não evoluem mais, com as formas alternativas.
  finalFormForm,

  /// Só as formas que não evoluem mais, sem as formas alternativas.
  finalForm,
}

/// De onde o dex nasceu (#34): as chaves aplicadas ao conjunto padrão do
/// catálogo. Fica guardada no dex para comparar com o padrão depois (#308).
@freezed
abstract class DexRecipe with _$DexRecipe {
  const factory DexRecipe({
    /// As formas regionais (Raichu de Alola, Meowth de Galar...).
    @Default(true) bool regional,

    /// As formas que ainda evoluem. Sem elas, só as que não evoluem mais
    /// pelo próprio caminho (o Final Form).
    @Default(true) bool preEvolutions,

    /// As formas alternativas (letras do Unown, padrões do Vivillon...).
    /// Sem elas, uma forma por espécie, além das regionais.
    @Default(true) bool alternateForms,

    /// O dex por jogo (#34): o grupo de versões (`scarlet-violet`). `null` é
    /// o Nacional. No dex por jogo não há a chave das regionais: cada
    /// espécie entra com as formas que existem no jogo.
    @JsonKey(includeIfNull: false) String? versionGroup,

    /// As pokédex do jogo, na ordem em que entram (a principal, depois as
    /// das DLCs...).
    @Default(<String>[]) List<String> pokedexes,
  }) = _DexRecipe;

  const DexRecipe._();

  factory DexRecipe.fromJson(Map<String, dynamic> json) =>
      _$DexRecipeFromJson(json);

  factory DexRecipe.of(DexPreset preset) => switch (preset) {
    DexPreset.livingFormLite => const DexRecipe(),
    DexPreset.living => const DexRecipe(alternateForms: false),
    DexPreset.finalFormForm => const DexRecipe(preEvolutions: false),
    DexPreset.finalForm => const DexRecipe(
      preEvolutions: false,
      alternateForms: false,
    ),
  };

  /// O atalho com estas chaves; `null` numa combinação fora deles (o
  /// "Personalizado"). A base (Nacional ou o jogo) não conta.
  DexPreset? get preset => [
    for (final p in DexPreset.values)
      if (DexRecipe.of(p) ==
          copyWith(versionGroup: null, pokedexes: const <String>[]))
        p,
  ].firstOrNull;

  /// As mesmas chaves de [preset] sobre esta base.
  DexRecipe withPreset(DexPreset preset) =>
      DexRecipe.of(preset)
          .copyWith(versionGroup: versionGroup, pokedexes: pokedexes);

  bool get byGame => versionGroup != null;
}

/// Uma pokédex de um jogo, para escolher no dex por jogo (#34).
@freezed
abstract class GameDexChoice with _$GameDexChoice {
  const factory GameDexChoice({
    required String name,
    required String label,

    /// Quantas espécies ela tem.
    required int species,
    @Default(<String, String>{}) Map<String, String> labels,

    /// A DLC da pokédex (`the-teal-mask`); `null` no jogo base.
    String? dlc,

    /// Lista extra, sem número (Outros encontros, Aventura Dinamax...).
    @Default(false) bool extra,

    /// Uma pokédex anterior do jogo já tem todas as espécies desta (as
    /// ilhas de Alola, dentro da de Alola): o rótulo dela.
    String? coveredBy,
    @Default(<String, String>{}) Map<String, String> coveredByLabels,

    /// Marcada quando se escolhe o jogo: as numeradas que trazem espécies
    /// novas.
    @Default(false) bool selectedByDefault,
  }) = _GameDexChoice;
}

/// Como as formas novas entram no dex desatualizado (#308).
enum DexUpdateMode {
  /// Cada forma no lugar certo: o esquema é refeito, e slots e boxes mudam.
  inOrder,

  /// Em boxes depois da última do dex, fora da ordem: nada do que existe
  /// muda de lugar.
  atEnd,
}

/// Uma box que recebe formas no "No fim" (#308).
@freezed
abstract class DexUpdateBox with _$DexUpdateBox {
  const factory DexUpdateBox({
    required String name,
    required int forms,

    /// Criada no fim do HOME (não havia box livre ali).
    @Default(false) bool isNew,
  }) = _DexUpdateBox;
}

/// O que mudou no padrão desde que o dex foi criado, e o que cada jeito de
/// atualizar faz nas boxes do HOME (#308).
@freezed
abstract class DexUpdatePreview with _$DexUpdatePreview {
  const factory DexUpdatePreview({
    /// As formas que a receita do dex dá hoje e o dex não tem.
    required List<FormRef> added,

    /// As formas do dex que saíram do padrão.
    required List<FormRef> removed,

    /// A mudança em si (as formas que entram e saem): o aviso que o usuário
    /// adiou ou ignorou só vale para ela.
    required String signature,

    /// De onde o dex nasceu (o padrão, nos dex de antes do #34).
    required DexRecipe recipe,

    /// "Na ordem": as boxes que o dex usa antes e depois, as boxes cujo
    /// conteúdo muda e quantos espécimes mudam de lugar.
    required int boxesBefore,
    required int boxesAfter,
    required List<String> changedBoxes,
    required int movedSpecimens,
    required bool inOrderFits,

    /// "No fim": as boxes que recebem as formas novas.
    required List<DexUpdateBox> atEndBoxes,
    required bool atEndFits,

    /// Quantas das formas que saíram têm espécime: voltam ao inventário se
    /// saírem do dex.
    @Default(0) int removedWithSpecimen,
  }) = _DexUpdatePreview;
}

@freezed
abstract class PersonalDex with _$PersonalDex {
  const factory PersonalDex({
    required int id,
    required String name,
    required int total,
    required int registered,

    /// Dos [registered], quantos estão num save (fora do HOME).
    @Default(0) int away,
    @Default(false) bool isShinyDex,
    @Default(false) bool forceNewBox,

    /// De onde o dex nasceu (#34); `null` nos dex criados antes, que vieram
    /// do conjunto padrão (o Living Form Lite).
    DexRecipe? recipe,

    /// A mudança do padrão ([DexUpdatePreview.signature]) que o usuário
    /// deixou para depois (#308): o aviso sai do topo e fica no menu.
    String? updateLater,

    /// A mudança que o usuário decidiu não aplicar: o aviso some até o
    /// padrão mudar de novo.
    String? updateIgnored,
  }) = _PersonalDex;

  const PersonalDex._();

  factory PersonalDex.fromJson(Map<String, dynamic> json) =>
      _$PersonalDexFromJson(json);

  int get missing => total - registered;
}

@freezed
abstract class BoxSummary with _$BoxSummary {
  const factory BoxSummary({
    required int id,
    required String name,
    required int position,
    required int total,
    required int registered,
    @Default(0) int away,
  }) = _BoxSummary;

  const BoxSummary._();

  factory BoxSummary.fromJson(Map<String, dynamic> json) =>
      _$BoxSummaryFromJson(json);

  bool get isComplete => total > 0 && registered >= total;
}

/// Progresso do dex numa geração (`GET /personal-dexes/{id}/generations/`).
@freezed
abstract class GenerationProgress with _$GenerationProgress {
  const factory GenerationProgress({
    /// Slug da API (`"generation-iv"`); `null` = formas sem pokémon.
    required String? generation,
    required int total,
    required int registered,
    required BoxRef firstBox,
    @Default(0) int away,
  }) = _GenerationProgress;

  const GenerationProgress._();

  int get missing => total - registered;
}

/// Por que um slot está na lista de caçadas; [param] é o valor da API.
enum HuntReason {
  noShiny('no_shiny'),

  /// A forma pode ser alfa e o slot não tem um alfa (#280).
  noAlpha('no_alpha'),
  fromGo('from_go'),
  pokeball('pokeball');

  HuntReason(this.param);

  final String param;

  /// Valor da API → motivo; desconhecido → `null` (ignorado).
  static HuntReason? fromParam(String value) =>
      values.where((r) => r.param == value).firstOrNull;
}

/// Situação do slot nas caçadas: vazio (falta registrar) ou com um espécime
/// que ainda não serve (não shiny, do GO, pokébola errada).
enum HuntSituation {
  all,
  missing(param: false),
  registered(param: true);

  HuntSituation({this.param});

  /// Valor de `registered` na API; `null` não filtra.
  final bool? param;
}

/// "Fim do Pokémon Bank" (#316): o que dá para caçar nos jogos que deixam de
/// chegar ao HOME (os do Pokémon Bank, com `homeUntil` no catálogo) e ainda
/// não fecharam.
enum HomeCutoffFilter {
  all,

  /// Todos os jogos em que a forma pode ser caçada fecham: depois do corte,
  /// não há outro jeito.
  only(param: 'only'),

  /// Algum jogo em que a forma pode ser caçada fecha.
  also(param: 'also');

  HomeCutoffFilter({this.param});

  /// Valor de `home_cutoff` na API; `null` não filtra.
  final String? param;
}

/// Categoria da espécie, nos filtros das caçadas e do inventário.
enum SpeciesCategory {
  legendary('legendary'),
  mythical('mythical'),
  ultraBeast('ultra-beast'),
  baby('baby'),
  regular('regular');

  SpeciesCategory(this.param);

  final String param;
}

/// Tipo do shiny lock (o `lock_type` da API; nas caçadas, `shiny_lock`).
enum ShinyLockType {
  /// Ainda dá para conseguir, por distribuição (evento).
  distroOnly('distro-only'),

  /// Impossível de obter shiny; só aparece com "incluir impossíveis".
  unobtainable('unobtainable');

  ShinyLockType(this.param);

  final String param;

  static ShinyLockType? fromParam(String? value) =>
      values.where((l) => l.param == value).firstOrNull;
}

/// Item da lista de caçadas (`GET /personal-dexes/{id}/hunts/`): um slot e
/// todos os motivos em que ele se encaixa.
///
/// Sem `fromJson` gerado: na API o slot vem "achatado" (os campos do slot e,
/// ao lado, `reasons` e `shiny_lock`), então [Hunt.parse] monta o objeto à
/// mão. Uma `factory` com corpo não vira um "caso" novo no freezed.
/// Resultado de "Depositar automaticamente"
/// (`POST /personal-dexes/{id}/link-specimens/`): os [slots] que recebem um
/// espécime (já com ele) e quantos slots vazios ficaram sem ([missing]).
@freezed
abstract class LinkResult with _$LinkResult {
  const factory LinkResult({
    required int linked,
    required int missing,
    @Default(<Slot>[]) List<Slot> slots,
  }) = _LinkResult;

  factory LinkResult.fromJson(Map<String, dynamic> json) =>
      _$LinkResultFromJson(json);
}

@freezed
abstract class Hunt with _$Hunt {
  const factory Hunt({
    required Slot slot,
    required List<HuntReason> reasons,
    ShinyLockType? shinyLock,

    /// Versões (das que recebem do HOME) em que a forma pode ser caçada:
    /// está numa pokédex do jogo e não é exclusiva da outra versão. Vazio
    /// sem o catálogo.
    @Default(<String>[]) List<String> versions,
  }) = _Hunt;

  const Hunt._();

  factory Hunt.parse(Map<String, dynamic> json) => Hunt(
    slot: Slot.fromJson(json),
    reasons: [
      for (final value in json['reasons'] as List<dynamic>)
        ?HuntReason.fromParam(value as String),
    ],
    shinyLock: ShinyLockType.fromParam(json['shiny_lock'] as String?),
  );
}

/// O estado de cada slot no mapa da box do Faltam (#282).
enum HuntCell {
  /// Falta e está na lista.
  listed,

  /// Falta, mas fica fora dos filtros.
  hidden,

  /// Já tem.
  done,

  /// Slot sem forma do dex.
  empty,
}

/// Uma box do Faltam (#282): quantos itens dela estão na lista e o mapa dos
/// 30 slots, linha a linha.
typedef HuntBox = ({BoxRef box, int count, List<HuntCell> cells});

/// Filtros da lista de caçadas.
///
/// Dois grupos: os **motivos** ([reasons], somados com OU), sempre à vista na
/// tela; e o **escopo** (o resto, combinado com E), na folha de filtros.
@freezed
abstract class HuntQuery with _$HuntQuery {
  const factory HuntQuery({
    @Default(<HuntReason>[HuntReason.noShiny]) List<HuntReason> reasons,

    /// Bolas aceitas pelo motivo [HuntReason.pokeball].
    @Default(<String>[]) List<String> acceptedBalls,
    @Default(<String>[]) List<String> generations,

    /// Qualquer um dos tipos (diferente do inventário, que exige todos).
    @Default(<String>[]) List<String> types,
    @Default(<SpeciesCategory>[]) List<SpeciesCategory> categories,
    @Default('') String search,
    @Default(false) bool includeLocked,
    @Default(HuntSituation.all) HuntSituation situation,
    @Default(HomeCutoffFilter.all) HomeCutoffFilter homeCutoff,

    /// Só o que dá para caçar em alguma destas versões (as dos saves do
    /// usuário); vazio = qualquer jogo.
    @Default(<String>[]) List<String> versions,
  }) = _HuntQuery;

  const HuntQuery._();

  /// Quantos grupos do escopo estão ativos (o número do badge de Filtros).
  int get scopeCount => [
    generations.isNotEmpty,
    types.isNotEmpty,
    categories.isNotEmpty,
    includeLocked,
    homeCutoff != HomeCutoffFilter.all,
  ].where((active) => active).length;

  /// Limpa o escopo, mantendo motivos, situação e busca.
  HuntQuery clearScope() => HuntQuery(
    reasons: reasons,
    acceptedBalls: acceptedBalls,
    search: search,
    situation: situation,
    versions: versions,
  );

  /// Parâmetros da API. `reasons` vai sempre: sem ele, a API usaria o
  /// padrão, e não o que está na tela.
  Map<String, dynamic> toQueryParameters() {
    String join(Iterable<String> values) => values.join(',');
    final search = this.search.trim();
    return {
      'reasons': join(reasons.map((r) => r.param)),
      if (acceptedBalls.isNotEmpty) 'accepted_balls': join(acceptedBalls),
      if (generations.isNotEmpty) 'generation': join(generations),
      if (types.isNotEmpty) 'type': join(types),
      if (categories.isNotEmpty)
        'category': join(categories.map((c) => c.param)),
      if (search.isNotEmpty) 'search': search,
      if (includeLocked) 'include_locked': true,
      'registered': ?situation.param,
      'home_cutoff': ?homeCutoff.param,
      if (versions.isNotEmpty) 'version': join(versions),
    };
  }
}

/// Limite de boxes do Pokémon HOME no plano pago: 300 (9.000 lugares) desde
/// o HOME 4.1.0; antes eram 200. O backend não cria boxes além dele.
const homeMaxBoxes = 300;

/// Simulação de um dex padrão (`GET /personal-dexes/preview/`).
@freezed
abstract class DexPreview with _$DexPreview {
  const factory DexPreview({
    required int forms,
    required int boxesNeeded,
    required int largestFreeRun,
    required bool enoughSpace,

    /// Boxes novas que a criação faria no fim (0: só boxes existentes).
    @Default(0) int boxesToCreate,

    /// Onde o esquema começaria; `null` sem espaço ou quando o dex fica todo
    /// em boxes novas.
    BoxRef? firstBox,
  }) = _DexPreview;
}
