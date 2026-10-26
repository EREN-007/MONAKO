import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/profiles/presets.dart';
import '../core/profiles/profile_tools.dart';
import '../core/profiles/visual_profile.dart';
import 'local_store.dart';
import 'models.dart';
import 'sync_service.dart';
import 'user_settings.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Contenu d'une page chargé en mémoire.
class PageContent {
  PageContent(this.page, this.strokes, this.highlights, this.texts);
  final NotePage page;
  final List<InkStroke> strokes;
  final List<InkStroke> highlights;
  final List<TextBlock> texts;
}

/// Résultat de recherche (titres, texte tapé, OCR).
class SearchHit {
  SearchHit(this.notebook, {this.page, this.snippet});
  final Notebook notebook;
  final NotePage? page;
  final String? snippet;
}

/// Point d'accès unique aux données: écrit localement tout de suite,
/// puis synchronise avec Supabase (sauvegarde automatique toutes les 5 s et
/// à chaque changement de page).
class NotesRepository extends ChangeNotifier {
  NotesRepository(this.store, this.sync) {
    _sub = sync.changes.listen(_onRemote);
    _reload();
  }

  final LocalStore store;
  final SyncService sync;
  late final StreamSubscription<SyncChanges> _sub;
  Timer? _autosave;

  static const autosaveDelay = Duration(seconds: 5);

  final Map<String, Folder> _folders = {};
  final Map<String, Notebook> _notebooks = {};
  final Map<String, NotePage> _pages = {};
  final Map<String, ImportedAsset> _assets = {};
  final Map<String, VisualProfile> _profiles = {};
  UserSettings _settings = const UserSettings();

  final _pageChanges = StreamController<Set<String>>.broadcast();

  /// Pages modifiées par la synchronisation (pour rafraîchir l'éditeur).
  Stream<Set<String>> get pageChanges => _pageChanges.stream;

  // ------------------------------------------------------------------
  // Chargement
  // ------------------------------------------------------------------

  void _reload() {
    _folders
      ..clear()
      ..addEntries(store
          .rows(Tables.folders)
          .map(Folder.fromRow)
          .where((f) => !f.deleted)
          .map((f) => MapEntry(f.id, f)));
    _notebooks
      ..clear()
      ..addEntries(store
          .rows(Tables.notebooks)
          .map(Notebook.fromRow)
          .where((n) => !n.deleted)
          .map((n) => MapEntry(n.id, n)));
    _pages
      ..clear()
      ..addEntries(store
          .rows(Tables.pages)
          .map(NotePage.fromRow)
          .where((p) => !p.deleted)
          .map((p) => MapEntry(p.id, p)));
    _assets
      ..clear()
      ..addEntries(store
          .rows(Tables.assets)
          .map(ImportedAsset.fromRow)
          .map((a) => MapEntry(a.id, a)));
    _profiles.clear();
    for (final r in store.rows(Tables.profiles)) {
      final p = profileFromRow(r);
      if (!p.deleted) _profiles[p.id] = p;
    }
    final s = store.settingsRow;
    _settings = s == null ? const UserSettings() : UserSettings.fromRow(s);
  }

  void _onRemote(SyncChanges c) {
    _reload();
    notifyListeners();
    if (c.pageIds.isNotEmpty) _pageChanges.add(c.pageIds);
  }

  /// Recharge tout après une connexion / un effacement local.
  void reloadAll() {
    _reload();
    notifyListeners();
  }

  void scheduleSync({bool now = false}) {
    if (!sync.enabled) return;
    _autosave?.cancel();
    if (now) {
      sync.sync();
    } else {
      _autosave = Timer(autosaveDelay, sync.sync);
    }
  }

  // ------------------------------------------------------------------
  // Réglages et profils
  // ------------------------------------------------------------------

  UserSettings get settings => _settings;

  Future<void> updateSettings(UserSettings s) async {
    _settings = s;
    await store.put(Tables.userSettings, s.toRow());
    notifyListeners();
    scheduleSync();
  }

  /// Profils enregistrés par l'utilisateur (hors prédéfinis).
  List<VisualProfile> get customProfiles =>
      _profiles.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  List<VisualProfile> get allProfiles => [...Presets.all, ...customProfiles];

