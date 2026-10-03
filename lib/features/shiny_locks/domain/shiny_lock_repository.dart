import 'package:ishinydex/features/shiny_locks/domain/models.dart';

/// Cadastro de shiny locks (`/shiny-locks/`).
abstract interface class ShinyLockRepository {
  /// Todos, em ordem alfabética (poucas dezenas: sem paginação).
  Future<List<ShinyLock>> fetchShinyLocks();

  /// Nome repetido, sem formas ou tipo inválido → `ValidationFailure`, com o
  /// erro no campo (`caption`, `forms`, `lock_type`).
  Future<ShinyLock> createShinyLock(ShinyLockDraft draft);

  Future<ShinyLock> updateShinyLock(int id, ShinyLockDraft draft);

  /// Apaga só o lock; as formas continuam.
  Future<void> deleteShinyLock(int id);
}
