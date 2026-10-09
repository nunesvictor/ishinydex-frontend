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

    /// Jogo de origem (nome da versão), derivado do OT pelo backend.
    String? originVersion,

    /// Marca de origem (`paldea`, `go`...); `null` = sem marca.
    String? originMark,

    /// Save onde o espécime está; `null` = no HOME.
    Save? location,

    /// Desde quando está no [location].
    DateTime? locationSince,

    /// Como saiu o shiny e quanto custou (só em shiny).
    HuntRecord? hunt,
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

  bool get isAway => location != null;
}

/// Registro da caçada que rendeu o espécime (#163). Tudo opcional.
@freezed
abstract class HuntRecord with _$HuntRecord {
  const factory HuntRecord({
    /// Id do método no catálogo (`shinyMethods`).
    String? method,

    /// A contagem na [unit]; em horas, guarda minutos.
    int? count,

    /// Unidade da contagem (`encounters`, `hours`...), uma das do método.
    String? unit,
    DateTime? startedAt,

    /// Link do post (ex.: r/ShinyPokemon).
    String? postUrl,
  }) = _HuntRecord;

  const HuntRecord._();

  factory HuntRecord.fromJson(Map<String, dynamic> json) =>
      _$HuntRecordFromJson(json);

  /// Sem método, contagem nem post: não vale guardar (só a data de início,
  /// que o formulário preenche com hoje, não conta).
  bool get isBlank =>
      method == null && count == null && (postUrl == null || postUrl!.isEmpty);
}

/// Nomes em pt-BR das unidades dos métodos de shiny.
const huntUnitLabels = {
  'encounters': 'encontros',
  'hours': 'horas',
  'resets': 'resets',
  'eggs': 'ovos',
  'chains': 'cadeia',
  'runs': 'runs',
  'raids': 'reides',
  'hordes': 'hordas',
  'combo': 'combo',
};

/// `"4.213 resets"`, ou `"38 h 30 min"` em horas (a contagem são minutos).
String huntCountLabel(int count, String? unit) {
  if (unit == 'hours') {
    final (h, m) = (count ~/ 60, count % 60);
    return m == 0 ? '$h h' : (h == 0 ? '$m min' : '$h h $m min');
  }
  final number = NumberFormat.decimalPattern('pt_BR').format(count);
  return unit == null ? number : '$number ${huntUnitLabels[unit] ?? unit}';
}

