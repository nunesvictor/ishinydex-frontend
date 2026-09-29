import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/network/app_failure.dart';
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
  const factory FormType({
    required int slot,
    required String type,

    /// Ícone 60×60 do tipo; `null` se o backend não tiver o arquivo.
    String? spriteUrl,
  }) = _FormType;

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

/// Opção de um select. Pokébolas e tipos trazem também o [spriteUrl].
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
    @Default(<Choice>[]) List<Choice> type,
    @Default(<Choice>[]) List<Choice> generation,
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

  String get label {
    final v = version;
    return '$name ($trainerId)${v == null ? '' : ' · ${prettifyName(v)}'}';
  }
}

/// Versão de jogo (`GET /versions/`), usada no cadastro de treinador.
@freezed
abstract class GameVersion with _$GameVersion {
  const factory GameVersion({
    required String name,
    required String versionGroup,
    required String generation,
  }) = _GameVersion;

  const GameVersion._();

  factory GameVersion.fromJson(Map<String, dynamic> json) =>
      _$GameVersionFromJson(json);

  /// `"lets-go-pikachu"` → `"Lets Go Pikachu"`.
  String get label => prettifyName(name);
}

/// Situação do specimen no inventário.
enum SpecimenStatus {
  all,
  available,
  deposited;

  /// Valor do filtro `available` da API (`null` = sem filtro).
  bool? get availableParam => switch (this) {
    SpecimenStatus.all => null,
    SpecimenStatus.available => true,
    SpecimenStatus.deposited => false,
  };
}

/// Ordem do inventário; [param] é o valor de `ordering` na API.
enum SpecimenOrdering {
  dex('dex', 'Nº da Pokédex'),
  capturedDesc('-captured_at', 'Capturados recentemente'),
  capturedAsc('captured_at', 'Capturados há mais tempo'),
  createdDesc('-created_at', 'Cadastrados recentemente');

  SpecimenOrdering(this.param, this.label);

  final String param;
  final String label;
}

/// Filtros do inventário.
///
/// Classe freezed, e não record: serve de chave de provider e tem listas.
/// Records comparam listas por identidade (duas listas iguais seriam chaves
/// diferentes); o freezed compara pelo conteúdo.
///
/// Os filtros "rápidos" (busca, status, ✨, 💢, GO) ficam sempre na barra;
/// os demais ("avançados") ficam na folha de filtros.
@freezed
abstract class SpecimenQuery with _$SpecimenQuery {
  const factory SpecimenQuery({
    @Default('') String search,
    @Default(SpecimenStatus.all) SpecimenStatus status,
    @Default(false) bool shinyOnly,
    @Default(false) bool alphaOnly,
    @Default(false) bool fromGoOnly,
    @Default(<String>[]) List<String> pokeballs,
    @Default(false) bool withoutPokeball,

    /// Até 2 tipos; a forma precisa ter todos.
    @Default(<String>[]) List<String> types,
    @Default(<int>[]) List<int> ots,
    @Default(false) bool withoutOt,
    @Default(<String>[]) List<String> generations,
    @Default(<String>[]) List<String> genders,
    @Default(<String>[]) List<String> natures,
    @Default(<String>[]) List<String> languages,
    @Default('') String ability,
    DateTime? capturedAfter,
    DateTime? capturedBefore,
    @Default(SpecimenOrdering.dex) SpecimenOrdering ordering,
  }) = _SpecimenQuery;

  const SpecimenQuery._();

  /// Máximo de tipos (Pokémon têm no máximo dois).
  static const maxTypes = 2;

  /// Valor que a API entende como "sem" (pokébola, OT).
  static const noneParam = 'none';

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  bool get hasPokeballFilter => pokeballs.isNotEmpty || withoutPokeball;
  bool get hasOtFilter => ots.isNotEmpty || withoutOt;
  bool get hasCaptureFilter => capturedAfter != null || capturedBefore != null;

  /// Quantos grupos de filtros avançados estão ativos (o número do badge do
  /// botão Filtros). A ordem conta quando não é a padrão.
  int get advancedCount => [
    hasPokeballFilter,
    types.isNotEmpty,
    hasOtFilter,
    generations.isNotEmpty,
    genders.isNotEmpty,
    natures.isNotEmpty,
    languages.isNotEmpty,
    ability.trim().isNotEmpty,
    hasCaptureFilter,
    ordering != SpecimenOrdering.dex,
  ].where((active) => active).length;

