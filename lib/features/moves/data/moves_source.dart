import 'package:dio/dio.dart';

/// De onde vêm os golpes: o arquivo `moves-AAAA.MM.DD.json`, ao lado do
/// catálogo (backend#134).
///
/// O nome leva a versão do catálogo, então o conteúdo nunca muda: o service
/// worker (`web/sw.js`) guarda o arquivo num cache próprio, que sobrevive às
/// versões do app, e só baixa de novo quando o catálogo muda.
class MovesSource {
  const MovesSource(this._dio, this.url);

  final Dio _dio;
  final String url;

  /// O texto do arquivo. [onProgress] recebe os bytes recebidos e o total
  /// (`null` quando o servidor não informa, como numa resposta comprimida).
  Future<String> fetch(void Function(int received, int? total) onProgress) =>
      _dio
          .get<String>(
            url,
            options: Options(responseType: ResponseType.plain),
            onReceiveProgress: (received, total) =>
                onProgress(received, total > 0 ? total : null),
          )
          .then((response) => response.data!);
}
