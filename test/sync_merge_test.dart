// Règles de fusion (section 9): la dernière modification gagne pour les
// réglages; les traits sont fusionnés, jamais effacés silencieusement.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:monako/data/local_store.dart';
import 'package:monako/data/sync_service.dart';

void main() {
  late LocalStore store;
  late SyncService sync;

  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('monako_test').path);
  });

  setUp(() async {
    store = LocalStore();
    await store.open(inMemory: true);
    await store.clearAll();
    sync = SyncService(null, store);
  });

  Map<String, dynamic> stroke(String time, {bool deleted = false, String role = 'ink.primary'}) => {
        'id': 's1',
        'notebook_id': 'n1',
        'page_id': 'p1',
        'role': role,
        'width': 2.4,
        'points': '',
        'modified_at': time,
        'deleted': deleted,
      };

  test('une ligne distante inconnue est ajoutée', () async {
    expect(await sync.mergeRemote(Tables.strokes, stroke('2026-01-01T00:00:00Z')), isTrue);
    expect((await store.pageRows(Tables.strokes, 'p1')).length, 1);
    expect(store.pendingCount, 0);
  });

  test('la modification la plus récente gagne', () async {
    await store.put(Tables.strokes, stroke('2026-01-02T00:00:00Z', role: 'ink.accent1'));
    await sync.mergeRemote(Tables.strokes, stroke('2026-01-01T00:00:00Z', role: 'ink.accent2'));
    var local = await store.getElement(Tables.strokes, 'p1|s1');
    expect(local!['role'], 'ink.accent1');

    await sync.mergeRemote(Tables.strokes, stroke('2026-01-03T00:00:00Z', role: 'ink.accent3'));
    local = await store.getElement(Tables.strokes, 'p1|s1');
    expect(local!['role'], 'ink.accent3');
  });

  test('une suppression locale n’est jamais annulée par une version distante', () async {
    await store.put(Tables.strokes, stroke('2026-01-01T00:00:00Z', deleted: true));
    await sync.mergeRemote(Tables.strokes, stroke('2026-01-05T00:00:00Z'));
    final local = await store.getElement(Tables.strokes, 'p1|s1');
    expect(local!['deleted'], isTrue);
    expect(store.isDirty(Tables.strokes, 'p1|s1'), isTrue, reason: 'à envoyer');
  });

  test('une suppression distante gagne même plus ancienne', () async {
    await store.put(Tables.strokes, stroke('2026-01-05T00:00:00Z'));
    await sync.mergeRemote(Tables.strokes, stroke('2026-01-01T00:00:00Z', deleted: true));
    final local = await store.getElement(Tables.strokes, 'p1|s1');
    expect(local!['deleted'], isTrue);
  });

  test('traits de deux appareils fusionnés sans perte', () async {
    await store.put(Tables.strokes, {...stroke('2026-01-01T00:00:00Z'), 'id': 'a'});
    await sync.mergeRemote(Tables.strokes, {...stroke('2026-01-01T00:00:01Z'), 'id': 'b'});
    final rows = await store.pageRows(Tables.strokes, 'p1');
    expect(rows.map((r) => r['id']).toSet(), {'a', 'b'});
  });

  test('markClean ignore une ligne modifiée pendant l’envoi', () async {
    await store.put(Tables.folders, {'id': 'f', 'name': 'A', 'modified_at': 't1', 'deleted': false});
    await store.put(Tables.folders, {'id': 'f', 'name': 'B', 'modified_at': 't2', 'deleted': false});
    await store.markClean(Tables.folders, 'f', 't1');
    expect(store.isDirty(Tables.folders, 'f'), isTrue);
    await store.markClean(Tables.folders, 'f', 't2');
    expect(store.isDirty(Tables.folders, 'f'), isFalse);
  });
}
