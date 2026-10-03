import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/auth/auth_providers.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/shiny_locks/data/http_shiny_lock_repository.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/domain/shiny_lock_repository.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

final shinyLockRepositoryProvider = Provider<ShinyLockRepository>((ref) {
  if (ref.watch(envProvider).usesLocalBackend) {
    return ref.watch(fakeBackendProvider);
  }
  return HttpShinyLockRepository(ref.watch(dioProvider));
});

final FutureProvider<List<ShinyLock>> shinyLocksProvider =
    FutureProvider.autoDispose<List<ShinyLock>>(
      (ref) => ref.watch(shinyLockRepositoryProvider).fetchShinyLocks(),
    );

final shinyLockActionsProvider = Provider<ShinyLockActions>(
  ShinyLockActions.new,
);

/// Criar, editar e apagar shiny locks, recarregando o que depende deles: a
/// lista, as caçadas (o aviso de shiny lock e o "incluir impossíveis") e o
/// detalhe das formas (o aviso no painel do slot e no cadastro de espécime).
class ShinyLockActions {
  ShinyLockActions(this._ref);

  final Ref _ref;

  ShinyLockRepository get _repository => _ref.read(shinyLockRepositoryProvider);

  Future<ShinyLock> create(ShinyLockDraft draft) async {
    final created = await _repository.createShinyLock(draft);
    _changed();
    return created;
  }

  Future<ShinyLock> update(int id, ShinyLockDraft draft) async {
    final updated = await _repository.updateShinyLock(id, draft);
    _changed();
    return updated;
  }

  Future<void> delete(int id) async {
    await _repository.deleteShinyLock(id);
    _changed();
  }

  void _changed() => _ref
    ..invalidate(shinyLocksProvider)
    ..invalidate(huntPageProvider)
    ..invalidate(formDetailProvider);
}