/// Quanto durou a caçada, de [start] até [end]: `"12 dias"`, `"3 meses"`,
/// `"2 anos"`. No mesmo dia, `"menos de um dia"`.
String huntDuration(DateTime start, DateTime end) {
  final days = end.difference(start).inDays;
  String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  if (days < 1) return 'menos de um dia';
  if (days < 30) return plural(days, 'dia', 'dias');
  if (days < 365) return plural(days ~/ 30, 'mês', 'meses');
  return plural(days ~/ 365, 'ano', 'anos');
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
    HuntRecord? hunt,
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
    hunt: specimen.hunt,
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
    if (hunt != null) 'hunt': hunt!.toJson(),
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
    'hunt': hunt?.toJson(),
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

/// Status base do Pokémon (`stat` como na PokéAPI: `hp`, `attack`...).
/// [effort] é o EV que ele dá ao ser derrotado.
@freezed
abstract class FormStat with _$FormStat {
  const factory FormStat({
    required String stat,
    required int baseStat,
    @Default(0) int effort,
  }) = _FormStat;

  const FormStat._();

  factory FormStat.fromJson(Map<String, dynamic> json) =>
      _$FormStatFromJson(json);

  /// Nome do status como nos jogos em português.
  String get label => switch (stat) {
    'hp' => 'HP',
    'attack' => 'Ataque',
    'defense' => 'Defesa',
    'special-attack' => 'Atq. Esp.',
    'special-defense' => 'Def. Esp.',
    'speed' => 'Velocidade',
    _ => prettifyName(stat),
  };
}

/// Detalhe da forma (`GET /forms/{id}/`): tipos, habilidades, status base e
/// os dados da espécie (linha evolutiva, outras formas, gênero...).
@freezed
abstract class FormDetail with _$FormDetail {
  const factory FormDetail({
    required int id,
    required String name,
    required int pokeapiId,
    required String spriteUrl,
    required String shinySpriteUrl,
    @Default('') String formName,
    int? nationalNumber,
    @Default(<FormType>[]) List<FormType> types,
    @Default(<FormAbility>[]) List<FormAbility> abilities,
    @Default(<FormStat>[]) List<FormStat> stats,

    /// Chance de fêmea em oitavos (0 = só macho, 8 = só fêmea); -1 = sem
    /// gênero.
    int? genderRate,
    int? captureRate,

    /// Ciclos de ovo.
    int? hatchCounter,

    /// Decímetros e hectogramas, como na PokéAPI.
    int? height,
    int? weight,

    /// Versões do grupo em que a forma estreou (`red-japan`...).
    @Default(<String>[]) List<String> debutVersions,

    /// Estágios da linha evolutiva (ramificações no mesmo estágio); vazio se
    /// a espécie não evolui nem vem de outra.
    @Default(<List<FormRef>>[]) List<List<FormRef>> evolutionChain,

    /// Demais formas da espécie (Mega, Gigantamax, regionais).
    @Default(<FormRef>[]) List<FormRef> otherForms,

    /// Os jogos do HOME em cuja pokédex a espécie está (vazio sem o
    /// catálogo).
    @Default(<GamePokedex>[]) List<GamePokedex> pokedexes,
    @Default(false) bool isShinylocked,
    @Default(false) bool isDistroOnly,
  }) = _FormDetail;

  const FormDetail._();

  factory FormDetail.fromJson(Map<String, dynamic> json) =>
      _$FormDetailFromJson(json);
}

/// Um jogo do HOME e as pokédex dele em que uma espécie está.
@freezed
abstract class GamePokedex with _$GamePokedex {
  const factory GamePokedex({
    required String versionGroup,

    /// As versões do jogo que recebem do HOME (`scarlet`, `violet`).
    required List<String> versions,
    required List<PokedexEntry> entries,
  }) = _GamePokedex;

  factory GamePokedex.fromJson(Map<String, dynamic> json) =>
      _$GamePokedexFromJson(json);
}

/// A espécie numa pokédex: o nome dela e o número (`null` nas pokédex
/// especiais, como a da Aventura Dinamax).
@freezed
abstract class PokedexEntry with _$PokedexEntry {
  const factory PokedexEntry({
    required String label,
    int? number,
    @Default(false) bool dlc,
  }) = _PokedexEntry;

  const PokedexEntry._();

  factory PokedexEntry.fromJson(Map<String, dynamic> json) =>
      _$PokedexEntryFromJson(json);

  /// "Galar nº 383", "Tundra Coroada nº 139 (DLC)", "Aventura Dinamax (DLC)".
  String get description =>
      '$label${number == null ? '' : ' nº $number'}${dlc ? ' (DLC)' : ''}';
}

/// Opção de um select. Pokébolas e tipos trazem também o [spriteUrl].
@freezed
abstract class Choice with _$Choice {
  const factory Choice({
    required String value,
    required String label,
    String? spriteUrl,

    /// Só nas naturezas: o stat que ela aumenta e o que diminui (nomes de
    /// [FormStat.stat]); `null` nas neutras.
    String? increased,
    String? decreased,
  }) = _Choice;

  factory Choice.fromJson(Map<String, dynamic> json) => _$ChoiceFromJson(json);
}

/// Rótulo de [value] entre as [choices] de `/specimens/options/`
/// (`"adamant"` → `"Adamant"`). Fora da lista, cai no [prettifyName]; sem
/// valor, é nulo.
String? choiceLabel(List<Choice>? choices, String? value) {
  if (value == null || value.isEmpty) return null;
  for (final c in choices ?? const <Choice>[]) {
    if (c.value == value) return c.label;
  }
  return prettifyName(value);
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
    @Default(<Choice>[]) List<Choice> originMark,
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
    return '$name ($trainerId)${v == null ? '' : ' · ${versionLabel(v)}'}';
  }
}

