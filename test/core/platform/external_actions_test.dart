import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/platform/external_actions.dart';
import 'package:ishinydex/core/web/share_outcome.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final _png = Uint8List.fromList(const [1, 2, 3]);
const _origin = Rect.fromLTWH(10, 20, 300, 400);

void main() {
  group('linkOpener (#429)', () {
    test('no PWA, a aba nova do navegador (fora dele, não existe)', () {
      expect(
        () => linkOpener(web: true)('https://x.example'),
        throwsUnsupportedError,
      );
    });

    test('no nativo, o navegador do sistema', () async {
      final opened = <(Uri, LaunchMode)>[];
      linkOpener(
        launch: (url, {mode = LaunchMode.platformDefault}) async {
          opened.add((url, mode));
          return true;
        },
      )('https://bulbapedia.example/Eevee');
      await Future<void>.delayed(Duration.zero);
      expect(opened, [
        (
          Uri.parse('https://bulbapedia.example/Eevee'),
          LaunchMode.externalApplication,
        ),
      ]);
    });

    test('no nativo, uma falha ao abrir não derruba o app', () async {
      final errors = <Object>[];
      await runZonedGuarded(() async {
        linkOpener(
          launch: (url, {mode = LaunchMode.platformDefault}) =>
              Future<bool>.error(Exception('sem navegador')),
        )('https://x.example');
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => errors.add(error));
      expect(errors, isEmpty);
    });
  });

  group('fileSharer (#428)', () {
    test('no PWA, o Web Share do navegador (fora dele, não existe)', () {
      expect(
        () => fileSharer(web: true)(_png, name: 'a.png', type: 'image/png'),
        throwsUnsupportedError,
      );
    });

    test('no nativo, a folha do iOS com o arquivo e a origem', () async {
      ShareParams? sent;
      final outcome =
          await fileSharer(
            share: (params) async {
              sent = params;
              return const ShareResult(
                'com.apple.UIKit.activity.SaveToCameraRoll',
                ShareResultStatus.success,
              );
            },
          )(
            _png,
            name: 'ishinydex-pikachu.png',
            type: 'image/png',
            origin: _origin,
          );

      expect(outcome, ShareOutcome.shared);
      final file = sent!.files!.single;
      expect(await file.readAsBytes(), _png);
      expect(file.mimeType, 'image/png');
      expect(sent!.fileNameOverrides, ['ishinydex-pikachu.png']);
      expect(sent!.sharePositionOrigin, _origin);
    });

    for (final status in [
      ShareResultStatus.dismissed,
      ShareResultStatus.unavailable,
    ]) {
      test('fechou a folha ($status): sem aviso', () async {
        final outcome = await shareNatively(
          _png,
          name: 'a.png',
          type: 'image/png',
          share: (_) async => ShareResult('', status),
        );
        expect(outcome, ShareOutcome.cancelled);
        expect(outcome.silent, isTrue);
      });
    }

    test('erro do sistema: falhou (a tela avisa)', () async {
      final outcome = await shareNatively(
        _png,
        name: 'a.png',
        type: 'image/png',
        share: (_) => Future.error(Exception('sem folha')),
      );
      expect(outcome, ShareOutcome.failed);
    });

    test('o padrão é o SharePlus (sem o plugin nos testes: falhou)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final outcome = await shareNatively(
        _png,
        name: 'a.png',
        type: 'image/png',
      );
      expect(outcome, ShareOutcome.failed);
    });
  });
}
