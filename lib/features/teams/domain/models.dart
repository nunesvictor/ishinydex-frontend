import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

part 'models.freezed.dart';

/// Um time de até [maxMembers] Pokémon, preso a um jogo (o grupo de versões,
/// #231): só aceita o que existe nele.
@freezed
abstract class Team with _$Team {
  const factory Team({
    required int id,
    required String name,

    /// O grupo de versões (`scarlet-violet`).
    required String versionGroup,
    @Default(<TeamMember>[]) List<TeamMember> members,
  }) = _Team;

  const Team._();

  static const maxMembers = 6;

  bool get isFull => members.length >= maxMembers;
}

/// Um membro do time: a forma, o nível, a habilidade, a natureza, o item, o
/// Tera, até 4 golpes, os EVs e os IVs. Pode apontar para um espécime do
/// inventário, de onde puxa a forma, a natureza e a habilidade.
@freezed
abstract class TeamMember with _$TeamMember {
  const factory TeamMember({
    required int form,
    FormRef? formRef,

    /// O espécime ligado; `null` = nenhum (ou o espécime foi apagado).
    int? specimen,
    @Default(TeamMember.defaultLevel) int level,

    /// A habilidade (o nome da PokéAPI, `as-one-spectrier`).
    String? ability,
    String? nature,

    /// O item segurado (o nome da PokéAPI, `focus-sash`).
    String? item,

    /// O tipo Tera (`fairy`, `stellar`), só no Scarlet/Violet.
    String? tera,

    /// Os golpes, pelo nome da PokéAPI, na ordem dos slots.
    @Default(<String>[]) List<String> moves,

    /// Os EVs por stat (`hp`, `attack`...); o que falta é 0.
    @Default(<String, int>{}) Map<String, int> evs,

    /// Os IVs por stat; o que falta é [maxIv].
    @Default(<String, int>{}) Map<String, int> ivs,
  }) = _TeamMember;

  const TeamMember._();

  static const defaultLevel = 50;
  static const maxMoves = 4;
  static const maxIv = 31;
  static const maxEv = 252;
  static const maxEvTotal = 510;

  int ev(String stat) => evs[stat] ?? 0;
  int iv(String stat) => ivs[stat] ?? maxIv;
  int get evTotal => evs.values.fold(0, (a, b) => a + b);
}
