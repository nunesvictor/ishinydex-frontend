import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Par do PKCE (RFC 7636), o login OAuth sem app secret: o [verifier] fica
/// no aparelho e o [challenge] (o SHA-256 dele) vai na URL de login. Na
/// volta, só quem tem o verificador consegue trocar o código pelo token.
class Pkce {
  Pkce(this.verifier)
    : challenge = _base64Url(sha256.convert(ascii.encode(verifier)).bytes);

  /// Verificador aleatório novo (32 bytes, 43 caracteres).
  factory Pkce.generate([Random? random]) => Pkce(randomToken(32, random));

  final String verifier;
  final String challenge;
}

/// [length] bytes aleatórios em base64url, sem `=`. Também serve de `state`
/// do login (protege contra uma volta que o app não iniciou).
String randomToken(int length, [Random? random]) {
  final source = random ?? Random.secure();
  return _base64Url([for (var i = 0; i < length; i++) source.nextInt(256)]);
}

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