  VisualProfile? profileById(String? id) =>
      id == null ? null : (Presets.byId(id) ?? _profiles[id]);

  static VisualProfile profileFromRow(Map r) {
    final base = baseProfileFor(r['base_id'] as String?);
    return VisualProfile.fromJson(
      {
        'id': r['id'],
        'name': r['name'],
        'needs': r['needs'],
        'roles': r['roles'],
        'filters': r['filters'],
        'text': r['text'],
        'stroke': r['stroke'],
        'simplifiedUi': r['simplified_ui'],
        'baseId': r['base_id'],
      },
      base: base,
      modifiedAt: parseTime(r['modified_at']),
      deleted: r['deleted'] == true,
    );
  }

  Map<String, dynamic> profileToRow(VisualProfile p) {
    final j = p.toJson();
    final existing = store.get(Tables.profiles, p.id);
    return {
      'id': p.id,
      'user_id': existing?['user_id'] ?? sync.currentUserId,
      'name': j['name'],
      'needs': j['needs'],
      'roles': j['roles'],
      'filters': j['filters'],
      'text': j['text'],
      'stroke': j['stroke'],
      'simplified_ui': p.simplifiedUi,
      'base_id': p.baseId,
      'modified_at': timeToJson(p.modifiedAt),
      'deleted': p.deleted,
    };
  }

  Future<VisualProfile> saveProfile(VisualProfile p) async {
    final saved = p.isPreset
        ? p.copyWith(id: 'prof_${newId()}', isPreset: false, baseId: p.id)
        : p.copyWith();
    _profiles[saved.id] = saved;
    await store.put(Tables.profiles, profileToRow(saved));
    notifyListeners();
    scheduleSync();
    return saved;
  }

  Future<void> deleteProfile(String id) async {
    final p = _profiles.remove(id);
    if (p == null) return;
    await store.put(Tables.profiles, profileToRow(p.copyWith(deleted: true)));
    if (_settings.activeProfileId == id) {
      await updateSettings(
          _settings.copyWith(activeProfileId: _settings.rescueProfileId));
    }
    notifyListeners();
    scheduleSync();
  }

  // ------------------------------------------------------------------
  // Dossiers et cahiers
  // ------------------------------------------------------------------

  List<Folder> get folders =>
      _folders.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  List<Notebook> notebooksIn(String? folderId) => _notebooks.values
      .where((n) => folderId == null || n.folderId == folderId)
      .toList()
    ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

  List<Notebook> get allNotebooks => notebooksIn(null);

  Notebook? notebook(String id) => _notebooks[id];

  bool isShared(Notebook n) =>
      n.userId != null && sync.currentUserId != null && n.userId != sync.currentUserId;

  Future<Folder> createFolder(String name) async {
    final f = Folder(id: newId(), name: name, userId: sync.currentUserId);
    _folders[f.id] = f;
    await store.put(Tables.folders, f.toRow());
    notifyListeners();
    scheduleSync();
    return f;
  }

  Future<void> renameFolder(Folder f, String name) async {
    final u = f.copyWith(name: name);
    _folders[f.id] = u;
    await store.put(Tables.folders, u.toRow());
    notifyListeners();
    scheduleSync();
  }

  Future<void> deleteFolder(Folder f) async {
    _folders.remove(f.id);
    await store.put(Tables.folders, f.copyWith(deleted: true).toRow());
    for (final n in notebooksIn(f.id)) {
      await _saveNotebook(n.copyWith(clearFolder: true));
    }
    notifyListeners();
    scheduleSync();
  }

  Future<void> _saveNotebook(Notebook n) async {
    if (n.deleted) {
      _notebooks.remove(n.id);
    } else {
      _notebooks[n.id] = n;
    }
    await store.put(Tables.notebooks, n.toRow());
  }

  Future<Notebook> createNotebook(String title,
      {String? folderId, PageTemplate template = PageTemplate.lined}) async {
    final n = Notebook(
      id: newId(),
      title: title,
      folderId: folderId,
      userId: sync.currentUserId,
    );
    await _saveNotebook(n);
    await addPage(n.id, template: template);
    notifyListeners();
    scheduleSync();
    return n;
  }

  Future<void> updateNotebook(Notebook n) async {
    await _saveNotebook(n);
    notifyListeners();
    scheduleSync();
  }

