import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// O login do Dropbox não vale mais (revogado no site do Dropbox, por
/// exemplo): é preciso conectar de novo.
class DropboxAuthException implements Exception {
  const DropboxAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sem conexão com o Dropbox (sem internet, ou o Dropbox fora do ar).
class DropboxOfflineException implements Exception {
  const DropboxOfflineException();
}

/// O arquivo mudou no Dropbox desde a `rev` informada: outro aparelho
/// enviou antes. Quem chama baixa de novo, junta e tenta outra vez.
class DropboxConflictException implements Exception {
  const DropboxConflictException();
}

/// Resposta inesperada do Dropbox.
class DropboxException implements Exception {
  const DropboxException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// O arquivo no Dropbox: a `rev` (versão, para o envio condicional) e o
/// conteúdo.
typedef RemoteFile = ({String rev, Uint8List bytes});

/// A API HTTP do Dropbox, só com o que o sync usa. O app tem acesso apenas à
/// própria pasta (`Apps/<nome do app>`), e o arquivo de dados fica na raiz
/// dela.
class DropboxClient {
  DropboxClient(
    this._dio, {
    required this.appKey,
    required this.refreshToken,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const authorizeEndpoint = 'https://www.dropbox.com/oauth2/authorize';
  static const tokenEndpoint = 'https://api.dropboxapi.com/oauth2/token';
  static const apiBase = 'https://api.dropboxapi.com/2';
  static const contentBase = 'https://content.dropboxapi.com/2';

  /// O arquivo de dados, na pasta do app.
  static const path = '/ishinydex.json';

  final Dio _dio;
  final String appKey;
  final String refreshToken;
  final DateTime Function() _now;

  String? _accessToken;
  DateTime? _expiresAt;

  /// URL do login. [redirectUri] é a página do app (sem endereço fixo); o
  /// `token_access_type=offline` pede o refresh token, que não expira.
  static Uri authorizeUrl({
    required String appKey,
    required String redirectUri,
    required String challenge,
    required String state,
  }) => Uri.parse(authorizeEndpoint).replace(
    queryParameters: {
      'client_id': appKey,
      'response_type': 'code',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'token_access_type': 'offline',
      'redirect_uri': redirectUri,
      'state': state,
    },
  );

  /// Troca o código da volta do login pelo refresh token.
  static Future<String> exchangeCode(
    Dio dio, {
    required String appKey,
    required String code,
    required String verifier,
    required String redirectUri,
  }) async {
    final body = await _tokenRequest(dio, {
      'code': code,
      'grant_type': 'authorization_code',
      'code_verifier': verifier,
      'client_id': appKey,
      'redirect_uri': redirectUri,
    });
    return body['refresh_token'] as String;
  }

  static Future<Map<String, dynamic>> _tokenRequest(
    Dio dio,
    Map<String, String> data,
  ) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        tokenEndpoint,
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response.data!;
    } on DioException catch (error) {
      // 400 invalid_grant: código usado/expirado, ou refresh token revogado.
      if (error.response?.statusCode case 400 || 401) {
        throw DropboxAuthException(_describe(error.response!.data));
      }
      throw _translate(error);
    }
  }

  /// Token de acesso (vale ~4 h), renovado pelo refresh token quando falta
  /// menos de 1 min para expirar.
  Future<String> _token() async {
    final expiresAt = _expiresAt;
    if (_accessToken != null &&
        expiresAt != null &&
        _now().isBefore(expiresAt.subtract(const Duration(minutes: 1)))) {
      return _accessToken!;
    }
    final body = await _tokenRequest(_dio, {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': appKey,
    });
    _expiresAt = _now().add(Duration(seconds: body['expires_in'] as int));
    return _accessToken = body['access_token'] as String;
  }

