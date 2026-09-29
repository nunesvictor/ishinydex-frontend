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
