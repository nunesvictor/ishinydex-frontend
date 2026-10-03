import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/local/data/data_file_io.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';
import 'package:ishinydex/features/local/presentation/local_data_tiles.dart';

import '../../helpers/helpers.dart';

class _FakeIo implements DataFileIo {
  ({String name, Uint8List bytes})? next;
  String? savedName;

  @override
  Future<({String name, Uint8List bytes})?> pick() async => next;

  @override
  Future<void> save(String name, Uint8List bytes) async => savedName = name;
}

void main() {
  late FakeBackend backend;
  late LocalData data;
  late _FakeIo io;

  Future<void> openSettings(WidgetTester tester) async {
    backend = FakeBackend.seeded();
    data = LocalData(
      store: LocalStore(InMemoryLocalDataStorage()),
      backend: backend,
      catalogVersion: 'catalog-x',
    );
    io = _FakeIo();
    await pumpFullApp(
      tester,
      backend: backend,
      overrides: [
        localDataProvider.overrideWithValue(data),
        dataFileIoProvider.overrideWithValue(io),
      ],
    );
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
  }

  Future<void> tapTile(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('fora do modo local, a seção não aparece', (tester) async {
    await pumpFullApp(tester);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Seus dados'), findsNothing);
  });

  testWidgets('exportar baixa o arquivo e avisa', (tester) async {
    await openSettings(tester);
    expect(find.text('Seus dados'), findsOneWidget);
    await tapTile(tester, 'Exportar dados');
    expect(io.savedName, startsWith('ishinydex-'));
    expect(find.text('Exportado: ${io.savedName}'), findsOneWidget);
  });

  testWidgets('importar: desistir, arquivo inválido e cancelar', (
    tester,
  ) async {
    await openSettings(tester);
    await tapTile(tester, 'Importar dados');
    expect(find.byType(ImportDialog), findsNothing);

    io.next = (name: 'x.txt', bytes: utf8.encode('oi'));
    await tapTile(tester, 'Importar dados');
    expect(
      find.text('Não é um arquivo de dados do iShinyDex.'),
      findsOneWidget,
    );

    io.next = (name: 'b.json', bytes: data.export().bytes);
    await tapTile(tester, 'Importar dados');
    expect(find.byType(ImportDialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportDialog), findsNothing);
  });

  testWidgets('importar juntando: resumo, escolha e volta aos dexes', (
    tester,
  ) async {
    await openSettings(tester);
    // Um arquivo de outro aparelho, com um treinador a mais.
    final other = FakeBackend.seeded()
      ..addTrainer(name: 'Gary', trainerId: '777777');
    final file = LocalData(
      store: LocalStore(InMemoryLocalDataStorage()),
      backend: other,
      catalogVersion: 'catalog-x',
    ).export();
    io.next = (name: file.name, bytes: file.bytes);

    await tapTile(tester, 'Importar dados');
    expect(find.text(file.name), findsOneWidget);
    expect(find.textContaining('2 dexes'), findsOneWidget);
    await tester.tap(find.text('Juntar com os dados deste aparelho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.text('Dados importados.'), findsOneWidget);
    expect(find.text('Shiny Living Dex'), findsWidgets);
    expect([
      for (final t in await backend.fetchTrainers()) t.name,
    ], contains('Gary'));
  });

  testWidgets('diálogo: singular e plural no resumo', (tester) async {
    await pumpWidgetApp(
      tester,
      ImportDialog(
        name: 'a.json',
        summary: (
          dexes: 1,
          specimens: 1,
          saves: 0,
          savedAt: DateTime(2026, 10, 3, 9, 30),
        ),
      ),
    );
    expect(find.textContaining('1 dex · 1 espécime · 0 saves'), findsOneWidget);
    expect(find.textContaining('03/10/2026 09:30'), findsOneWidget);
  });
}
