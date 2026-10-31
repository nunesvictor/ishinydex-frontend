import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/teams/domain/models.dart';

/// Os times do team builder (#231).
abstract interface class TeamRepository {
  Future<List<Team>> fetchTeams();

  /// Cria ([Team.id] 0) ou grava o time.
  Future<Team> saveTeam(Team team);

  Future<void> deleteTeam(int teamId);

  /// Os espécimes da forma [formId], para ligar a um membro.
  Future<List<Specimen>> fetchSpecimensOfForm(int formId);

  /// As formas que têm espécime no inventário (a marca "No inventário" das
  /// formas sugeridas pela sinergia, #374).
  Future<Set<int>> fetchOwnedForms();
}
