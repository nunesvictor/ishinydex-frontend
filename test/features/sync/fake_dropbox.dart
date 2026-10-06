import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ishinydex/features/sync/data/dropbox_client.dart';

/// Um Dropbox em memória, no lugar da rede (adaptador HTTP do Dio): login,
/// renovação do token, a pasta do app com um arquivo e as regras do envio
/// condicional pela `rev`.
class FakeDropbox implements HttpClientAdapter {
  /// Conteúdo do arquivo de dados; `null` se não existe.
  Uint8List? file;
  int _version = 0;

  String? get rev => file == null ? null : 'r$_version';

  /// Sem internet: toda chamada falha sem resposta.
  bool offline = false;

  /// O refresh token foi revogado (no site do Dropbox).
  bool revoked = false;

  /// Próxima resposta de uma chamada da API, no lugar da normal.
  ({int status, Object body})? forced;

  /// Só força a resposta na rota que termina com isto (ex.: `download`).
  String? forcedOn;

  /// Roda antes de aceitar um envio: simula outro aparelho enviando antes.
  void Function()? beforeUpload;

  int tokenRefreshes = 0;
  final requests = <RequestOptions>[];

  /// Grava [content] como se outro aparelho tivesse enviado.
  void put(Map<String, dynamic> content) {
    file = utf8.encode(jsonEncode(content));
    _version++;
  }

  Map<String, dynamic>? get content => file == null
      ? null
      : jsonDecode(utf8.decode(file!)) as Map<String, dynamic>;

  Dio dio() => Dio()..httpClientAdapter = this;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sem internet',
      );
    }
    final body = requestStream == null
        ? Uint8List(0)
        : Uint8List.fromList(
            await requestStream.fold<List<int>>([], (all, c) => all..addAll(c)),
          );
    if (options.uri.toString() == DropboxClient.tokenEndpoint) {
      return _token(Uri.splitQueryString(utf8.decode(body)));
    }
    if (options.headers['Authorization'] case final String auth
        when !auth.startsWith('Bearer at')) {
      return _json(401, {'error_summary': 'invalid_access_token/'});
    }
    if (forced case final forced?
        when forcedOn == null || options.uri.path.endsWith(forcedOn!)) {
      this.forced = null;
      forcedOn = null;
      return forced.body is String
          ? ResponseBody.fromString(forced.body as String, forced.status)
          : _json(forced.status, forced.body);
    }
    final arg = switch (options.headers['Dropbox-API-Arg']) {
      final String raw => jsonDecode(raw) as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };
    return switch (options.uri.path) {
      '/2/files/get_metadata' =>
        rev == null
            ? _json(409, {'error_summary': 'path/not_found/...'})
            : _json(200, {'rev': rev}),
      '/2/files/download' => ResponseBody.fromBytes(file!, 200),
      '/2/files/upload' => _upload(arg['mode'] as Map<String, dynamic>, body),
      '/2/users/get_current_account' => _json(200, {
        'name': {'display_name': 'Victor N.'},
      }),
      _ => _json(404, {'error_summary': 'rota desconhecida'}),
    };
  }

  ResponseBody _token(Map<String, String> form) {
    switch (form['grant_type']) {
      case 'authorization_code' when form['code'] == 'bom':
        return _json(200, {
          'refresh_token': 'rt-${form['code_verifier']}',
          'access_token': 'at-login',
          'expires_in': 14400,
        });
      case 'refresh_token' when !revoked:
        tokenRefreshes++;
        return _json(200, {
          'access_token': 'at$tokenRefreshes',
          'expires_in': 14400,
        });
      default:
        return _json(400, {
          'error': 'invalid_grant',
          'error_description': 'refresh token is invalid or revoked',
        });
    }
  }

  ResponseBody _upload(Map<String, dynamic> mode, Uint8List body) {
    final before = beforeUpload;
    beforeUpload = null;
    before?.call();
    final ok = switch (mode['.tag']) {
      'add' => file == null,
      'update' => mode['update'] == rev,
      _ => true,
    };
    if (!ok) return _json(409, {'error_summary': 'path/conflict/file/..'});
    file = body;
    _version++;
    return _json(200, {'rev': rev});
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
