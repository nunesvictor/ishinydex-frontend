import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ishinydex/core/utils/format.dart';

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
  }) = _FormRef;

  const FormRef._();

  factory FormRef.fromJson(Map<String, dynamic> json) =>
      _$FormRefFromJson(json);

  String get displayName => prettifyName(name);

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
    String? pokeball,
    String? pokeballSpriteUrl,
  }) = _SpecimenSummary;

  const SpecimenSummary._();

  factory SpecimenSummary.fromJson(Map<String, dynamic> json) =>
      _$SpecimenSummaryFromJson(json);

  String get displayName {
    final nick = nickname;
    if (nick != null && nick.isNotEmpty) return nick;
    return prettifyName(formName ?? 'Specimen #$id');
  }
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

@freezed
abstract class PersonalDex with _$PersonalDex {
  const factory PersonalDex({
    required int id,
    required String name,
    required int total,
    required int registered,
    @Default(false) bool isShinyDex,
    @Default(false) bool forceNewBox,
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
  }) = _GenerationProgress;

  const GenerationProgress._();

  factory GenerationProgress.fromJson(Map<String, dynamic> json) =>
      _$GenerationProgressFromJson(json);

  /// `"generation-iv"` → `"Geração IV"`.
  String get label {
    final gen = generation;
    if (gen == null) return 'Outras formas';
    return 'Geração ${gen.replaceFirst('generation-', '').toUpperCase()}';
  }

  int get missing => total - registered;
}

/// Por que um slot está na lista de caçadas; [param] é o valor da API.
enum HuntReason {
  noShiny('no_shiny', 'Sem shiny'),
  fromGo('from_go', 'Shiny do GO'),
  pokeball('pokeball', 'Pokébola');

  HuntReason(this.param, this.label);

  final String param;
  final String label;

  /// Valor da API → motivo; desconhecido → `null` (ignorado).
  static HuntReason? fromParam(String value) =>
      values.where((r) => r.param == value).firstOrNull;
}

/// Categoria da espécie nos filtros de caçadas.
enum HuntCategory {
  legendary('legendary', 'Lendário'),
  mythical('mythical', 'Mítico'),
  ultraBeast('ultra-beast', 'Ultra Beast'),
  baby('baby', 'Bebê'),
  regular('regular', 'Comum');

  HuntCategory(this.param, this.label);

  final String param;
  final String label;
}

/// Shiny lock da forma, como a API informa em `shiny_lock`.
enum ShinyLock {
  /// Ainda dá para conseguir, por distribuição (evento).
  distroOnly('distro-only', 'Só por distribuição'),

  /// Impossível de obter shiny; só aparece com "incluir impossíveis".
  unobtainable('unobtainable', 'Shiny impossível');

  ShinyLock(this.param, this.label);

  final String param;
  final String label;

  static ShinyLock? fromParam(String? value) =>
      values.where((l) => l.param == value).firstOrNull;
}

/// Item da lista de caçadas (`GET /personal-dexes/{id}/hunts/`): um slot e
/// todos os motivos em que ele se encaixa.
///
/// Sem `fromJson` gerado: na API o slot vem "achatado" (os campos do slot e,
/// ao lado, `reasons` e `shiny_lock`), então [Hunt.parse] monta o objeto à
/// mão. Uma `factory` com corpo não vira um "caso" novo no freezed.
@freezed
abstract class Hunt with _$Hunt {
  const factory Hunt({
    required Slot slot,
    required List<HuntReason> reasons,
    ShinyLock? shinyLock,
  }) = _Hunt;

  const Hunt._();

  factory Hunt.parse(Map<String, dynamic> json) => Hunt(
    slot: Slot.fromJson(json),
    reasons: [
      for (final value in json['reasons'] as List<dynamic>)
        ?HuntReason.fromParam(value as String),
    ],
    shinyLock: ShinyLock.fromParam(json['shiny_lock'] as String?),
  );
}

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
    @Default(<HuntCategory>[]) List<HuntCategory> categories,
    @Default('') String search,
    @Default(false) bool includeLocked,
  }) = _HuntQuery;

  const HuntQuery._();

  /// Quantos grupos do escopo estão ativos (o número do badge de Filtros).
  int get scopeCount => [
    generations.isNotEmpty,
    types.isNotEmpty,
    categories.isNotEmpty,
    includeLocked,
  ].where((active) => active).length;

  /// Limpa o escopo, mantendo motivos e busca.
  HuntQuery clearScope() =>
      HuntQuery(reasons: reasons, acceptedBalls: acceptedBalls, search: search);

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
    };
  }
}

/// Simulação de um dex padrão (`GET /personal-dexes/preview/`).
@freezed
abstract class DexPreview with _$DexPreview {
  const factory DexPreview({
    required int forms,
    required int boxesNeeded,
    required int largestFreeRun,
    required bool enoughSpace,

    /// Onde o esquema começaria; `null` sem espaço.
    BoxRef? firstBox,
  }) = _DexPreview;

  factory DexPreview.fromJson(Map<String, dynamic> json) =>
      _$DexPreviewFromJson(json);
}
