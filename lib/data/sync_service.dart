import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_store.dart';
import 'models.dart';

/// Résultat d'un passage de synchronisation: ce qui a changé localement.
class SyncChanges {
  final Set<String> tables = {};
  final Set<String> pageIds = {};
  bool get isEmpty => tables.isEmpty;
}

enum SyncState { idle, syncing, offline, error, disabled }

/// Synchronisation entre appareils via Supabase (seul back-end).
///
/// 1. Tirer: chaque table, par pagination « keyset » sur
///    (server_updated_at, id) depuis le dernier curseur.
/// 2. Fusionner: la dernière modification gagne pour les réglages; les
///    suppressions (pierres tombales) gagnent toujours; les traits sont
///    fusionnés, jamais effacés silencieusement.
/// 3. Pousser: la file d'envoi locale, table par table (parents d'abord).
///
/// Le serveur applique les mêmes règles (déclencheur `monako_sync_guard`).
class SyncService extends ChangeNotifier {
  SyncService(this._client, this._store);

  final SupabaseClient? _client;
  final LocalStore _store;

  static const _pageSize = 500;
  static const _pushChunk = 200;
  static const bucket = 'assets';

  SyncState _state = SyncState.idle;
  SyncState get state => _client == null ? SyncState.disabled : _state;
  DateTime? lastSync;
  String? lastError;

  final _changes = StreamController<SyncChanges>.broadcast();

  /// Changements reçus du serveur (pull ou temps réel).
  Stream<SyncChanges> get changes => _changes.stream;

  Future<void>? _running;
  bool _again = false;
  RealtimeChannel? _channel;

  String? get _uid => _client?.auth.currentUser?.id;

  /// Identifiant du compte connecté (null hors connexion ou sans Supabase).
  String? get currentUserId => _uid;

  bool get enabled => _client != null && _uid != null;