  Future<void> deleteNotebook(Notebook n) =>
      updateNotebook(n.copyWith(deleted: true));

  /// Touche la date de modification (tri « récents »).
  Future<void> touchNotebook(String id) async {
    final n = _notebooks[id];
    if (n != null) await _saveNotebook(n.copyWith());
  }

  // ------------------------------------------------------------------
  // Pages
  // ------------------------------------------------------------------

  List<NotePage> pagesOf(String notebookId) => _pages.values
      .where((p) => p.notebookId == notebookId)
      .toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  NotePage? page(String id) => _pages[id];

  Future<NotePage> addPage(String notebookId,
      {PageTemplate template = PageTemplate.lined, NotePage? after}) async {
    final pages = pagesOf(notebookId);
    double pos;
    if (after == null || pages.isEmpty) {
      pos = pages.isEmpty ? 1 : pages.last.position + 1;
    } else {
      final i = pages.indexWhere((p) => p.id == after.id);
      pos = i == pages.length - 1
          ? after.position + 1
          : (after.position + pages[i + 1].position) / 2;
    }
    final p = NotePage(
      id: newId(),
      notebookId: notebookId,
      userId: sync.currentUserId,
      template: template,
      position: pos,
    );
    _pages[p.id] = p;
    await store.put(Tables.pages, p.toRow());
    notifyListeners();
    scheduleSync();
    return p;
  }

  Future<void> updatePage(NotePage p) async {
    if (p.deleted) {
      _pages.remove(p.id);
    } else {
      _pages[p.id] = p;
    }
    await store.put(Tables.pages, p.toRow());
    notifyListeners();
    scheduleSync();
  }

