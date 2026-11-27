import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/remote_image.dart';
import 'package:material_ui/material_ui.dart';

/// Um PNG de 1×1 transparente: a menor imagem que o Flutter decodifica.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x60,
  0x60,
  0x60,
  0x60,
  0x00,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0xA5,
  0xF6,
  0x45,
  0x40,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

const _url = 'https://sprites.example/pokemon/shiny/25.png';

void main() {
  late Directory dir;
  late List<Uri> downloads;

  /// Um cache numa pasta temporária, contando os downloads.
  RemoteImageCache cache({Download? download}) => RemoteImageCache(
    directory: () async => Directory('${dir.path}/images'),
    download:
        download ??
        (url) async {
          downloads.add(url);
          return _png;
        },
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('remote_image_test');
    downloads = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('remoteImage', () {
    test('no PWA, o NetworkImage (o service worker guarda)', () {
      final image = remoteImage(_url, web: true);
      expect(image, isA<NetworkImage>());
      expect((image as NetworkImage).url, _url);
    });

    test('no nativo, guardada em disco; o mesmo endereço, a mesma chave', () {
      final image = remoteImage(_url);
      expect(image, const DiskCachedImage(_url));
      expect(image.hashCode, const DiskCachedImage(_url).hashCode);
      expect(image, isNot(const DiskCachedImage('$_url?outra')));
      expect('$image', 'DiskCachedImage("$_url")');
    });
  });

  group('RemoteImageCache', () {
    test('baixa uma vez; da segunda em diante, lê do disco', () async {
      final store = cache();
      expect(await store.bytes(_url), _png);
      expect(downloads, [Uri.parse(_url)]);
      expect((await store.fileFor(_url)).existsSync(), isTrue);

      // Outro cache na mesma pasta: o app aberto de novo, memória vazia.
      expect(await cache().bytes(_url), _png);
      expect(downloads, hasLength(1));
    });

    test('o nome do arquivo é o SHA-1 do endereço', () async {
      final file = await cache().fileFor(_url);
      expect(file.path, matches(RegExp(r'/images/[0-9a-f]{40}$')));
      expect((await cache().fileFor('$_url?b')).path, isNot(file.path));
    });

    test('arquivo vazio (gravação interrompida) é baixado de novo', () async {
      final store = cache();
      final file = await store.fileFor(_url);
      await file.create(recursive: true);
      expect(await store.bytes(_url), _png);
      expect(downloads, hasLength(1));
      expect(file.readAsBytesSync(), _png);
      expect(File('${file.path}.part').existsSync(), isFalse);
    });

    test('sem a pasta do cache, ainda baixa (só não guarda)', () async {
      final store = RemoteImageCache(
        directory: () async => throw const FileSystemException('sem disco'),
        download: (url) async {
          downloads.add(url);
          return _png;
        },
      );
      expect(await store.bytes(_url), _png);
      expect(await store.bytes(_url), _png);
      expect(downloads, hasLength(2));
      await store.evict(_url); // nada a apagar, sem erro
    });

    test('sem conseguir gravar, a imagem aparece do mesmo jeito', () async {
      // Um arquivo onde devia ficar a pasta: criar a pasta falha.
      File('${dir.path}/images').writeAsStringSync('');
      final store = cache();
      expect(await store.bytes(_url), _png);
      expect(downloads, hasLength(1));
    });

    test('falha no download não grava nada', () async {
      final store = cache(
        download: (url) async => throw HttpException('HTTP 404', uri: url),
      );
      await expectLater(store.bytes(_url), throwsA(isA<HttpException>()));
      expect((await store.fileFor(_url)).existsSync(), isFalse);
    });

    test('evict apaga o arquivo guardado', () async {
      final store = cache();
      await store.bytes(_url);
      await store.evict(_url);
      expect((await store.fileFor(_url)).existsSync(), isFalse);
      await store.evict(_url); // de novo: já não existe, sem erro
    });

    test('o padrão guarda na pasta de cache do app', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(
              channel,
              (call) async => '/caches/ishinydex',
            );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final file = await RemoteImageCache().fileFor(_url);
      expect(file.path, startsWith('/caches/ishinydex/images/'));
    });
  });

  group('DiskCachedImage', () {
    /// Resolve a imagem fora do relógio falso (lê arquivo e decodifica).
    Future<Object> resolve(WidgetTester tester, ImageProvider image) async {
      final value = await tester.runAsync(() {
        final result = Completer<Object>();
        final stream = image.resolve(ImageConfiguration.empty);
        late final ImageStreamListener listener;
        void done(Object value) {
          stream.removeListener(listener);
          result.complete(value);
        }

        listener = ImageStreamListener(
          (info, _) => done(info),
          onError: (error, _) => done(error),
        );
        stream.addListener(listener);
        return result.future;
      });
      return value!;
    }

    testWidgets('decodifica o que veio do cache', (tester) async {
      final store = cache();
      final value = await resolve(tester, DiskCachedImage(_url, cache: store));
      expect(value, isA<ImageInfo>());
      expect((value as ImageInfo).image.width, 1);
      value.dispose();
      expect(downloads, hasLength(1));
    });

    testWidgets('sem cache próprio, usa o do app', (tester) async {
      final previous = RemoteImageCache.instance;
      addTearDown(() => RemoteImageCache.instance = previous);
      RemoteImageCache.instance = cache();
      final value = await resolve(tester, const DiskCachedImage('$_url?app'));
      expect(value, isA<ImageInfo>());
      (value as ImageInfo).dispose();
      expect(downloads, [Uri.parse('$_url?app')]);
    });

    testWidgets('o que não é imagem falha e sai do disco', (tester) async {
      final store = cache(
        download: (url) async {
          downloads.add(url);
          return Uint8List.fromList('<html>erro</html>'.codeUnits);
        },
      );
      final value = await resolve(
        tester,
        DiskCachedImage('$_url?ruim', cache: store),
      );
      expect(value, isNot(isA<ImageInfo>()));
      final file = await tester.runAsync(() => store.fileFor('$_url?ruim'));
      expect(file!.existsSync(), isFalse);
    });
  });
}