  /// Lance une synchronisation (une seule à la fois; les demandes pendant
  /// un passage en déclenchent un autre à la fin).
  Future<void> sync() {
    if (!enabled) return Future.value();
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _syncOnce();
    } while (_again && enabled);
  }

  Future<void> _syncOnce() async {
    _state = SyncState.syncing;
    notifyListeners();
    try {
      final changes = SyncChanges();
      await _adoptLocalRows();
      for (final t in Tables.ordered) {
        await _pull(t, changes);
      }
      await _evictRevokedNotebooks(changes);
      await _push();
      lastSync = DateTime.now();
      lastError = null;
      _state = SyncState.idle;
      if (!changes.isEmpty) _changes.add(changes);
    } on AuthException catch (e) {
      lastError = e.message;
      _state = SyncState.error;
    } catch (e) {
      lastError = '$e';
      _state = _looksOffline(e) ? SyncState.offline : SyncState.error;
      debugPrint('Synchronisation: $e');
    }
    notifyListeners();
  }

  static bool _looksOffline(Object e) {
    final s = '$e'.toLowerCase();
    return s.contains('socket') ||
        s.contains('failed host lookup') ||
        s.contains('network') ||
        s.contains('clientexception') ||
        s.contains('xmlhttprequest');
  }

  // ------------------------------------------------------------------
  // Données créées hors connexion: attribuées au compte à la connexion.
  // ------------------------------------------------------------------

  Future<void> _adoptLocalRows() async {
    final uid = _uid!;
    for (final (table, key, _) in _store.pending()) {
      final row = await _store.getAny(table, key);
      if (row != null && row['user_id'] == null) {
        row['user_id'] = uid;
        await _store.put(table, row);
      }
    }
  }

  // ------------------------------------------------------------------
  // Tirer
  // ------------------------------------------------------------------

  Future<void> _pull(String table, SyncChanges changes) async {
    final client = _client!;
    final idCol = Tables.idColumn(table);
    final cursorKey = 'cursor:$table';
    String? ts = _store.meta<String>('$cursorKey:ts');
    String? lastId = _store.meta<String>('$cursorKey:id');
    if (ts != null) {
      // Chevauchement de 2 s: une transaction longue peut valider une ligne
      // horodatée juste avant le curseur. La fusion est idempotente.
      ts = DateTime.parse(ts)
          .subtract(const Duration(seconds: 2))
          .toUtc()
          .toIso8601String();
      lastId = null;
    }
    while (true) {
      var q = client.from(table).select();
      if (ts != null) {
        q = lastId == null
            ? q.gte('server_updated_at', ts)
            : q.or('server_updated_at.gt."$ts",'
                'and(server_updated_at.eq."$ts",$idCol.gt."$lastId")');
      }
      final rows = await q
          .order('server_updated_at', ascending: true)
          .order(idCol, ascending: true)
          .limit(_pageSize);
      for (final r in rows) {
        if (await mergeRemote(table, r)) {
          changes.tables.add(table);
          final page = r['page_id'] ?? (table == Tables.pages ? r['id'] : null);
          if (page != null) changes.pageIds.add(page as String);
        }
      }
      if (rows.isEmpty) break;
      ts = rows.last['server_updated_at'] as String;
      lastId = '${rows.last[idCol]}';
      await _store.setMeta('$cursorKey:ts', ts);
      await _store.setMeta('$cursorKey:id', lastId);
      if (rows.length < _pageSize) break;
    }
  }

  /// Fusionne une ligne distante. Retourne vrai si la copie locale a changé.
  @visibleForTesting
  Future<bool> mergeRemote(String table, Map<String, dynamic> remote) async {
    final key = LocalStore.keyFor(table, remote);
    final local = await _store.getAny(table, key);
    if (local == null) {
      await _store.put(table, remote, dirty: false);
      return true;
    }
    final dirty = _store.isDirty(table, key);
    final remoteTime = parseTime(remote['modified_at']);
    final localTime = parseTime(local['modified_at']);
    final remoteDeleted = remote['deleted'] == true;
    final localDeleted = local['deleted'] == true;

    if (!dirty) {
      if (remoteTime.isBefore(localTime) && !remoteDeleted) return false;
      if (_sameContent(local, remote)) return false;
      await _store.put(table, remote, dirty: false);
      return true;
    }
    // La copie locale a des changements non envoyés.
    if (!remoteTime.isBefore(localTime)) {
      // Le distant est plus récent: il gagne, sauf une suppression locale.
      final merged = {...remote, 'deleted': remoteDeleted || localDeleted};
      await _store.put(table, merged, dirty: localDeleted && !remoteDeleted);
      if (!(localDeleted && !remoteDeleted)) {
        await _store.markClean(table, key, local['modified_at']);
      }
      return true;
    }
    if (remoteDeleted && !localDeleted) {
      // Une suppression distante gagne toujours.
      await _store.put(table, {...local, 'deleted': true});
      return true;
    }
    return false;
  }

  static bool _sameContent(Map a, Map b) =>
      a['modified_at'] == b['modified_at'] && a['deleted'] == b['deleted'];

  /// Retire de l'appareil les cahiers dont le partage a été révoqué.
  Future<void> _evictRevokedNotebooks(SyncChanges changes) async {
    final uid = _uid!;
    final foreign = _store
        .rows(Tables.notebooks)
        .where((r) => r['user_id'] != null && r['user_id'] != uid)
        .map((r) => r['id'] as String)
        .toSet();
    if (foreign.isEmpty) return;
    final visible = <String>{};
    for (final chunk in _chunks(foreign.toList(), 100)) {
      final rows =
          await _client!.from(Tables.notebooks).select('id').inFilter('id', chunk);
      visible.addAll(rows.map((r) => r['id'] as String));
    }
    final revoked = foreign.difference(visible);
    if (revoked.isEmpty) return;
    final pages = _store
        .rows(Tables.pages)
        .where((p) => revoked.contains(p['notebook_id']))
        .map((p) => p['id'] as String)
        .toList();
    for (final t in Tables.elementTables) {
      final keys = [for (final p in pages) ..._store.pageKeys(t, p)];
      await _store.evict(t, keys);
    }
    await _store.evict(Tables.pages, pages);
    await _store.evict(
        Tables.assets,
        _store
            .rows(Tables.assets)
            .where((a) => revoked.contains(a['notebook_id']))
            .map((a) => a['id'] as String));
    await _store.evict(Tables.notebooks, revoked);
    changes.tables.addAll([Tables.notebooks, Tables.pages]);
  }

  // ------------------------------------------------------------------
  // Pousser
  // ------------------------------------------------------------------

  Future<void> _push() async {
    final uid = _uid!;
    final pending = _store.pending();
    if (pending.isEmpty) return;
    final byTable = <String, List<(String, Object?)>>{};
    for (final (t, k, m) in pending) {
      (byTable[t] ??= []).add((k, m));
    }
    for (final table in Tables.ordered) {
      final entries = byTable[table];
      if (entries == null) continue;
      final upserts = <(String, Object?, Map<String, dynamic>)>[];
      for (final (key, sentAt) in entries) {
        final row = await _store.getAny(table, key);
        if (row == null) {
          await _store.markClean(table, key, sentAt);
          continue;
        }
        row.remove('server_updated_at');
        if (table == Tables.userSettings) row['user_id'] = uid;
        if (table == Tables.assets && row['storage_path'] == null) {
          final path = await _uploadAsset(row, uid);
          if (path == null) continue; // fichier pas encore disponible
          row['storage_path'] = path;
          await _store.put(table, row, dirty: false);
        }
        if (table == Tables.notebooks && row['user_id'] != uid) {
          // Cahier partagé avec moi: mise à jour seulement.
          row.remove('user_id');
          await _client!.from(table).update(row).eq('id', row['id'] as Object);
          await _store.markClean(table, key, sentAt);
          continue;
        }
        upserts.add((key, sentAt, row));
      }
      for (final chunk in _chunks(upserts, _pushChunk)) {
        await _client!.from(table).upsert(
              [for (final (_, _, r) in chunk) r],
              onConflict: Tables.idColumn(table),
            );
        for (final (key, sentAt, _) in chunk) {
          await _store.markClean(table, key, sentAt);
        }
      }
    }
  }

  Future<String?> _uploadAsset(Map<String, dynamic> row, String uid) async {
    final bytes = await _store.assetBytes(row['id'] as String);
    if (bytes == null) return null;
    final isPdf = row['kind'] == 'pdf';
    final ext = isPdf ? 'pdf' : _imageExt(row['file_name'] as String? ?? '');
    final path = '$uid/${row['notebook_id']}/${row['id']}.$ext';
    await _client!.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: isPdf ? 'application/pdf' : 'image/$ext',
          ),
        );
    return path;
  }

  static String _imageExt(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'jpg') return 'jpeg';
    return const {'png', 'jpeg', 'webp', 'gif', 'heic'}.contains(ext)
        ? ext
        : 'png';
  }

  /// Télécharge le fichier original d'un document importé.
  Future<Uint8List?> downloadAsset(String storagePath) async {
    if (!enabled) return null;
    return _client!.storage.from(bucket).download(storagePath);
  }

  // ------------------------------------------------------------------
  // Temps réel (cahiers partagés)
  // ------------------------------------------------------------------

  /// Écoute les changements d'un cahier ouvert, pour voir en direct les
  /// traits d'un camarade, dans ses propres couleurs.
  void watchNotebook(String? notebookId) {
    final client = _client;
    if (client == null) return;
    if (_channel != null) {
      client.removeChannel(_channel!);
      _channel = null;
    }
    if (notebookId == null || !enabled) return;
    var channel = client.channel('notebook:$notebookId');
    for (final t in const [
      Tables.pages,
      Tables.strokes,
      Tables.highlights,
      Tables.textBlocks,
    ]) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'notebook_id',
          value: notebookId,
        ),
        callback: (payload) async {
          final row = payload.newRecord;
          if (row.isEmpty) return;
          if (await mergeRemote(t, row)) {
            final c = SyncChanges()..tables.add(t);
            final page = row['page_id'] ?? (t == Tables.pages ? row['id'] : null);
            if (page != null) c.pageIds.add(page as String);
            _changes.add(c);
          }
        },
      );
    }
    _channel = channel..subscribe();
  }

  // ------------------------------------------------------------------
  // Compte
  // ------------------------------------------------------------------

  /// Supprime les fichiers de l'utilisateur dans le stockage puis le compte
  /// (cascade sur toutes ses données).
  Future<void> deleteAccount() async {
    final client = _client!;
    final uid = _uid!;
    final storage = client.storage.from(bucket);
    final notebooks = await storage.list(path: uid);
    for (final nb in notebooks) {
      final files = await storage.list(path: '$uid/${nb.name}');
      if (files.isNotEmpty) {
        await storage.remove([for (final f in files) '$uid/${nb.name}/${f.name}']);
      }
    }
    await client.rpc<void>('delete_my_account');
  }

  /// Remet les curseurs à zéro (nouveau compte sur l'appareil).
  Future<void> resetCursors() async {
    for (final t in Tables.ordered) {
      await _store.setMeta('cursor:$t:ts', null);
      await _store.setMeta('cursor:$t:id', null);
    }
  }

  @override
  void dispose() {
    _changes.close();
    super.dispose();
  }
}

Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
  for (var i = 0; i < list.length; i += size) {
    yield list.sublist(i, i + size > list.length ? list.length : i + size);
  }
}
