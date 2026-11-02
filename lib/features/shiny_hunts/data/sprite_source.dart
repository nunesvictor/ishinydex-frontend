import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:ishinydex/features/shiny_hunts/domain/sprite_diff.dart';

/// Baixa um sprite e lê os pixels dele, para comparar o normal com o shiny
/// (#381). Os sprites do HOME têm 512 px; [size] reduz para a conta sair
/// rápida também no celular.
class SpriteSource {
  const SpriteSource(this._dio, {this.size = 256});

  final Dio _dio;
  final int size;

  Future<SpritePixels> pixels(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return await decodeSprite(Uint8List.fromList(response.data!), size: size);
  }
}

/// Os pixels RGBA de uma imagem (PNG), na largura [size].
Future<SpritePixels> decodeSprite(Uint8List bytes, {required int size}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: size);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData();
  final pixels = SpritePixels(
    width: image.width,
    height: image.height,
    rgba: data!.buffer.asUint8List(),
  );
  image.dispose();
  codec.dispose();
  return pixels;
}
