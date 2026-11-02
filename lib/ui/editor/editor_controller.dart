import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/ink/pressure.dart';
import '../../core/ink/shape_recognizer.dart';
import '../../core/render/stroke_geometry.dart';
import '../../core/roles.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/rescue_gesture.dart';

enum EditorTool { pen, highlighter, eraser, lasso, shapes, text, laser, hand }

enum EraserMode {
  /// Efface le trait entier touché.
  stroke,

  /// Efface seulement la partie touchée (le trait est coupé).
  precise,
}

/// Une action annulable: éléments ajoutés et éléments retirés.
/// Annuler une suppression recrée les éléments avec un nouvel identifiant:
/// une pierre tombale n'est jamais annulée (fusion sûre entre appareils).
class _EditAction {
  _EditAction({this.added = const [], this.removed = const []});
  List<PageElement> added;
  List<PageElement> removed;
}

/// État de l'éditeur pour un cahier entier: plusieurs pages chargées à la
/// fois (défilement continu), outils, sélection, annuler/rétablir.
/// Toutes les coordonnées sont celles de la page (0..largeur, 0..hauteur).
class EditorController extends ChangeNotifier {
  EditorController(this.repo, this.notebookId, {String? initialPageId}) {
    _currentPageId = initialPageId ?? (pages.isEmpty ? null : pages.first.id);
    _pageSub = repo.pageChanges.listen(_onRemotePages);
    _rescueSub = RescueGesture.events.listen(_onRescue);
    repo.addListener(_onRepo);
  }

  final NotesRepository repo;
  final String notebookId;
  late final StreamSubscription<Set<String>> _pageSub;
  late final StreamSubscription<DateTime> _rescueSub;

  final StrokeGeometryCache geometry = StrokeGeometryCache();

  /// Presse-papiers partagé entre cahiers.
  static List<PageElement> clipboard = [];

  // ------------------------------------------------------------------
  // Pages et contenu
  // ------------------------------------------------------------------

  final Map<String, PageContent> _contents = {};
  final Set<String> _loading = {};
  final Map<String, int> _versions = {};
  String? _currentPageId;

  List<NotePage> get pages => repo.pagesOf(notebookId);

  NotePage? get currentPage {
    final ps = pages;
    if (ps.isEmpty) return null;
    return ps.firstWhere((p) => p.id == _currentPageId, orElse: () => ps.first);
  }

  int get currentIndex {
    final i = pages.indexWhere((p) => p.id == currentPage?.id);
    return i < 0 ? 0 : i;
  }

  /// Notifié quand la page courante (la plus visible) change.
  final ValueNotifier<int> currentPageNotifier = ValueNotifier(0);

  void setCurrentPage(String pageId) {
    if (_currentPageId == pageId) return;
    _currentPageId = pageId;
    currentPageNotifier.value = currentIndex;
    // Sauvegarde à chaque changement de page.
    repo.scheduleSync(now: true);
  }

  PageContent? content(String pageId) => _contents[pageId];
  bool isLoaded(String pageId) => _contents.containsKey(pageId);
  int versionOf(String pageId) => _versions[pageId] ?? 0;

  void _bump(String pageId) => _versions[pageId] = versionOf(pageId) + 1;

  /// Charge les pages visibles et libère celles qui sont loin.
  void ensureLoaded(Iterable<String> pageIds, {Iterable<String> keep = const []}) {
    final wanted = {...pageIds, ...keep};
    for (final id in pageIds) {
      if (_contents.containsKey(id) || _loading.contains(id)) continue;
      final p = repo.page(id);
      if (p == null) continue;
      _loading.add(id);
      repo.loadPage(p).then((c) {
        _loading.remove(id);
        _contents[id] = c;
        _bump(id);
        notifyListeners();
      });
    }
    if (_contents.length > 12) {
      final drop = _contents.keys
          .where((id) =>
              !wanted.contains(id) && id != _selectionPage && id != _livePage)
          .toList();
      for (final id in drop.take(_contents.length - 12)) {
        _contents.remove(id);
      }
      geometry.retainOnly([
        for (final c in _contents.values) ...[
          ...c.strokes.map((s) => s.id),
          ...c.highlights.map((s) => s.id),
        ],
      ]);
    }
  }

