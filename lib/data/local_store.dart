import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Tables synchronisées, dans l'ordre d'envoi (parents avant enfants).
class Tables {
  Tables._();
  static const userSettings = 'user_settings';
  static const profiles = 'visual_profiles';
  static const folders = 'folders';
  static const notebooks = 'notebooks';
  static const assets = 'imported_assets';
  static const pages = 'pages';
  static const strokes = 'strokes';
  static const highlights = 'highlights';
  static const textBlocks = 'text_blocks';

  static const ordered = [
    userSettings,
    profiles,
    folders,
    notebooks,
    assets,
    pages,
    strokes,
    highlights,
    textBlocks,
  ];

  /// Tables d'éléments de page, potentiellement très volumineuses: chargées
  /// page par page (boîtes paresseuses).
  static const elementTables = {strokes, highlights, textBlocks};

  static String idColumn(String table) =>
      table == userSettings ? 'user_id' : 'id';
}

/// Stockage local (sauvegarde locale, section 3). Hors ligne d'abord:
/// toute modification est écrite ici immédiatement, puis envoyée à Supabase.
///
/// Les données sont chiffrées au repos sur iOS/Android (clé AES dans le
/// trousseau / Keystore).
class LocalStore {
  static const _settingsKey = 'me';
  final Map<String, Box<dynamic>> _small = {};
  final Map<String, LazyBox<dynamic>> _lazy = {};
  late Box<dynamic> _outbox;
  late Box<dynamic> _meta;
  late LazyBox<dynamic> _assetBytes;

  /// Index pageId -> clés, construit à partir des clés en mémoire.
  final Map<String, Map<String, Set<String>>> _pageIndex = {};

  Future<void> open({bool inMemory = false}) async {
    HiveCipher? cipher;
    if (!inMemory) {
      await Hive.initFlutter('monako');
      cipher = await _cipher();
    }
    Future<Box<dynamic>> box(String name) => Hive.openBox<dynamic>(name,
        encryptionCipher: cipher, bytes: inMemory ? Uint8List(0) : null);
    for (final t in Tables.ordered) {
      if (Tables.elementTables.contains(t)) {
        _lazy[t] = inMemory
            ? _MemoryLazyBox(await box('${t}_mem'))
            : await Hive.openLazyBox<dynamic>(t, encryptionCipher: cipher);
      } else {
        _small[t] = await box(t);
      }
    }
    _outbox = await box('outbox');
    _meta = await box('meta');
    _assetBytes = inMemory
        ? _MemoryLazyBox(await box('asset_bytes_mem'))
        : await Hive.openLazyBox<dynamic>('asset_bytes',
            encryptionCipher: cipher);
    for (final t in Tables.elementTables) {
      final idx = _pageIndex[t] = {};
      for (final k in _lazy[t]!.keys) {
        final key = k as String;
        final page = key.substring(0, key.indexOf('|'));
        (idx[page] ??= {}).add(key);
      }
    }
  }

