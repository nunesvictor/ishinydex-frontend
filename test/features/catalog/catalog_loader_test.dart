import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/catalog/data/catalog_loader.dart';

import '../../fixtures/catalog_fixture.dart';

const _url = 'https://pages.example/ishinydex/catalog/catalog.json';

/// Um catálogo guardado na memória, para os testes do [loadCatalog].
class _MemoryCache implements CatalogCache {
  _MemoryCache([this.json]);

  String? json;

  @override
  Future<String?> read() async => json;

  @override
  Future<void> write(String json) async => this.json = json;
}

/// A versão do catálogo guardado.
String _version(String? json) =>
    (jsonDecode(json!) as Map<String, dynamic>)['version'] as String;

/// O fixture com outra versão: diz qual dos dois o app abriu.
String _catalogVersion(String version) =>
    jsonEncode({...catalogJson(), 'version': version});

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
  });

  Future<CatalogLoad> load(
    CatalogCache? cache, {
    Duration grace = const Duration(seconds: 2),
  }) => loadCatalog(
    dio,
    url: _url,
    spriteBase: Env.defaultSpritesBaseUrl,
    cache: cache,
    grace: grace,
  );

  group('loadCatalog com o catálogo guardado (#427)', () {
    test('PWA (sem cache): só a rede', () async {
      adapter.onGet(_url, (server) => server.reply(200, catalogJson()));
      expect((await load(null)).catalog.version, 'catalog-2026.10.03');
    });

    test('primeira abertura: espera a rede e guarda', () async {
      adapter.onGet(_url, (server) => server.reply(200, catalogJson()));
      final cache = _MemoryCache();
      expect((await load(cache)).catalog.version, 'catalog-2026.10.03');
      expect(jsonDecode(cache.json!), catalogJson());
    });

    test('primeira abertura sem internet: falha (a tela de erro)', () async {
      adapter.onGet(
        _url,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: _url),
            reason: 'Failed host lookup',
          ),
        ),
      );
      final cache = _MemoryCache();
      await expectLater(load(cache), throwsA(isA<DioException>()));
      expect(cache.json, isNull);
    });

    test('com internet: o catálogo novo, que passa a ser o guardado', () async {
      adapter.onGet(
        _url,
        (server) => server.reply(200, jsonDecode(_catalogVersion('novo'))),
      );
      final cache = _MemoryCache(_catalogVersion('guardado'));
      expect((await load(cache)).catalog.version, 'novo');
      expect(_version(cache.json), 'novo');
    });

    test('sem internet: abre com o guardado', () async {
      adapter.onGet(
        _url,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: _url),
            reason: 'Failed host lookup',
          ),
        ),
      );
      final cache = _MemoryCache(_catalogVersion('guardado'));
      expect((await load(cache)).catalog.version, 'guardado');
    });

    test(
      'rede lenta: abre com o guardado e guarda o novo quando chega',
      () async {
        adapter.onGet(
          _url,
          (server) => server.reply(
            200,
            jsonDecode(_catalogVersion('novo')),
            delay: const Duration(milliseconds: 100),
          ),
        );
        final cache = _MemoryCache(_catalogVersion('guardado'));
        final opened = await load(
          cache,
          grace: const Duration(milliseconds: 20),
        );
        expect(opened.catalog.version, 'guardado');
        expect(_version(cache.json), 'guardado');

        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(_version(cache.json), 'novo');
      },
    );

    test(
      'resposta que não é catálogo: não guarda, abre com o guardado',
      () async {
        adapter.onGet(_url, (server) => server.reply(200, '<html>erro</html>'));
        final cache = _MemoryCache(_catalogVersion('guardado'));
        expect((await load(cache)).catalog.version, 'guardado');
        expect(_version(cache.json), 'guardado');
      },
    );
  });

  group('FileCatalogCache', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('catalog_cache'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('nada guardado: null; depois de gravar, o mesmo texto', () async {
      final cache = FileCatalogCache(
        directory: () async => Directory('${dir.path}/suporte'),
      );
      expect(await cache.read(), isNull);
      await cache.write('{"version":"a"}');
      expect(await cache.read(), '{"version":"a"}');
      await cache.write('{"version":"b"}');
      expect(await cache.read(), '{"version":"b"}');
      expect(File('${dir.path}/suporte/catalog.json.part').existsSync(), false);
    });

    test('sem a pasta: lê null e gravar não quebra a abertura', () async {
      final cache = FileCatalogCache(
        directory: () async => throw const FileSystemException('sem disco'),
      );
      expect(await cache.read(), isNull);
      await cache.write('{}');
    });

    test('pasta impossível de criar: gravar não quebra a abertura', () async {
      File('${dir.path}/suporte').writeAsStringSync('');
      final cache = FileCatalogCache(
        directory: () async => Directory('${dir.path}/suporte'),
      );
      await cache.write('{}');
      expect(await cache.read(), isNull);
    });
  });
}
