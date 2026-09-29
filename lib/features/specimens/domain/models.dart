import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
abstract class Specimen with _$Specimen {
  const factory Specimen({
    required int id,
    required int form,
    FormRef? formRef,
    String? formName,
    String? nickname,
    String? ability,
    String? language,
    String? gender,
    String? nature,
    @Default(false) bool isAlpha,
    @Default(false) bool isShiny,
    @Default(false) bool isFromGo,
    DateTime? capturedAt,
    String? pokeball,
    String? pokeballSpriteUrl,
    String? observation,
    int? ot,
    int? slot,
  }) = _Specimen;

  const Specimen._();

  factory Specimen.fromJson(Map<String, dynamic> json) =>
      _$SpecimenFromJson(json);

  String get displayName {
    final nick = nickname;
    if (nick != null && nick.isNotEmpty) return nick;
    return prettifyName(formName ?? formRef?.name ?? 'Specimen #$id');
  }

  String? get spriteUrl => formRef?.spriteFor(shiny: isShiny);

  bool get isDeposited => slot != null;
}

/// Dados para criar (`POST /specimens/`) ou editar
/// (`PATCH /specimens/{id}/`) um specimen.
@freezed
abstract class SpecimenDraft with _$SpecimenDraft {
  const factory SpecimenDraft({
    required int form,
    String? nickname,
    String? ability,
    String? language,
    String? gender,
    String? nature,
    @Default(false) bool isAlpha,
    @Default(false) bool isShiny,
    @Default(false) bool isFromGo,
    DateTime? capturedAt,
    String? pokeball,
    String? observation,
    int? ot,
  }) = _SpecimenDraft;

  const SpecimenDraft._();

  /// Rascunho preenchido com os dados atuais, para o formulário de edição.
  factory SpecimenDraft.fromSpecimen(Specimen specimen) => SpecimenDraft(
    form: specimen.form,
    nickname: specimen.nickname,
    ability: specimen.ability,
    language: specimen.language,
    gender: specimen.gender,
    nature: specimen.nature,
    isAlpha: specimen.isAlpha,
    isShiny: specimen.isShiny,
    isFromGo: specimen.isFromGo,
    capturedAt: specimen.capturedAt,
    pokeball: specimen.pokeball,
    observation: specimen.observation,
    ot: specimen.ot,
  );

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Omite campos vazios; `captured_at` vai como data (`yyyy-MM-dd`).
  Map<String, dynamic> toRequestJson() => {
    'form': form,
    if (_filled(nickname)) 'nickname': nickname,
    if (_filled(ability)) 'ability': ability,
    if (_filled(language)) 'language': language,
    if (_filled(gender)) 'gender': gender,
    if (_filled(nature)) 'nature': nature,
    'is_alpha': isAlpha,
    'is_shiny': isShiny,
    'is_from_go': isFromGo,
    if (capturedAt != null) 'captured_at': _dateFormat.format(capturedAt!),
    if (_filled(pokeball)) 'pokeball': pokeball,
    if (_filled(observation)) 'observation': observation,
    if (ot != null) 'ot': ot,
  };

  /// Para o PATCH: envia todos os campos, com `null` nos vazios, para que
  /// apagar um valor (ex.: o apelido) também chegue ao backend. `form` fica
  /// de fora porque não pode mudar depois da criação.
  Map<String, dynamic> toUpdateJson() => {
    'nickname': _orNull(nickname),
    'ability': _orNull(ability),
    'language': _orNull(language),
    'gender': _orNull(gender),
    'nature': _orNull(nature),
    'is_alpha': isAlpha,
    'is_shiny': isShiny,
    'is_from_go': isFromGo,
    'captured_at': capturedAt == null ? null : _dateFormat.format(capturedAt!),
    'pokeball': _orNull(pokeball),
    'observation': _orNull(observation),
    'ot': ot,
  };

  static bool _filled(String? value) => value != null && value.isNotEmpty;

  static String? _orNull(String? value) => _filled(value) ? value : null;
}

@freezed
abstract class FormType with _$FormType {
  const factory FormType({required int slot, required String type}) = _FormType;

  factory FormType.fromJson(Map<String, dynamic> json) =>
      _$FormTypeFromJson(json);
}

@freezed
abstract class FormAbility with _$FormAbility {
  const factory FormAbility({
    required int slot,
    required String ability,
    @Default(false) bool isHidden,
  }) = _FormAbility;

  factory FormAbility.fromJson(Map<String, dynamic> json) =>
      _$FormAbilityFromJson(json);
}

@freezed
abstract class FormDetail with _$FormDetail {
  const factory FormDetail({
    required int id,
    required String name,
    required int pokeapiId,
    required String spriteUrl,
    required String shinySpriteUrl,
    @Default('') String formName,
    @Default(<FormType>[]) List<FormType> types,
    @Default(<FormAbility>[]) List<FormAbility> abilities,
    @Default(false) bool isShinylocked,
    @Default(false) bool isDistroOnly,
  }) = _FormDetail;

  factory FormDetail.fromJson(Map<String, dynamic> json) =>
      _$FormDetailFromJson(json);
}

/// Opção de um select. Pokébolas trazem também o [spriteUrl].
@freezed
abstract class Choice with _$Choice {
  const factory Choice({
    required String value,
    required String label,
    String? spriteUrl,
  }) = _Choice;

  factory Choice.fromJson(Map<String, dynamic> json) => _$ChoiceFromJson(json);
}

@freezed
abstract class SpecimenOptions with _$SpecimenOptions {
  const factory SpecimenOptions({
    @Default(<Choice>[]) List<Choice> language,
    @Default(<Choice>[]) List<Choice> gender,
    @Default(<Choice>[]) List<Choice> nature,
    @Default(<Choice>[]) List<Choice> pokeball,
  }) = _SpecimenOptions;

  factory SpecimenOptions.fromJson(Map<String, dynamic> json) =>
      _$SpecimenOptionsFromJson(json);
}

@freezed
abstract class Trainer with _$Trainer {
  const factory Trainer({
    required int id,
    required String name,
    required String trainerId,
    String? version,
  }) = _Trainer;

  const Trainer._();

  factory Trainer.fromJson(Map<String, dynamic> json) =>
      _$TrainerFromJson(json);

  String get label => '$name ($trainerId)';
}
