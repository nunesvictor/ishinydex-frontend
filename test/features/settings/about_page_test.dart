import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/catalog/data/catalog_loader.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/settings/presentation/about_page.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

void main() {
  testWidgets('versão, endereço do projeto e aviso legal', (tester) async {
    await pumpWidgetApp(
      tester,
      const AboutPage(),
      overrides: [
        envProvider.overrideWithValue(const Env(appVersion: 'v2.0.0')),
      ],
    );
    expect(find.text('Versão v2.0.0'), findsOneWidget);
    expect(find.text(projectUrl), findsOneWidget);
    expect(find.textContaining('The Pokémon Company'), findsOneWidget);
  });

  testWidgets('modo local com sync: a cópia no Dropbox', (tester) async {
    await pumpWidgetApp(
      tester,
      const AboutPage(),
      overrides: [
        envProvider.overrideWithValue(
          const Env(localData: true, dropboxAppKey: 'k'),
        ),
      ],
    );
    expect(find.textContaining('neste aparelho'), findsOneWidget);
    expect(find.textContaining('seu Dropbox'), findsOneWidget);
  });

  testWidgets('demonstração: dados fictícios, nada é enviado', (tester) async {
    await pumpWidgetApp(
      tester,
      const AboutPage(),
      overrides: [envProvider.overrideWithValue(const Env())],
    );
    expect(find.textContaining('Esta é uma demonstração'), findsOneWidget);
    expect(find.textContaining('Nada do que você faz'), findsOneWidget);
    expect(find.textContaining('Catálogo'), findsNothing);
  });

  testWidgets('modo local: os dados ficam neste aparelho', (tester) async {
    await pumpWidgetApp(
      tester,
      const AboutPage(),
      overrides: [envProvider.overrideWithValue(const Env(localData: true))],
    );
    expect(find.textContaining('ficam neste aparelho'), findsOneWidget);
    expect(find.textContaining('seu Dropbox'), findsNothing);
  });

  testWidgets('com o catálogo: versão e tempo de carga', (tester) async {
    await pumpWidgetApp(
      tester,
      const AboutPage(),
      overrides: [
        envProvider.overrideWithValue(const Env()),
        catalogLoadProvider.overrideWithValue(
          CatalogLoad(
            catalog: Catalog.fromJson(catalogJson(), spriteBase: 'http://s'),
            elapsed: const Duration(milliseconds: 230),
          ),
        ),
      ],
    );
    expect(
      find.text('Catálogo catalog-2026.10.03 · carregado em 230 ms'),
      findsOneWidget,
    );
    expect(find.textContaining('seu Dropbox'), findsNothing);
  });

  testWidgets('Ajustes → Sobre', (tester) async {
    await pumpFullApp(tester, size: compactSize);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sobre o iShinyDex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sobre o iShinyDex'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.textContaining('Esta é uma demonstração'), findsOneWidget);
  });
}
