import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

import '../fixtures/catalog_fixture.dart';

/// Slots vazios fora do arquivo de dados (#392).
void main() {
  final catalog = Catalog.fromJson(
    catalogJson(),
    spriteBase: Env.defaultSpritesBaseUrl,
  );

  /// Um aparelho, com o relógio [now] nas datas do arquivo.
  LocalData device({DateTime Function()? now}) => LocalData(
    store: LocalStore(InMemoryLocalDataStorage(), now: now),
    backend: FakeBackend.local(catalog),
    catalogVersion: catalog.version,
  );

  List<Map<String, dynamic>> slotsOf(Map<String, dynamic> file) => [
    for (final s in (file['records'] as Map)['slots'] as List)
      s as Map<String, dynamic>,
  ];

  Map<String, dynamic> slotMarks(Map<String, dynamic> file) =>
      ((file['deleted'] as Map)['slots'] as Map?)?.cast<String, dynamic>() ??
      const {};

  /// Os registros em ordem de id, para comparar dois aparelhos.
  String canonical(Map<String, List<Map<String, dynamic>>> records) =>
      jsonEncode({
        for (final type in records.keys.toList()..sort())
          type: [...records[type]!]
            ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int)),
      });

  test('ida e volta sem perda, do tamanho do arquivo real', () async {
    final phone = device();
    final backend = phone.backend;
    final dex = await backend.createDex(
      name: 'Shiny',
      isShinyDex: true,
      forceNewBox: true,
    );
    // 200 boxes: 6.000 células, quase todas vazias.
    for (var i = 0; i < 199; i++) {
      backend.addFreeBox('Livre $i');
    }
    final file = phone.currentFile();
    final occupied = slotsOf(file);
    // Só as células do dex: as 5.991 vazias ficam de fora.
    int total(List<BoxSummary> boxes) =>
        boxes.fold(0, (sum, box) => sum + box.total);
    expect(occupied, hasLength(total(await backend.fetchBoxes(dex.id))));
    expect(occupied.every((s) => s['form'] != null), isTrue);

    final copy = FakeBackend.local(
      catalog,
      records: LocalStore(InMemoryLocalDataStorage()).adopt(file),
    );
    expect(canonical(copy.records), canonical(backend.records));
    expect(total(await copy.fetchBoxes(dex.id)), occupied.length);

    // As células recriadas, com o id fixo e na ordem: um dex novo ocupa as
    // primeiras da primeira box livre.
    final other = await copy.createDex(
      name: 'Normal',
      isShinyDex: false,
      forceNewBox: true,
    );
    final box = (await copy.fetchBoxes(other.id)).first;
    final slots = await copy.fetchSlots(dexId: other.id, boxId: box.id);
    expect(
      [for (final s in slots) s.id],
      [
        for (var i = 0; i < slots.length; i++)
          FakeBackend.cellId(box.id, i ~/ 6, i % 6),
      ],
    );
  });

  test('arquivo do schema 6: os vazios saem sem virar exclusão', () async {
    final phone = device();
    await phone.backend.createDex(
      name: 'Shiny',
      isShinyDex: true,
      forceNewBox: true,
    );
    final file = phone.currentFile();
    final boxId = slotsOf(file).first['box'];
    final old = {
      ...file,
      'schemaVersion': 6,
      'records': {
        ...file['records'] as Map<String, dynamic>,
        'slots': [
          ...slotsOf(file),
          for (var col = 0; col < 6; col++)
            {
              'id': 900 + col,
              'box': boxId,
              'row': 4,
              'col': col,
              'dex': null,
              'form': null,
              'specimen': null,
              'updatedAt': '2026-10-01T00:00:00.000Z',
            },
        ],
      },
    };
    final laptop = device();
    await laptop.import(old, merge: false);
    final after = laptop.currentFile();
    expect(slotsOf(after), hasLength(slotsOf(file).length));
    expect(slotMarks(after), isEmpty);
  });

  test('liberar as células (apagar o dex) chega ao outro aparelho', () async {
    var clock = DateTime.utc(2026, 11);
    final phone = device(now: () => clock);
    final pc = device(now: () => clock);
    final dex = await phone.backend.createDex(
      name: 'Shiny',
      isShinyDex: true,
      forceNewBox: true,
    );
    await pc.import(phone.currentFile(), merge: true);
    final cells = slotsOf(pc.currentFile()).length;
    expect(cells, greaterThan(0));

    clock = DateTime.utc(2026, 11, 2);
    await phone.backend.deleteDex(dex.id);
    final freed = phone.currentFile();
    expect(slotsOf(freed), isEmpty);
    expect(slotMarks(freed), hasLength(cells));

    await pc.import(freed, merge: true);
    expect(slotsOf(pc.currentFile()), isEmpty);
    expect(await pc.backend.fetchDexes(), isEmpty);
  });

  test('conflito de célula: fica o mais novo; o espécime do outro volta ao '
      'inventário', () async {
    var clock = DateTime.utc(2026, 11);
    final phone = device(now: () => clock);
    final pc = device(now: () => clock);
    // Uma box livre, criada no celular e levada ao PC (sem as células).
    phone.backend.addFreeBox('Livre');
    await pc.import(phone.currentFile(), merge: true);

    // Cada aparelho cria um dex na mesma box, com ids de célula diferentes.
    final mine = await phone.backend.createDex(
      name: 'Do celular',
      isShinyDex: true,
      forceNewBox: false,
    );
    final phoneBox = (await phone.backend.fetchBoxes(mine.id)).first;
    final [first, ...] = await phone.backend.fetchSlots(
      dexId: mine.id,
      boxId: phoneBox.id,
    );
    final specimen = (await phone.backend.create(
      SpecimenDraft(form: first.form!.id),
    )).id;
    await phone.backend.deposit(slotId: first.id, specimenId: specimen);
    final fromPhone = phone.currentFile();
    clock = DateTime.utc(2026, 11, 2);
    final theirs = await pc.backend.createDex(
      name: 'Do PC',
      isShinyDex: false,
      forceNewBox: false,
    );
    final fromPc = pc.currentFile();

    await phone.import(fromPc, merge: true);
    final merged = phone.currentFile();
    final cells = {
      for (final s in slotsOf(merged)) '${s['box']}:${s['row']}:${s['col']}',
    };
    expect(cells, hasLength(slotsOf(merged).length));
    expect(slotsOf(merged).every((s) => s['dex'] == theirs.id), isTrue);
    expect(slotMarks(merged), isNotEmpty);
    // O espécime do celular continua, fora de slot.
    final kept = await phone.backend.fetchSpecimen(specimen);
    expect(kept.slot, isNull);
    expect(slotsOf(fromPhone), isNotEmpty);
  });
}