  Future<void> ensureLoadedNow(String pageId) async {
    if (!_contents.containsKey(pageId)) await reload(pageId);
  }

  Future<void> reload(String pageId) async {
    final p = repo.page(pageId);
    if (p == null) return;
    final c = await repo.loadPage(p);
    _contents[pageId] = c;
    _bump(pageId);
    notifyListeners();
  }

  void _onRepo() {
    // Gabarit, signet, pages ajoutées par un autre appareil…
    for (final e in _contents.entries.toList()) {
      final p = repo.page(e.key);
      if (p == null) {
        _contents.remove(e.key);
      } else if (!identical(p, e.value.page)) {
        _contents[e.key] = e.value.withPage(p);
        _bump(e.key);
      }
    }
    notifyListeners();
  }

  void _onRemotePages(Set<String> ids) {
    for (final id in ids) {
      if (_contents.containsKey(id) && id != _livePage && !dragging) reload(id);
    }
  }

  // ------------------------------------------------------------------
  // Outils
  // ------------------------------------------------------------------

  EditorTool _tool = EditorTool.pen;
  EditorTool get tool => _tool;
  set tool(EditorTool t) {
    _tool = t;
    clearSelection();
    notifyListeners();
  }

  InkRole inkRole = InkRole.inkPrimary;
  InkRole highlightRole = InkRole.highlight1;
  PenType penType = PenType.fountain;
  double penWidth = 2.4;
  double highlighterWidth = 18;
  double eraserRadius = 10;
  EraserMode eraserMode = EraserMode.stroke;
  bool eraseHighlightsOnly = false;