  static Future<HiveCipher?> _cipher() async {
    if (kIsWeb) return null;
    try {
      const storage = FlutterSecureStorage();
      var keyB64 = await storage.read(key: 'monako_hive_key');
      if (keyB64 == null) {
        keyB64 = base64Encode(Hive.generateSecureKey());
        await storage.write(key: 'monako_hive_key', value: keyB64);
      }
      return HiveAesCipher(base64Decode(keyB64));
    } catch (e) {
      debugPrint('Chiffrement local indisponible: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Clés
  // ------------------------------------------------------------------

  static String keyFor(String table, Map row) {
    if (Tables.elementTables.contains(table)) {
      return '${row['page_id']}|${row['id']}';
    }
    if (table == Tables.userSettings) return _settingsKey;
    return row['id'] as String;
  }

  static Map<String, dynamic> _copy(dynamic v) =>
      (v as Map).map((k, val) => MapEntry(k as String, val));

  // ------------------------------------------------------------------
  // Lecture
  // ------------------------------------------------------------------

  Iterable<Map<String, dynamic>> rows(String table) =>
      _small[table]!.values.map(_copy);

  Map<String, dynamic>? get(String table, String key) {
    final v = _small[table]!.get(key);
    return v == null ? null : _copy(v);
  }

  Map<String, dynamic>? get settingsRow => get(Tables.userSettings, _settingsKey);

  Future<Map<String, dynamic>?> getElement(String table, String key) async {
    final v = await _lazy[table]!.get(key);
    return v == null ? null : _copy(v);
  }

  Future<Map<String, dynamic>?> getAny(String table, String key) =>
      Tables.elementTables.contains(table)
          ? getElement(table, key)
          : Future.value(get(table, key));

  Future<List<Map<String, dynamic>>> pageRows(String table, String pageId) async {
    final keys = _pageIndex[table]![pageId];
    if (keys == null) return const [];
    final box = _lazy[table]!;
    final out = <Map<String, dynamic>>[];
    for (final k in keys) {
      final v = await box.get(k);
      if (v != null) out.add(_copy(v));
    }
    return out;
  }

  /// Toutes les lignes d'une table d'éléments (export, recherche).
  Future<List<Map<String, dynamic>>> allElementRows(String table) async {
    final box = _lazy[table]!;
    final out = <Map<String, dynamic>>[];
    for (final k in box.keys) {
      final v = await box.get(k);
      if (v != null) out.add(_copy(v));
    }
    return out;
  }

  // ------------------------------------------------------------------
  // Écriture
  // ------------------------------------------------------------------

  /// Écrit une ligne. [dirty] = à envoyer au serveur.
  Future<void> put(String table, Map<String, dynamic> row,
      {bool dirty = true}) async {
    final key = keyFor(table, row);
    if (Tables.elementTables.contains(table)) {
      await _lazy[table]!.put(key, row);
      (_pageIndex[table]![row['page_id'] as String] ??= {}).add(key);
    } else {
      await _small[table]!.put(key, row);
    }
    if (dirty) {
      await _outbox.put('$table|$key', row['modified_at']);
    }
  }

  Future<void> putAll(String table, List<Map<String, dynamic>> rows,
      {bool dirty = true}) async {
    if (rows.isEmpty) return;
    final entries = {for (final r in rows) keyFor(table, r): r};
    if (Tables.elementTables.contains(table)) {
      await _lazy[table]!.putAll(entries);
      final idx = _pageIndex[table]!;
      for (final r in rows) {
        (idx[r['page_id'] as String] ??= {}).add(keyFor(table, r));
      }
    } else {
      await _small[table]!.putAll(entries);
    }
    if (dirty) {
      await _outbox.putAll({
        for (final e in entries.entries) '$table|${e.key}': e.value['modified_at'],
      });
    }
  }

  /// Retire définitivement des lignes locales (cahier dont le partage a été
  /// révoqué). Ne touche jamais le serveur.
  Future<void> evict(String table, Iterable<String> keys) async {
    final list = keys.toList();
    if (Tables.elementTables.contains(table)) {
      await _lazy[table]!.deleteAll(list);
      for (final k in list) {
        _pageIndex[table]![k.substring(0, k.indexOf('|'))]?.remove(k);
      }
    } else {
      await _small[table]!.deleteAll(list);
    }
    await _outbox.deleteAll(list.map((k) => '$table|$k'));
  }

  Set<String> pageKeys(String table, String pageId) =>
      _pageIndex[table]![pageId] ?? const {};

  // ------------------------------------------------------------------
  // File d'envoi
  // ------------------------------------------------------------------

  /// Entrées en attente: (table, clé, modified_at au moment de l'écriture).
  List<(String, String, Object?)> pending() => [
        for (final k in _outbox.keys)
          (
            (k as String).substring(0, k.indexOf('|')),
            k.substring(k.indexOf('|') + 1),
            _outbox.get(k),
          ),
      ];

  bool isDirty(String table, String key) => _outbox.containsKey('$table|$key');

  int get pendingCount => _outbox.length;

  /// Marque comme envoyée, seulement si la ligne n'a pas été modifiée
  /// pendant l'envoi.
  Future<void> markClean(String table, String key, Object? sentModifiedAt) async {
    final k = '$table|$key';
    if (_outbox.get(k) == sentModifiedAt) await _outbox.delete(k);
  }

  // ------------------------------------------------------------------
  // Fichiers importés (originaux, jamais modifiés)
  // ------------------------------------------------------------------

  Future<void> putAssetBytes(String assetId, Uint8List bytes) =>
      _assetBytes.put(assetId, bytes);

  Future<Uint8List?> assetBytes(String assetId) async {
    final v = await _assetBytes.get(assetId);
    if (v is Uint8List) return v;
    if (v is List) return Uint8List.fromList(v.cast<int>());
    return null;
  }

  // ------------------------------------------------------------------
  // Méta (curseurs de synchronisation, propriétaire des données locales)
  // ------------------------------------------------------------------

  T? meta<T>(String key) => _meta.get(key) as T?;
  Future<void> setMeta(String key, Object? value) =>
      value == null ? _meta.delete(key) : _meta.put(key, value);

  /// Efface toutes les données locales (déconnexion, suppression de compte).
  Future<void> clearAll() async {
    for (final b in _small.values) {
      await b.clear();
    }
    for (final b in _lazy.values) {
      await b.clear();
    }
    for (final idx in _pageIndex.values) {
      idx.clear();
    }
    await _outbox.clear();
    await _meta.clear();
    await _assetBytes.clear();
  }
}

/// Boîte « paresseuse » en mémoire, pour les tests.
class _MemoryLazyBox implements LazyBox<dynamic> {
  _MemoryLazyBox(this._box);
  final Box<dynamic> _box;

  @override
  Future<dynamic> get(dynamic key, {dynamic defaultValue}) async =>
      _box.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) => _box.put(key, value);
  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) => _box.putAll(entries);
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) => _box.deleteAll(keys);
  @override
  Future<int> clear() => _box.clear();
  @override
  Iterable<dynamic> get keys => _box.keys;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