/// Um save do usuário (`GET /saves/`): onde um espécime pode estar fora do
/// HOME. A identidade (nome, TID e versão) é a do [trainer].
@freezed
abstract class Save with _$Save {
  const factory Save({
    required int id,
    required Trainer trainer,
    @Default('') String label,
  }) = _Save;

  const Save._();

  factory Save.fromJson(Map<String, dynamic> json) => _$SaveFromJson(json);

  /// Jogos que recebem Pokémon do HOME (só os OTs desses viram save).
  static const transferVersions = {
    'lets-go-pikachu',
    'lets-go-eevee',
    'sword',
    'shield',
    'brilliant-diamond',
    'shining-pearl',
    'legends-arceus',
    'scarlet',
    'violet',
    'legends-za',
  };

  /// Jogos que só recebem Pokémon com uma marca de origem: o Let's Go só
  /// aceita de volta quem veio dele (ver [accepts]).
  static const requiredMarks = {
    'lets-go-pikachu': 'lets-go',
    'lets-go-eevee': 'lets-go',
  };

  /// A marca exigida para entrar no save (ver [requiredMarks]).
  String? get requiredMark => requiredMarks[trainer.version];

  /// Se um Pokémon com a marca de origem [mark] e o OT de [otVersion] pode
  /// entrar no save. Num jogo com [requiredMark], além da marca dele, vale
  /// a do GO quando o OT é de um jogo com a mesma marca: é quem foi do GO
  /// para o Let's Go pelo GO Park e pode voltar a ele.
  bool accepts(String? mark, String? otVersion) {
    final required = requiredMark;
    return required == null ||
        mark == required ||
        (mark == 'go' && requiredMarks[otVersion] == required);
  }

  /// Por que o save recusa um Pokémon (ver [accepts]); `null` = aceita
  /// qualquer um.
  String? get restriction => requiredMark == null
      ? null
      : "Só Pokémon do Let's Go, ou do GO com OT de Let's Go (GO Park)";

  /// `"Scarlet"`: o jogo do save.
  String get game => versionLabel(trainer.version ?? '');

  /// De quem é, sem o jogo: o apelido ou o treinador (`"Ash (123456)"`).
  String get owner =>
      label.isEmpty ? '${trainer.name} (${trainer.trainerId})' : label;

  /// `"Scarlet · Switch Lite"`, ou com o treinador se não houver apelido:
  /// `"Scarlet · Ash (123456)"`.
  String get title => '$game · $owner';
}

/// Dias desde [since] até hoje (0 = hoje).
int daysSince(DateTime since, {DateTime? today}) {
  final now = today ?? DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(since.year, since.month, since.day)).inDays;
}

