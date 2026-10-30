import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/moves/data/moves_source.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';

/// O `Dio` do download dos golpes.
final movesDioProvider = Provider<Dio>((ref) => Dio());

/// De onde baixar os golpes: o `movesFile` do catálogo, ao lado do
/// `catalog.json`. `null` sem o arquivo (catálogo antigo, ou a demonstração
/// sem catálogo): a aba diz que não há golpes.
final movesSourceProvider = Provider<MovesSource?>((ref) {
  final catalogUrl = ref.watch(envProvider).catalogUrl;
  final file = ref.watch(fakeBackendProvider).catalog?.movesFile;
  if (catalogUrl == null || file == null) return null;
  return MovesSource(
    ref.watch(movesDioProvider),
    Uri.parse(catalogUrl).resolve(file).toString(),
  );
});

/// O estado dos golpes (#36).
sealed class MovesState {
  const MovesState();
}

/// Sem o arquivo dos golpes.
class MovesUnavailable extends MovesState {
  const MovesUnavailable();
}

/// Baixando: os bytes recebidos e o total (`null` se o servidor não diz).
class MovesDownloading extends MovesState {
  const MovesDownloading({this.received = 0, this.total});

  final int received;
  final int? total;
}

/// Baixado, lendo o arquivo.
class MovesPreparing extends MovesState {
  const MovesPreparing();
}

class MovesReady extends MovesState {
  const MovesReady(this.data);

  final MovesData data;
}

/// Não deu para baixar: [offline] quando foi a conexão.
class MovesFailed extends MovesState {
  const MovesFailed({required this.offline});

  final bool offline;
}

/// Os golpes, baixados uma vez só, na primeira vez que a aba Golpes (ou a
/// busca) os pede, e guardados na memória enquanto o app está aberto. A
/// inicialização nunca chama este provider.
final movesProvider = NotifierProvider<MovesNotifier, MovesState>(
  MovesNotifier.new,
);

class MovesNotifier extends Notifier<MovesState> {
  @override
  MovesState build() {
    final source = ref.watch(movesSourceProvider);
    if (source == null) return const MovesUnavailable();
    unawaited(Future.microtask(() => _load(source)));
    return const MovesDownloading();
  }

  /// Tenta de novo depois de uma falha.
  void retry() {
    final source = ref.read(movesSourceProvider);
    if (source == null || state is! MovesFailed) return;
    state = const MovesDownloading();
    unawaited(_load(source));
  }

  Future<void> _load(MovesSource source) async {
    try {
      final text = await source.fetch((received, total) {
        state = MovesDownloading(received: received, total: total);
      });
      state = const MovesPreparing();
      // Um quadro para a tela mostrar o "Preparando" antes da leitura.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      state = MovesReady(
        MovesData.fromJson(jsonDecode(text) as Map<String, dynamic>),
      );
    } on Object catch (error) {
      state = MovesFailed(
        offline:
            error is DioException &&
            (error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout),
      );
    }
  }
}
