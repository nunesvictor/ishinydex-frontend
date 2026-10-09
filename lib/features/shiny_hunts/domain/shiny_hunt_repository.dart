import 'package:ishinydex/features/shiny_hunts/domain/models.dart';

/// As caçadas em andamento e pausadas (#164).
abstract interface class ShinyHuntRepository {
  Future<List<ShinyHunt>> fetchShinyHunts();

  /// Cria ([ShinyHunt.id] 0) ou grava a caçada. Só um cronômetro roda por
  /// vez: começar outro com um rodando é recusado.
  Future<ShinyHunt> saveShinyHunt(ShinyHunt hunt);

  /// Apaga a caçada (excluir uma pausada, ou o fim pelo "Encontrei!").
  Future<void> deleteShinyHunt(int huntId);
}