  void update(void Function() change) {
    change();
    notifyListeners();
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  // ------------------------------------------------------------------
  // Trait en cours (stylet, surligneur, formes)
  // ------------------------------------------------------------------

  /// Points du trait en cours: x, y, pression.
  final List<double> live = [];
  final ValueNotifier<int> liveVersion = ValueNotifier(0);
  String? _livePage;
  int? _livePointer;
  final PressureFilter _pressure = PressureFilter();
  Timer? _holdTimer;
  RecognizedShape? liveShape;
  final List<(DateTime, InkStroke)> _recentTaps = [];

  String? get livePage => _livePage;
  bool get hasLiveStroke => _livePointer != null;
  bool get liveIsHighlight => _tool == EditorTool.highlighter;

  void strokeStart(String pageId, int pointer, Offset p, double? pressure) {
    _livePage = pageId;
    _livePointer = pointer;
    liveShape = null;
    _pressure.reset();
    live
      ..clear()
      ..addAll([p.dx, p.dy, _pressure.apply(pressure) ?? -1]);
    _armHold();
    liveVersion.value++;
  }

  void strokeExtend(int pointer, Offset p, double? pressure) {
    if (pointer != _livePointer) return;
    final n = live.length;
    if (n >= 3 &&
        (Offset(live[n - 3], live[n - 2]) - p).distanceSquared < 0.16) {
      return;
    }
    live.addAll([p.dx, p.dy, _pressure.apply(pressure) ?? -1]);
    if (liveShape != null && (p - liveShape!.points.last).distance > 12) {
      // Le stylet repart: on revient au tracé libre.
      liveShape = null;
    }
    _armHold();
    liveVersion.value++;
  }

  /// « Dessiner puis maintenir »: une pause de 600 ms à la fin d'un trait
  /// le transforme en forme régulière (ligne, rectangle, ellipse…).
  void _armHold() {
    _holdTimer?.cancel();
    if (_tool != EditorTool.pen) return;
    _holdTimer = Timer(const Duration(milliseconds: 600), () {
      if (_livePointer == null || live.length < 12 * 3) return;
      final shape = recognizeShape(_livePoints());
      if (shape != null) {
        liveShape = shape;
        liveVersion.value++;
      }
    });
  }

  List<Offset> _livePoints() => [
        for (var i = 0; i + 2 < live.length; i += 3) Offset(live[i], live[i + 1]),
      ];

  void strokeCancel() {
    _holdTimer?.cancel();
    _livePointer = null;
    _livePage = null;
    liveShape = null;
    live.clear();
    liveVersion.value++;
  }

  Future<void> strokeEnd(int pointer) async {
    if (pointer != _livePointer) return;
    _holdTimer?.cancel();
    final pageId = _livePage;
    _livePointer = null;
    if (pageId == null || live.isEmpty) return strokeCancel();
    final highlight = _tool == EditorTool.highlighter;
    var shape = liveShape;
    if (_tool == EditorTool.shapes) shape = recognizeShape(_livePoints());
    final Float32List points = shape == null
        ? Float32List.fromList(live)
        : Float32List.fromList([
            for (final p in shape.points) ...[p.dx, p.dy, 0.5],
          ]);
    final s = InkStroke(
      id: newId(),
      notebookId: notebookId,
      pageId: pageId,
      role: highlight ? highlightRole : inkRole,
      width: highlight ? highlighterWidth : penWidth,
      points: points,
      highlight: highlight,
      pen: highlight
          ? PenType.ball
          : (shape != null ? PenType.shape : penType),
    );
    live.clear();
    liveShape = null;
    _livePage = null;
    liveVersion.value++;
    if (s.pointCount <= 2) _recentTaps.add((DateTime.now(), s));
    await _apply(_EditAction(added: [s]));
  }

  /// Le geste de secours a été reconnu: les points laissés par les trois
  /// touchers sont retirés.
  Future<void> _onRescue(DateTime at) async {
    final since = at.subtract(const Duration(milliseconds: 1600));
    final dots = [
      for (final (t, s) in _recentTaps)
        if (t.isAfter(since)) s,
    ];
    _recentTaps.clear();
    if (dots.isEmpty) return;
    final ids = dots.map((d) => d.id).toSet();
    for (final d in dots) {
      final c = _contents[d.pageId];
      if (c == null) continue;
      c.strokes.removeWhere((s) => ids.contains(s.id));
      c.highlights.removeWhere((s) => ids.contains(s.id));
      _bump(d.pageId);
    }
    _undo.removeWhere((a) => a.added.any((e) => ids.contains(e.id)));
    notifyListeners();
    await repo.saveElements(dots.map((d) => d.markDeleted()));
  }

  // ------------------------------------------------------------------
  // Pointeur laser (jamais enregistré)
  // ------------------------------------------------------------------

  final Map<String, List<(Offset, int)>> laser = {};
  final ValueNotifier<int> laserVersion = ValueNotifier(0);
  Timer? _laserTimer;
  static const laserLife = 700;

  void laserAt(String pageId, Offset p) {
    (laser[pageId] ??= []).add((p, DateTime.now().millisecondsSinceEpoch));
    laserVersion.value++;
    _laserTimer ??= Timer.periodic(const Duration(milliseconds: 32), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final l in laser.values) {
        l.removeWhere((e) => now - e.$2 > laserLife);
      }
      laser.removeWhere((_, l) => l.isEmpty);
      laserVersion.value++;
      if (laser.isEmpty) {
        _laserTimer?.cancel();
        _laserTimer = null;
      }
    });
  }

  // ------------------------------------------------------------------
  // Gomme (trait entier ou précise)
  // ------------------------------------------------------------------

  final Map<String, PageElement> _erasedOriginals = {};
  final Map<String, InkStroke> _erasePieces = {};

  void eraseAt(String pageId, Offset p) {
    final c = _contents[pageId];
    if (c == null) return;
    final candidates = [
      if (!eraseHighlightsOnly) ...c.strokes,
      ...c.highlights,
    ];
    var changed = false;
    for (final s in candidates) {
      if (!_hits(s, p, eraserRadius)) continue;
      changed = true;
      _removeFromContent(c, s);
      if (_erasePieces.remove(s.id) == null) _erasedOriginals[s.id] = s;
      if (eraserMode == EraserMode.precise) {
        for (final piece in _split(s, p, eraserRadius)) {
          _erasePieces[piece.id] = piece;
          (piece.highlight ? c.highlights : c.strokes).add(piece);
        }
      }
    }
    if (changed) {
      _bump(pageId);
      notifyListeners();
    }
  }

  Future<void> eraseEnd() async {
    if (_erasedOriginals.isEmpty && _erasePieces.isEmpty) return;
    final action = _EditAction(
      added: _erasePieces.values.toList(),
      removed: _erasedOriginals.values.toList(),
    );
    _erasedOriginals.clear();
    _erasePieces.clear();
    _undo.add(action);
    _redo.clear();
    await repo.saveElements([
      ...action.added,
      for (final e in action.removed) e.markDeleted(),
    ]);
    notifyListeners();
  }

  /// Coupe un trait autour du point gommé: les morceaux restants
  /// deviennent de nouveaux traits (même rôle, même stylo).
  static List<InkStroke> _split(InkStroke s, Offset p, double r) {
    final reach = r + s.width / 2;
    final runs = <List<double>>[];
    var current = <double>[];
    for (var i = 0; i < s.pointCount; i++) {
      final q = s.pointAt(i);
      if ((q - p).distance <= reach) {
        if (current.length >= 6) runs.add(current);
        current = <double>[];
      } else {
        current.addAll([q.dx, q.dy, s.pressureAt(i)]);
      }
    }
    if (current.length >= 6) runs.add(current);
    return [
      for (final run in runs)
        s.copyWith(id: newId(), points: Float32List.fromList(run)),
    ];
  }

  static bool _hits(InkStroke s, Offset p, double r) {
    final reach = r + s.width / 2;
    if (!s.bounds.inflate(reach).contains(p)) return false;
    final n = s.pointCount;
    if (n == 1) return (s.pointAt(0) - p).distance <= reach;
    for (var i = 0; i < n - 1; i++) {
      if (_segmentDistance(p, s.pointAt(i), s.pointAt(i + 1)) <= reach) {
        return true;
      }
    }
    return false;
  }

  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.distanceSquared;
    if (len2 == 0) return (p - a).distance;
    final t =
        (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // ------------------------------------------------------------------
  // Lasso: sélection, déplacement, mise à l'échelle
  // ------------------------------------------------------------------

  String? _selectionPage;
  Set<String> selection = {};
  final List<Offset> lasso = [];
  Offset _dragDelta = Offset.zero;
  Offset? _dragStart;
  double _scale = 1;
  Offset? _scaleStart;

  String? get selectionPage => _selectionPage;
  bool get dragging => _dragStart != null || _scaleStart != null;
  Offset get dragDelta => _dragDelta;
  double get dragScale => _scale;
  bool get hasSelection => selection.isNotEmpty;

  /// Poignée de redimensionnement (coin bas-droit de la sélection).
  Rect? get scaleHandle {
    final b = selectionBounds;
    if (b == null) return null;
    return Rect.fromCenter(center: b.inflate(10).bottomRight, width: 36, height: 36);
  }

  void lassoStart(String pageId, Offset p) {
    if (_selectionPage == pageId && selection.isNotEmpty) {
      final handle = scaleHandle;
      if (handle != null && handle.inflate(8).contains(p)) {
        _scaleStart = p;
        _scale = 1;
        return;
      }
      if (selectionBounds!.inflate(14).contains(p)) {
        _dragStart = p;
        _dragDelta = Offset.zero;
        return;
      }
    }
    _selectionPage = pageId;
    selection = {};
    lasso
      ..clear()
      ..add(p);
    _bump(pageId);
    notifyListeners();
  }

  void lassoUpdate(Offset p) {
    final page = _selectionPage;
    if (page == null) return;
    if (_scaleStart != null) {
      final b = selectionBounds!;
      final start = b.bottomRight - b.topLeft;
      final now = p - b.topLeft;
      final f = math.max(now.dx / math.max(start.dx, 1), now.dy / math.max(start.dy, 1));
      _scale = f.clamp(0.2, 6.0);
    } else if (_dragStart != null) {
      _dragDelta = p - _dragStart!;
    } else {
      lasso.add(p);
    }
    _bump(page);
    notifyListeners();
  }

  Future<void> lassoEnd() async {
    final page = _selectionPage;
    if (page == null) return;
    if (_scaleStart != null) {
      final f = _scale;
      _scaleStart = null;
      _scale = 1;
      if ((f - 1).abs() > 0.01) await _transformSelection(scale: f);
      notifyListeners();
      return;
    }
    if (_dragStart != null) {
      final delta = _dragDelta;
      _dragStart = null;
      _dragDelta = Offset.zero;
      if (delta.distance > 0.5) await _transformSelection(offset: delta);
      notifyListeners();
      return;
    }
    final c = _contents[page];
    final poly = List<Offset>.of(lasso);
    lasso.clear();
    if (c == null || poly.length < 3) {
      selection = {};
    } else {
      selection = {
        for (final s in [...c.strokes, ...c.highlights])
          if (_strokeInside(s, poly)) s.id,
        for (final t in c.texts)
          if (_inside(t.bounds.center, poly)) t.id,
        for (final i in c.images)
          if (_inside(i.bounds.center, poly)) i.id,
      };
    }
    _bump(page);
    notifyListeners();
  }

  static bool _inside(Offset p, List<Offset> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _strokeInside(InkStroke s, List<Offset> poly) {
    var inside = 0;
    for (var i = 0; i < s.pointCount; i++) {
      if (_inside(s.pointAt(i), poly)) inside++;
    }
    return inside >= math.max(1, s.pointCount ~/ 2);
  }

  List<PageElement> get selectedElements {
    final c = _contents[_selectionPage];
    if (c == null) return const [];
    return [
      for (final e in c.elements)
        if (selection.contains(e.id)) e,
    ];
  }

  Rect? get selectionBounds {
    Rect? b;
    for (final e in selectedElements) {
      b = b == null ? e.bounds : b.expandToInclude(e.bounds);
    }
    return b;
  }

  void clearSelection() {
    final page = _selectionPage;
    selection = {};
    lasso.clear();
    _dragStart = null;
    _scaleStart = null;
    if (page != null) _bump(page);
  }

  Future<void> _transformSelection({Offset offset = Offset.zero, double scale = 1}) async {
    final before = selectedElements;
    final origin = selectionBounds?.topLeft ?? Offset.zero;
    Offset map(Offset p) => origin + (p - origin) * scale + offset;
    final after = [
      for (final e in before)
        switch (e) {
          InkStroke s => s.copyWith(
              width: s.width * (scale == 1 ? 1 : math.sqrt(scale)),
              points: Float32List.fromList([
                for (var i = 0; i < s.pointCount; i++) ...[
                  map(s.pointAt(i)).dx,
                  map(s.pointAt(i)).dy,
                  s.pressureAt(i),
                ],
              ]),
            ),
          TextBlock t => t.copyWith(
              x: map(Offset(t.x, t.y)).dx,
              y: map(Offset(t.x, t.y)).dy,
              width: t.width * scale,
              size: t.size * scale,
            ),
          PageImage i => i.copyWith(
              x: map(Offset(i.x, i.y)).dx,
              y: map(Offset(i.x, i.y)).dy,
              width: i.width * scale,
              height: i.height * scale,
            ),
        },
    ];
    await _apply(_EditAction(added: after, removed: before), replace: true);
  }

  Future<void> deleteSelection() async {
    final els = selectedElements;
    if (els.isEmpty) return;
    clearSelection();
    await _apply(_EditAction(removed: els));
  }

  void copySelection() => clipboard = selectedElements;

  Future<void> cutSelection() async {
    copySelection();
    await deleteSelection();
  }

  /// Colle le presse-papiers sur [pageId], décalé pour rester visible.
  Future<void> paste(String pageId) async {
    if (clipboard.isEmpty) return;
    final sameSpot = clipboard.first.pageId != pageId;
    final shift = sameSpot ? Offset.zero : const Offset(24, 24);
    final copies = [
      for (final e in clipboard) _cloneTo(e, pageId, shift),
    ];
    await _apply(_EditAction(added: copies));
    _selectionPage = pageId;
    selection = copies.map((e) => e.id).toSet();
    _tool = EditorTool.lasso;
    _bump(pageId);
    notifyListeners();
  }

  Future<void> duplicateSelection() async {
    final page = _selectionPage;
    if (page == null || selection.isEmpty) return;
    final copies = [
      for (final e in selectedElements) _cloneTo(e, page, const Offset(24, 24)),
    ];
    await _apply(_EditAction(added: copies));
    selection = copies.map((e) => e.id).toSet();
    _bump(page);
    notifyListeners();
  }

  PageElement _cloneTo(PageElement e, String pageId, Offset shift) => switch (e) {
        InkStroke s => s.copyWith(
            id: newId(),
            pageId: pageId,
            points: Float32List.fromList([
              for (var i = 0; i < s.pointCount; i++) ...[
                s.pointAt(i).dx + shift.dx,
                s.pointAt(i).dy + shift.dy,
                s.pressureAt(i),
              ],
            ]),
          ),
        TextBlock t => t.copyWith(
            id: newId(), pageId: pageId, x: t.x + shift.dx, y: t.y + shift.dy),
        PageImage i => i.copyWith(
            id: newId(), pageId: pageId, x: i.x + shift.dx, y: i.y + shift.dy),
      };

  /// Change le rôle des éléments sélectionnés (les surlignages gardent un
  /// rôle de surlignage).
  Future<void> setSelectionRole(InkRole role) async {
    final before = <PageElement>[];
    final after = <PageElement>[];
    for (final e in selectedElements) {
      if (e is InkStroke && e.highlight == role.isHighlight) {
        before.add(e);
        after.add(e.copyWith(role: role));
      } else if (e is TextBlock && !role.isHighlight) {
        before.add(e);
        after.add(e.copyWith(role: role));
      }
    }
    if (before.isEmpty) return;
    await _apply(_EditAction(added: after, removed: before), replace: true);
  }

  // ------------------------------------------------------------------
  // Texte et images
  // ------------------------------------------------------------------

  TextBlock? textAt(String pageId, Offset p) {
    final c = _contents[pageId];
    if (c == null) return null;
    for (final t in c.texts.reversed) {
      if (t.bounds.inflate(6).contains(p)) return t;
    }
    return null;
  }

  Future<TextBlock?> addText(
      String pageId, Offset at, String text, InkRole role, double size) async {
    final p = repo.page(pageId);
    if (p == null || text.trim().isEmpty) return null;
    final t = TextBlock(
      id: newId(),
      notebookId: notebookId,
      pageId: pageId,
      x: at.dx,
      y: at.dy,
      width: math.max(160, p.width - at.dx - 32),
      text: text,
      role: role,
      size: size,
    );
    await _apply(_EditAction(added: [t]));
    return t;
  }

  Future<void> updateText(TextBlock t,
      {String? text, InkRole? role, double? size}) async {
    if (text != null && text.trim().isEmpty) {
      await _apply(_EditAction(removed: [t]));
      return;
    }
    final u = t.copyWith(text: text, role: role, size: size);
    await _apply(_EditAction(added: [u], removed: [t]), replace: true);
  }

  Future<void> deleteText(TextBlock t) => _apply(_EditAction(removed: [t]));

  /// Pose une image au centre de [center], à au plus 60 % de la page.
  Future<void> addImage(String pageId, ImportedAsset asset, Size natural,
      {Offset? center}) async {
    final p = repo.page(pageId);
    if (p == null) return;
    final maxW = p.width * 0.6, maxH = p.height * 0.5;
    final k = math.min(1.0, math.min(maxW / natural.width, maxH / natural.height));
    final w = natural.width * k, h = natural.height * k;
    final c = center ?? Offset(p.width / 2, p.height / 3);
    final img = PageImage(
      id: newId(),
      notebookId: notebookId,
      pageId: pageId,
      assetId: asset.id,
      x: (c.dx - w / 2).clamp(0, p.width - w),
      y: (c.dy - h / 2).clamp(0, p.height - h),
      width: w,
      height: h,
    );
    await _apply(_EditAction(added: [img]));
    _selectionPage = pageId;
    selection = {img.id};
    _tool = EditorTool.lasso;
    _bump(pageId);
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Pages (actions du menu)
  // ------------------------------------------------------------------

  Future<NotePage> addPage({
    PageTemplate? template,
    PageInsert where = PageInsert.after,
    PageFormat? format,
  }) async {
    final ref = currentPage;
    final p = await repo.addPage(notebookId,
        template: template ??
            (ref?.assetId == null ? ref?.template : null) ??
            PageTemplate.lined,
        after: ref,
        where: where,
        format: format);
    setCurrentPage(p.id);
    return p;
  }

  Future<void> deletePage(NotePage page) async {
    final ps = pages;
    final i = ps.indexWhere((p) => p.id == page.id);
    await repo.updatePage(page.copyWith(deleted: true));
    if (pages.isEmpty) await repo.addPage(notebookId);
    final rest = pages;
    setCurrentPage(rest[math.min(math.max(i, 0), rest.length - 1)].id);
    _contents.remove(page.id);
    notifyListeners();
  }

  Future<void> clearPage(NotePage page) async {
    final c = _contents[page.id] ?? await repo.loadPage(page);
    final els = c.elements.toList();
    if (els.isEmpty) return;
    await _apply(_EditAction(removed: els));
  }

  Future<NotePage> duplicatePage(NotePage page) async {
    final copy = await repo.duplicatePage(page);
    setCurrentPage(copy.id);
    return copy;
  }

  Future<void> setTemplate(NotePage page, PageTemplate t) =>
      repo.updatePage(page.copyWith(template: t));

  // ------------------------------------------------------------------
  // Annuler / rétablir
  // ------------------------------------------------------------------

  final List<_EditAction> _undo = [];
  final List<_EditAction> _redo = [];

  /// [replace]: les éléments ajoutés remplacent les retirés (même id,
  /// modification); sinon les retirés deviennent des pierres tombales.
  Future<void> _apply(_EditAction a,
      {bool replace = false, bool record = true}) async {
    final touched = <String>{};
    for (final e in a.removed) {
      final c = _contents[e.pageId];
      if (c != null) {
        _removeFromContent(c, e);
        touched.add(e.pageId);
      }
    }
    for (final e in a.added) {
      final c = _contents[e.pageId];
      if (c == null) continue;
      _removeFromContent(c, e);
      switch (e) {
        case InkStroke s when s.highlight:
          c.highlights.add(s);
        case InkStroke s:
          c.strokes.add(s);
        case TextBlock t:
          c.texts.add(t);
        case PageImage i:
          c.images.add(i);
      }
      touched.add(e.pageId);
    }
    if (record) {
      _undo.add(a);
      _redo.clear();
    }
    touched.forEach(_bump);
    notifyListeners();
    await repo.saveElements([
      ...a.added,
      if (!replace)
        for (final e in a.removed) e.markDeleted(),
    ]);
    unawaited(repo.touchNotebook(notebookId));
  }

  static void _removeFromContent(PageContent c, PageElement e) {
    switch (e) {
      case InkStroke s:
        (s.highlight ? c.highlights : c.strokes).removeWhere((x) => x.id == s.id);
      case TextBlock t:
        c.texts.removeWhere((x) => x.id == t.id);
      case PageImage i:
        c.images.removeWhere((x) => x.id == i.id);
    }
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final a = _undo.removeLast();
    clearSelection();
    _redo.add(await _invert(a));
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    final a = _redo.removeLast();
    clearSelection();
    _undo.add(await _invert(a));
  }

  /// Applique l'inverse de [a] et retourne l'action qui l'annule à son tour.
  Future<_EditAction> _invert(_EditAction a) async {
    final isModification = a.added.isNotEmpty &&
        a.removed.isNotEmpty &&
        a.added.length == a.removed.length &&
        a.added.every((e) => a.removed.any((r) => r.id == e.id));
    if (isModification) {
      // Revenir à l'état précédent: nouvelle modification datée de maintenant.
      final restored = [for (final e in a.removed) _touch(e)];
      await _apply(_EditAction(added: restored, removed: a.added),
          replace: true, record: false);
      return _EditAction(added: restored, removed: a.added);
    }
    // Ajout <-> suppression. Les éléments supprimés reviennent sous un
    // nouvel identifiant.
    final recreated = [for (final e in a.removed) _clone(e)];
    await _apply(_EditAction(added: recreated, removed: a.added),
        record: false);
    return _EditAction(added: recreated, removed: a.added);
  }

  static PageElement _touch(PageElement e) => switch (e) {
        InkStroke s => s.copyWith(),
        TextBlock t => t.copyWith(),
        PageImage i => i.copyWith(),
      };

  static PageElement _clone(PageElement e) => switch (e) {
        InkStroke s => s.copyWith(id: newId(), deleted: false),
        TextBlock t => t.copyWith(id: newId(), deleted: false),
        PageImage i => i.copyWith(id: newId(), deleted: false),
      };

  @override
  void dispose() {
    _pageSub.cancel();
    _rescueSub.cancel();
    _holdTimer?.cancel();
    _laserTimer?.cancel();
    repo.removeListener(_onRepo);
    liveVersion.dispose();
    laserVersion.dispose();
    currentPageNotifier.dispose();
    repo.scheduleSync(now: true);
    super.dispose();
  }
}