  Future<PageContent> loadPage(NotePage page) async {
    final strokes = (await store.pageRows(Tables.strokes, page.id))
        .map((r) => InkStroke.fromRow(r, highlight: false))
        .where((s) => !s.deleted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final highlights = (await store.pageRows(Tables.highlights, page.id))
        .map((r) => InkStroke.fromRow(r, highlight: true))
        .where((s) => !s.deleted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final texts = (await store.pageRows(Tables.textBlocks, page.id))
        .map(TextBlock.fromRow)
        .where((t) => !t.deleted)
        .toList();
    return PageContent(page, strokes, highlights, texts);
  }

  /// Enregistre des éléments (ajout, modification ou pierre tombale).
  Future<void> saveElements(Iterable<PageElement> elements) async {
    final byTable = <String, List<Map<String, dynamic>>>{};
    final uid = sync.currentUserId;
    for (final e in elements) {
      final table = switch (e) {
        InkStroke s => s.table,
        TextBlock _ => Tables.textBlocks,
      };
      final row = e.toRow();
      row['user_id'] ??= uid;
      (byTable[table] ??= []).add(row);
    }
    for (final e in byTable.entries) {
      await store.putAll(e.key, e.value);
    }
    scheduleSync();
  }

  // ------------------------------------------------------------------
  // Import PDF / images (l'original n'est jamais modifié)
  // ------------------------------------------------------------------

  ImportedAsset? asset(String? id) => id == null ? null : _assets[id];

  Future<void> updateAsset(ImportedAsset a) async {
    _assets[a.id] = a;
    await store.put(Tables.assets, a.toRow());
    notifyListeners();
    scheduleSync();
  }

  /// Crée un document importé et ses pages. [pageSizes] = taille de chaque
  /// page en points PDF (ou pixels pour une image).
  Future<Notebook> importDocument({
    required Uint8List bytes,
    required String fileName,
    required AssetKind kind,
    required List<Size2> pageSizes,
    Notebook? into,
    String? folderId,
  }) async {
    final nb = into ??
        Notebook(
          id: newId(),
          title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
          folderId: folderId,
          userId: sync.currentUserId,
        );
    if (into == null) await _saveNotebook(nb);
    final a = ImportedAsset(
      id: newId(),
      notebookId: nb.id,
      userId: sync.currentUserId,
      kind: kind,
      fileName: fileName,
      pageCount: pageSizes.length,
    );
    await store.putAssetBytes(a.id, bytes);
    _assets[a.id] = a;
    await store.put(Tables.assets, a.toRow());
    var pos = pagesOf(nb.id).fold<double>(0, (m, p) => p.position > m ? p.position : m);
    for (var i = 0; i < pageSizes.length; i++) {
      final s = pageSizes[i];
      const w = 800.0;
      final h = s.width <= 0 ? kDefaultPageSize.height : w * s.height / s.width;
      final p = NotePage(
        id: newId(),
        notebookId: nb.id,
        userId: sync.currentUserId,
        template: PageTemplate.blank,
        position: ++pos,
        width: w,
        height: h,
        assetId: a.id,
        assetPage: i + 1,
      );
      _pages[p.id] = p;
      await store.put(Tables.pages, p.toRow());
    }
    notifyListeners();
    scheduleSync();
    return nb;
  }

  final Map<String, Future<Uint8List?>> _downloads = {};

  /// Octets du fichier original (cache local, sinon téléchargement).
  Future<Uint8List?> assetBytes(ImportedAsset a) async {
    final local = await store.assetBytes(a.id);
    if (local != null) return local;
    final path = a.storagePath;
    if (path == null) return null;
    return _downloads[a.id] ??= () async {
      try {
        final bytes = await sync.downloadAsset(path);
        if (bytes != null) await store.putAssetBytes(a.id, bytes);
        return bytes;
      } finally {
        _downloads.remove(a.id);
      }
    }();
  }

  // ------------------------------------------------------------------
  // Recherche: titres (MVP), texte tapé et texte OCR (version 2)
  // ------------------------------------------------------------------

  Future<List<SearchHit>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <SearchHit>[];
    for (final n in allNotebooks) {
      if (n.title.toLowerCase().contains(q)) hits.add(SearchHit(n));
    }
    final texts = await store.allElementRows(Tables.textBlocks);
    for (final r in texts) {
      if (r['deleted'] == true) continue;
      final text = (r['text'] as String?) ?? '';
      final i = text.toLowerCase().indexOf(q);
      if (i < 0) continue;
      final n = _notebooks[r['notebook_id']];
      final p = _pages[r['page_id']];
      if (n == null || p == null) continue;
      hits.add(SearchHit(n, page: p, snippet: _snippet(text, i, q.length)));
    }
    for (final p in _pages.values) {
      final text = p.ocrText;
      if (text == null) continue;
      final i = text.toLowerCase().indexOf(q);
      final n = _notebooks[p.notebookId];
      if (i >= 0 && n != null) {
        hits.add(SearchHit(n, page: p, snippet: _snippet(text, i, q.length)));
      }
    }
    return hits;
  }

  static String _snippet(String text, int i, int len) {
    final start = (i - 30).clamp(0, text.length);
    final end = (i + len + 30).clamp(0, text.length);
    return '${start > 0 ? '…' : ''}${text.substring(start, end).replaceAll('\n', ' ')}${end < text.length ? '…' : ''}';
  }

  // ------------------------------------------------------------------
  // Export des données (droit d'accès / portabilité)
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> exportAllData() async => {
        'format': 'monako-export',
        'schemaVersion': kSchemaVersion,
        'exportedAt': timeToJson(nowUtc()),
        'settings': _settings.toRow(),
        'profiles': [for (final p in customProfiles) p.toJson()],
        'folders': [for (final f in folders) f.toRow()],
        'notebooks': [for (final n in allNotebooks) n.toRow()],
        'pages': [for (final p in _pages.values) p.toRow()],
        'assets': [for (final a in _assets.values) a.toRow()],
        'strokes': [
          for (final r in await store.allElementRows(Tables.strokes))
            if (r['deleted'] != true) r,
        ],
        'highlights': [
          for (final r in await store.allElementRows(Tables.highlights))
            if (r['deleted'] != true) r,
        ],
        'textBlocks': [
          for (final r in await store.allElementRows(Tables.textBlocks))
            if (r['deleted'] != true) r,
        ],
      };

  @override
  void dispose() {
    _sub.cancel();
    _autosave?.cancel();
    _pageChanges.close();
    super.dispose();
  }
}

/// Taille simple (évite de dépendre de dart:ui dans les appels d'import).
class Size2 {
  const Size2(this.width, this.height);
  final double width;
  final double height;
}