/// `"hoje"`, `"há 1 dia"`, `"há 203 dias"`.
String awayFor(DateTime since, {DateTime? today}) =>
    switch (daysSince(since, today: today)) {
      <= 0 => 'hoje',
      1 => 'há 1 dia',
      final days => 'há $days dias',
    };

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

  /// `"legends-za"` → `"Legends: Z-A"` ([versionLabel]).
  String get label => versionLabel(name);
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
  /// Onde o espécime fica nas boxes (o próprio slot, se depositado; senão o
  /// 1º slot com a forma dele). É a ordem padrão.
  box('box', 'Ordem das boxes'),

  /// Nº da espécie na Pokédex nacional (formas da mesma espécie juntas).
  national('national', 'Nº da Pokédex nacional'),
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
    @Default(<String>[]) List<String> pokeballs,
    @Default(false) bool withoutPokeball,

    /// Até 2 tipos; a forma precisa ter todos.
    @Default(<String>[]) List<String> types,
    @Default(<int>[]) List<int> ots,
    @Default(false) bool withoutOt,
    @Default(<String>[]) List<String> generations,

    /// Qualquer uma das categorias da espécie (como nas caçadas).
    @Default(<SpeciesCategory>[]) List<SpeciesCategory> categories,

    /// Marcas de origem (`paldea`, `go`, `none` = sem marca).
    @Default(<String>[]) List<String> originMarks,
    @Default(<String>[]) List<String> genders,
    @Default(<String>[]) List<String> natures,
    @Default(<String>[]) List<String> languages,
    @Default('') String ability,
    DateTime? capturedAfter,
    DateTime? capturedBefore,
    @Default(SpecimenOrdering.box) SpecimenOrdering ordering,

    /// Só estes espécimes (chip "Só selecionados" do lote). Não é um filtro
    /// da folha: não conta no [advancedCount].
    @Default(<int>[]) List<int> ids,

    /// Onde está: [locationHome], [locationAway] ou o id de um save (como
    /// texto); vazio = qualquer lugar.
    @Default('') String location,
  }) = _SpecimenQuery;

  const SpecimenQuery._();

  /// Máximo de tipos (Pokémon têm no máximo dois).
  static const maxTypes = 2;

  /// Valor que a API entende como "sem" (pokébola, OT).
  static const noneParam = 'none';

  /// Valores de [location]: no HOME ou fora dele (em qualquer save).
  static const locationHome = 'home';
  static const locationAway = 'away';

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  bool get hasPokeballFilter => pokeballs.isNotEmpty || withoutPokeball;
  bool get hasOtFilter => ots.isNotEmpty || withoutOt;
  bool get hasCaptureFilter => capturedAfter != null || capturedBefore != null;

  /// Algum filtro (rápido ou avançado) restringe a lista? A ordem não conta.
  bool get hasFilters =>
      copyWith(ordering: SpecimenOrdering.box) != emptySpecimenQuery;

  /// Quantos grupos de filtros avançados estão ativos (o número do badge do
  /// botão Filtros). A ordem conta quando não é a padrão.
  int get advancedCount => [
    hasPokeballFilter,
    types.isNotEmpty,
    hasOtFilter,
    generations.isNotEmpty,
    categories.isNotEmpty,
    originMarks.isNotEmpty,
    genders.isNotEmpty,
    natures.isNotEmpty,
    languages.isNotEmpty,
    ability.trim().isNotEmpty,
    hasCaptureFilter,
    location.isNotEmpty,
    ordering != SpecimenOrdering.box,
  ].where((active) => active).length;

  /// Limpa os filtros avançados, mantendo os rápidos.
  SpecimenQuery clearAdvanced() => SpecimenQuery(
    search: search,
    status: status,
    shinyOnly: shinyOnly,
    alphaOnly: alphaOnly,
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
      if (hasPokeballFilter)
        'pokeball': join([...pokeballs, if (withoutPokeball) noneParam]),
      if (types.isNotEmpty) 'type': join(types),
      if (hasOtFilter) 'ot': join([...ots, if (withoutOt) noneParam]),
      if (generations.isNotEmpty) 'generation': join(generations),
      if (categories.isNotEmpty)
        'category': join(categories.map((c) => c.param)),
      if (originMarks.isNotEmpty) 'origin_mark': join(originMarks),
      if (genders.isNotEmpty) 'gender': join(genders),
      if (natures.isNotEmpty) 'nature': join(natures),
      if (languages.isNotEmpty) 'language': join(languages),
      if (ability.isNotEmpty) 'ability': ability,
      if (capturedAfter != null)
        'captured_after': _dateFormat.format(capturedAfter!),
      if (capturedBefore != null)
        'captured_before': _dateFormat.format(capturedBefore!),
      if (ordering != SpecimenOrdering.box) 'ordering': ordering.param,
      if (ids.isNotEmpty) 'id': join(ids),
      if (location.isNotEmpty) 'location': location,
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
