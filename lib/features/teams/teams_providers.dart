import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/domain/team_repository.dart';

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => ref.watch(fakeBackendProvider),
);

/// Os times do team builder (#231).
final FutureProvider<List<Team>> teamsProvider =
    FutureProvider.autoDispose<List<Team>>(
      (ref) => ref.watch(teamRepositoryProvider).fetchTeams(),
    );

/// Os espécimes de uma forma, para ligar a um membro.
final FutureProviderFamily<List<Specimen>, int> formSpecimensProvider =
    FutureProvider.autoDispose.family<List<Specimen>, int>(
      (ref, formId) =>
          ref.watch(teamRepositoryProvider).fetchSpecimensOfForm(formId),
    );

final teamActionsProvider = Provider<TeamActions>(TeamActions.new);

/// O que se faz com um time; cada ação grava e recarrega a lista. Falhas
/// (`AppFailure`) sobem para a tela mostrar.
class TeamActions {
  TeamActions(this._ref);

  final Ref _ref;

  Future<Team> save(Team team) async {
    final saved = await _ref.read(teamRepositoryProvider).saveTeam(team);
    _ref.invalidate(teamsProvider);
    return saved;
  }

  /// Troca o membro [index] por [member] (ou acrescenta, no fim).
  Future<Team> saveMember(Team team, int index, TeamMember member) => save(
    team.copyWith(
      members: [
        for (final (i, m) in team.members.indexed)
          if (i == index) member else m,
        if (index >= team.members.length) member,
      ],
    ),
  );

  Future<Team> removeMember(Team team, int index) => save(
    team.copyWith(
      members: [
        for (final (i, m) in team.members.indexed)
          if (i != index) m,
      ],
    ),
  );

  Future<void> delete(int teamId) async {
    await _ref.read(teamRepositoryProvider).deleteTeam(teamId);
    _ref.invalidate(teamsProvider);
  }
}