  /// Limpa os filtros avançados, mantendo os rápidos.
  SpecimenQuery clearAdvanced() => SpecimenQuery(
    search: search,
    status: status,
    shinyOnly: shinyOnly,
    alphaOnly: alphaOnly,
    fromGoOnly: fromGoOnly,
  );

  /// Parâmetros de `GET /specimens/`: só os filtros em uso.
  Map<String, dynamic> toQueryParameters() {
    String join(Iterable<Object> values) => values.join(',');
    final search = this.search.trim();
    final ability = this.ability.trim();
    return {
      if (search.isNotEmpty) 'search': search,
      'available': ?status.availableParam,
      if (shinyOnly) 'is_shiny': true,
      if (alphaOnly) 'is_alpha': true,
      if (fromGoOnly) 'is_from_go': true,
      if (hasPokeballFilter)
        'pokeball': join([...pokeballs, if (withoutPokeball) noneParam]),
      if (types.isNotEmpty) 'type': join(types),
      if (hasOtFilter) 'ot': join([...ots, if (withoutOt) noneParam]),
      if (generations.isNotEmpty) 'generation': join(generations),
      if (genders.isNotEmpty) 'gender': join(genders),
      if (natures.isNotEmpty) 'nature': join(natures),
      if (languages.isNotEmpty) 'language': join(languages),
      if (ability.isNotEmpty) 'ability': ability,
      if (capturedAfter != null)
        'captured_after': _dateFormat.format(capturedAfter!),
      if (capturedBefore != null)
        'captured_before': _dateFormat.format(capturedBefore!),
      if (ordering != SpecimenOrdering.dex) 'ordering': ordering.param,
    };
  }
}

const emptySpecimenQuery = SpecimenQuery();

/// Edição de um campo no lote: [Keep] não envia o campo; [SetTo] envia o
/// valor, e `SetTo(null)` remove (pokébola, OT, data de captura).
///
/// *Sealed class*: o compilador sabe que só existem esses dois casos, então
/// um `switch` sobre `FieldEdit` sem `default` é verificado por completo.
@immutable
sealed class FieldEdit<T> {
  const FieldEdit();
}

final class Keep<T> extends FieldEdit<T> {
  const Keep();

  @override
  bool operator ==(Object other) => other is Keep<T>;

  @override
  int get hashCode => (Keep<T>).hashCode;
}

final class SetTo<T> extends FieldEdit<T> {
  const SetTo(this.value);

  final T? value;

  @override
  bool operator ==(Object other) => other is SetTo<T> && other.value == value;

  @override
  int get hashCode => Object.hash(SetTo<T>, value);
}

/// Alterações da edição em lote (`PATCH /specimens/bulk/`). Todo campo
/// começa em [Keep].
@freezed
abstract class SpecimenChanges with _$SpecimenChanges {
  const factory SpecimenChanges({
    @Default(Keep<String>()) FieldEdit<String> pokeball,
    @Default(Keep<int>()) FieldEdit<int> ot,
    @Default(Keep<String>()) FieldEdit<String> language,
    @Default(Keep<String>()) FieldEdit<String> gender,
    @Default(Keep<String>()) FieldEdit<String> nature,
    @Default(Keep<DateTime>()) FieldEdit<DateTime> capturedAt,
    @Default(Keep<bool>()) FieldEdit<bool> isShiny,
    @Default(Keep<bool>()) FieldEdit<bool> isAlpha,
    @Default(Keep<bool>()) FieldEdit<bool> isFromGo,
  }) = _SpecimenChanges;

  const SpecimenChanges._();

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Só os campos alterados, com as chaves da API.
  Map<String, dynamic> toJson() => {
    for (final (key, edit) in _edits)
      if (edit case SetTo(:final value))
        key: value is DateTime ? _dateFormat.format(value) : value,
  };

  /// Quantos campos mudam.
  int get count => toJson().length;

  bool get isEmpty => count == 0;

  List<(String, FieldEdit<Object>)> get _edits => [
    ('pokeball', pokeball),
    ('ot', ot),
    ('language', language),
    ('gender', gender),
    ('nature', nature),
    ('captured_at', capturedAt),
    ('is_shiny', isShiny),
    ('is_alpha', isAlpha),
    ('is_from_go', isFromGo),
  ];
}

/// Espécime cujo gênero não combina com a forma (resposta 400 do bulk).
typedef GenderConflict = ({int id, String formName});

/// O lote pediu um gênero impossível para alguns espécimes; nada foi
/// gravado.
class GenderConflictFailure extends ValidationFailure {
  GenderConflictFailure(this.conflicts, {required String message})
    : super({
        'gender': [message],
      });

  final List<GenderConflict> conflicts;
}