  /// Chamada autenticada; erros viram as exceções acima.
  Future<Response<T>> _call<T>(
    String url, {
    Object? data,
    String? contentType,
    String? arg,
    ResponseType? responseType,
  }) async {
    final token = await _token();
    try {
      return await _dio.post<T>(
        url,
        data: data,
        options: Options(
          contentType: contentType,
          responseType: responseType,
          headers: {'Authorization': 'Bearer $token', 'Dropbox-API-Arg': ?arg},
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        _accessToken = null;
        throw DropboxAuthException(_describe(error.response!.data));
      }
      throw _translate(error);
    }
  }

  /// O arquivo de dados, ou `null` se ainda não existe.
  Future<RemoteFile?> download() async {
    // A rev vem do get_metadata (resposta JSON comum), e não do cabeçalho do
    // download, que o navegador só expõe se o servidor permitir. Se o
    // arquivo mudar entre as duas chamadas, o envio com a rev antiga dá
    // conflito, e o sync recomeça: nada se perde.
    final String rev;
    try {
      final meta = await _call<Map<String, dynamic>>(
        '$apiBase/files/get_metadata',
        data: {'path': path},
        contentType: Headers.jsonContentType,
      );
      rev = meta.data!['rev'] as String;
    } on DropboxException catch (error) {
      if (error.message.contains('not_found')) return null;
      rethrow;
    }
    final file = await _call<List<int>>(
      '$contentBase/files/download',
      // O Dropbox aceita este tipo nos downloads pelo navegador (sem ele, o
      // cliente HTTP poderia mandar um que o Dropbox recusa).
      contentType: 'text/plain; charset=dropbox-cors-hack',
      arg: jsonEncode({'path': path}),
      responseType: ResponseType.bytes,
    );
    return (rev: rev, bytes: Uint8List.fromList(file.data!));
  }

  /// Envia o arquivo; devolve a nova rev. Com [rev], só substitui se o
  /// arquivo no Dropbox ainda for essa versão
  /// ([DropboxConflictException] se não for); sem [rev], só cria (conflito
  /// se já existir), a não ser com [overwrite].
  Future<String> upload(
    Uint8List bytes, {
    String? rev,
    bool overwrite = false,
  }) async {
    final mode = overwrite
        ? {'.tag': 'overwrite'}
        : rev != null
        ? {'.tag': 'update', 'update': rev}
        : {'.tag': 'add'};
    try {
      final response = await _call<Map<String, dynamic>>(
        '$contentBase/files/upload',
        // Bytes, e não texto: com um corpo string, o WebKit acrescenta
        // ";charset=UTF-8" ao tipo e o Dropbox responde 400 (ishinydex#53).
        data: bytes,
        contentType: 'application/octet-stream',
        arg: jsonEncode({
          'path': path,
          'mode': mode,
          'autorename': false,
          'mute': true,
        }),
      );
      return response.data!['rev'] as String;
    } on DropboxException catch (error) {
      if (error.message.contains('conflict')) {
        throw const DropboxConflictException();
      }
      rethrow;
    }
  }

  /// Nome da conta conectada, para mostrar em Sincronização.
  Future<String> accountName() async {
    final response = await _call<Map<String, dynamic>>(
      '$apiBase/users/get_current_account',
      // Esta rota não tem argumentos: o corpo é "null" em JSON.
      data: 'null',
      contentType: Headers.jsonContentType,
    );
    final name = response.data!['name'] as Map<String, dynamic>;
    return name['display_name'] as String;
  }

  /// Erros do Dio: sem resposta é sem conexão; com resposta, o motivo que o
  /// Dropbox mandou (`error_summary` em JSON, ou texto puro nos 400).
  static Exception _translate(DioException error) {
    final response = error.response;
    if (response == null) return const DropboxOfflineException();
    return DropboxException(
      '${response.statusCode} ${_describe(response.data)}'.trim(),
    );
  }

  static String _describe(Object? data) => switch (data) {
    {'error_summary': final String summary} => summary,
    {'error_description': final String description} => description,
    {'error': final String error} => error,
    final String text => text,
    final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
    _ => '',
  };
}
