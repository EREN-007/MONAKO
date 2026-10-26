import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/render/stroke_geometry.dart';
import '../../core/roles.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/rescue_gesture.dart';

enum EditorTool { pen, highlighter, text, eraser, select, hand }

/// Une action annulable: éléments ajoutés et éléments retirés.
/// Annuler une suppression recrée les éléments avec un nouvel identifiant:
/// une pierre tombale n'est jamais annulée (fusion sûre entre appareils).
class _EditAction {
  _EditAction({this.added = const [], this.removed = const []});
  List<PageElement> added;
  List<PageElement> removed;
}

class EditorController extends ChangeNotifier {
  EditorController(this.repo, this.notebookId, {int initialPage = 0}) {
    _pageIndex = initialPage;
    _pageSub = repo.pageChanges.listen(_onRemotePages);
    _rescueSub = RescueGesture.events.listen(_onRescue);
    repo.addListener(_onRepo);
  }

  final NotesRepository repo;
  final String notebookId;
  late final StreamSubscription<Set<String>> _pageSub;
  late final StreamSubscription<DateTime> _rescueSub;

  final StrokeGeometryCache geometry = StrokeGeometryCache();

  // ------------------------------------------------------------------
  // État
  // ------------------------------------------------------------------

  int _pageIndex = 0;
  PageContent? _content;
  bool loading = true;
  int version = 0;

  EditorTool _tool = EditorTool.pen;
  InkRole inkRole = InkRole.inkPrimary;
  InkRole highlightRole = InkRole.highlight1;
  double penWidth = 2.4;
  double highlighterWidth = 18;
  double eraserRadius = 10;

  final List<_EditAction> _undo = [];
  final List<_EditAction> _redo = [];

  /// Points du trait en cours: x, y, pression.
  final List<double> live = [];
  final ValueNotifier<int> liveVersion = ValueNotifier(0);
  int? _livePointer;

  Set<String> selection = {};
  Rect? selectionRect;
  Offset? _selectStart;
  Offset _dragDelta = Offset.zero;
  Offset? _dragStart;
  bool get dragging => _dragStart != null;
  Offset get dragDelta => _dragDelta;

  final List<(DateTime, InkStroke)> _recentTaps = [];

  List<NotePage> get pages => repo.pagesOf(notebookId);
  int get pageIndex => _pageIndex.clamp(0, math.max(0, pages.length - 1));
  NotePage? get page => pages.isEmpty ? null : pages[pageIndex];
  PageContent? get content => _content;
  List<InkStroke> get strokes => _content?.strokes ?? const [];
  List<InkStroke> get highlights => _content?.highlights ?? const [];
  List<TextBlock> get texts => _content?.texts ?? const [];

  EditorTool get tool => _tool;
  set tool(EditorTool t) {
    _tool = t;
    clearSelection();
    notifyListeners();
  }

  void setInkRole(InkRole r) {
    inkRole = r;
    notifyListeners();
  }

  void setHighlightRole(InkRole r) {
    highlightRole = r;
    notifyListeners();
  }

  void setPenWidth(double w) {
    penWidth = w;
    notifyListeners();
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  // ------------------------------------------------------------------
  // Pages
  // ------------------------------------------------------------------

  Future<void> load() async {
    final p = page;
    if (p == null) {
      loading = false;
      notifyListeners();
      return;
    }
    loading = _content?.page.id != p.id;
    if (loading) notifyListeners();
    final c = await repo.loadPage(p);
    if (page?.id != p.id) return; // la page a changé entre-temps
    _content = c;
    geometry.retainOnly([...c.strokes.map((s) => s.id), ...c.highlights.map((s) => s.id)]);
    loading = false;
    version++;
    notifyListeners();
  }

  Future<void> goToPage(int index) async {
    if (index < 0 || index >= pages.length || index == pageIndex) return;
    _pageIndex = index;
    _undo.clear();
    _redo.clear();
    clearSelection();
    // Sauvegarde à chaque changement de page.
    repo.scheduleSync(now: true);
    await load();
  }

  Future<void> addPage({PageTemplate? template}) async {
    final p = await repo.addPage(notebookId,
        template: template ?? page?.template ?? PageTemplate.lined, after: page);
    final i = pages.indexWhere((x) => x.id == p.id);
    _pageIndex = i < 0 ? pages.length - 1 : i - 1;
    await goToPage(i < 0 ? pages.length - 1 : i);
  }

  Future<void> deleteCurrentPage() async {
    final p = page;
    if (p == null) return;
    await repo.updatePage(p.copyWith(deleted: true));
    if (pages.isEmpty) await repo.addPage(notebookId);
    _pageIndex = math.min(_pageIndex, pages.length - 1);
    _content = null;
    await load();
  }

  Future<void> setTemplate(PageTemplate t) async {
    final p = page;
    if (p == null) return;
    await repo.updatePage(p.copyWith(template: t));
    _content = PageContent(page!, strokes, highlights, texts);
    version++;
    notifyListeners();
  }

  void _onRepo() {
    // Titre, pages ajoutées par un autre appareil…
    notifyListeners();
  }

  void _onRemotePages(Set<String> ids) {
    final p = page;
    if (p != null && ids.contains(p.id) && _livePointer == null && !dragging) {
      load();
    }
  }

  // ------------------------------------------------------------------
  // Dessin
  // ------------------------------------------------------------------

  bool get isDrawingTool =>
      _tool == EditorTool.pen || _tool == EditorTool.highlighter;

  void strokeStart(int pointer, Offset p, double? pressure) {
    _livePointer = pointer;
    live
      ..clear()
      ..addAll([p.dx, p.dy, pressure ?? -1]);
    liveVersion.value++;
  }

  void strokeExtend(int pointer, Offset p, double? pressure) {
    if (pointer != _livePointer) return;
    final n = live.length;
    if (n >= 3 && (Offset(live[n - 3], live[n - 2]) - p).distanceSquared < 0.25) {
      return;
    }
    live.addAll([p.dx, p.dy, pressure ?? -1]);
    liveVersion.value++;
  }

  void strokeCancel() {
    _livePointer = null;
    live.clear();
    liveVersion.value++;
  }

  Future<void> strokeEnd(int pointer) async {
    if (pointer != _livePointer) return;
    _livePointer = null;
    final p = page;
    if (p == null || live.isEmpty) return strokeCancel();
    final highlight = _tool == EditorTool.highlighter;
    final s = InkStroke(
      id: newId(),
      notebookId: notebookId,
      pageId: p.id,
      role: highlight ? highlightRole : inkRole,
      width: highlight ? highlighterWidth : penWidth,
      points: Float32List.fromList(live),
      highlight: highlight,
    );
    live.clear();
    liveVersion.value++;
    if (s.pointCount <= 2) _recentTaps.add((DateTime.now(), s));
    await _apply(_EditAction(added: [s]));
  }

  bool get hasLiveStroke => _livePointer != null;

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
    _content?.strokes.removeWhere((s) => ids.contains(s.id));
    _content?.highlights.removeWhere((s) => ids.contains(s.id));
    _undo.removeWhere((a) => a.added.any((e) => ids.contains(e.id)));
    version++;
    notifyListeners();
    await repo.saveElements(dots.map((d) => d.markDeleted()));
  }

  // ------------------------------------------------------------------
  // Gomme
  // ------------------------------------------------------------------

  final List<PageElement> _erasing = [];

  void eraseAt(Offset p) {
    final hit = <PageElement>[];
    for (final s in [...strokes, ...highlights]) {
      if (_hits(s, p, eraserRadius)) hit.add(s);
    }
    if (hit.isEmpty) return;
    final ids = hit.map((e) => e.id).toSet();
    _content!.strokes.removeWhere((s) => ids.contains(s.id));
    _content!.highlights.removeWhere((s) => ids.contains(s.id));
    _erasing.addAll(hit);
    version++;
    notifyListeners();
  }

  Future<void> eraseEnd() async {
    if (_erasing.isEmpty) return;
    final removed = List<PageElement>.of(_erasing);
    _erasing.clear();
    _undo.add(_EditAction(removed: removed));
    _redo.clear();
    await repo.saveElements(removed.map((e) => e.markDeleted()));
    notifyListeners();
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
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // ------------------------------------------------------------------
  // Sélection
  // ------------------------------------------------------------------

  void selectStart(Offset p) {
    if (selection.isNotEmpty && (selectionBounds?.inflate(12).contains(p) ?? false)) {
      _dragStart = p;
      _dragDelta = Offset.zero;
      return;
    }
    _selectStart = p;
    selection = {};
    selectionRect = Rect.fromPoints(p, p);
    notifyListeners();
  }

  void selectUpdate(Offset p) {
    if (_dragStart != null) {
      _dragDelta = p - _dragStart!;
      notifyListeners();
      return;
    }
    if (_selectStart == null) return;
    selectionRect = Rect.fromPoints(_selectStart!, p);
    notifyListeners();
  }

  Future<void> selectEnd() async {
    if (_dragStart != null) {
      final delta = _dragDelta;
      _dragStart = null;
      _dragDelta = Offset.zero;
      if (delta.distance > 0.5) await _moveSelection(delta);
      notifyListeners();
      return;
    }
    final r = selectionRect;
    _selectStart = null;
    selectionRect = null;
    if (r == null || r.width < 4 && r.height < 4) {
      selection = {};
    } else {
      selection = {
        for (final s in [...strokes, ...highlights])
          if (_strokeInside(s, r)) s.id,
        for (final t in texts)
          if (r.overlaps(t.bounds)) t.id,
      };
    }
    notifyListeners();
  }

  static bool _strokeInside(InkStroke s, Rect r) {
    if (!r.overlaps(s.bounds)) return false;
    var inside = 0;
    for (var i = 0; i < s.pointCount; i++) {
      if (r.contains(s.pointAt(i))) inside++;
    }
    return inside >= math.max(1, s.pointCount ~/ 2);
  }

  Rect? get selectionBounds {
    Rect? b;
    for (final e in _selectedElements) {
      b = b == null ? e.bounds : b.expandToInclude(e.bounds);
    }
    return b;
  }

  List<PageElement> get _selectedElements => [
        for (final s in strokes)
          if (selection.contains(s.id)) s,
        for (final s in highlights)
          if (selection.contains(s.id)) s,
        for (final t in texts)
          if (selection.contains(t.id)) t,
      ];

  void clearSelection() {
    selection = {};
    selectionRect = null;
    _selectStart = null;
    _dragStart = null;
  }

  Future<void> _moveSelection(Offset delta) async {
    final before = _selectedElements;
    final after = [
      for (final e in before)
        switch (e) {
          InkStroke s => s.translated(delta),
          TextBlock t => t.copyWith(x: t.x + delta.dx, y: t.y + delta.dy),
        },
    ];
    await _apply(_EditAction(added: after, removed: before), replace: true);
  }

  Future<void> deleteSelection() async {
    final els = _selectedElements;
    if (els.isEmpty) return;
    clearSelection();
    await _apply(_EditAction(removed: els));
  }

  /// Change le rôle des traits sélectionnés (les surlignages gardent un
  /// rôle de surlignage).
  Future<void> setSelectionRole(InkRole role) async {
    final before = <PageElement>[];
    final after = <PageElement>[];
    for (final e in _selectedElements) {
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
  // Texte
  // ------------------------------------------------------------------

  TextBlock? textAt(Offset p) {
    for (final t in texts.reversed) {
      if (t.bounds.inflate(6).contains(p)) return t;
    }
    return null;
  }

  Future<TextBlock?> addText(Offset at, String text, InkRole role, double size) async {
    final p = page;
    if (p == null || text.trim().isEmpty) return null;
    final t = TextBlock(
      id: newId(),
      notebookId: notebookId,
      pageId: p.id,
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

  Future<void> updateText(TextBlock t, {String? text, InkRole? role, double? size}) async {
    if (text != null && text.trim().isEmpty) {
      await _apply(_EditAction(removed: [t]));
      return;
    }
    final u = t.copyWith(text: text, role: role, size: size);
    await _apply(_EditAction(added: [u], removed: [t]), replace: true);
  }

  Future<void> deleteText(TextBlock t) => _apply(_EditAction(removed: [t]));

  // ------------------------------------------------------------------
  // Annuler / rétablir
  // ------------------------------------------------------------------

  /// [replace]: les éléments ajoutés remplacent les retirés (même id,
  /// modification); sinon les retirés deviennent des pierres tombales.
  Future<void> _apply(_EditAction a, {bool replace = false, bool record = true}) async {
    final c = _content;
    if (c == null) return;
    final addedIds = a.added.map((e) => e.id).toSet();
    final removedIds = a.removed.map((e) => e.id).toSet();
    c.strokes.removeWhere((s) => removedIds.contains(s.id) || addedIds.contains(s.id));
    c.highlights.removeWhere((s) => removedIds.contains(s.id) || addedIds.contains(s.id));
    c.texts.removeWhere((t) => removedIds.contains(t.id) || addedIds.contains(t.id));
    for (final e in a.added) {
      switch (e) {
        case InkStroke s when s.highlight:
          c.highlights.add(s);
        case InkStroke s:
          c.strokes.add(s);
        case TextBlock t:
          c.texts.add(t);
      }
    }
    if (record) {
      _undo.add(a);
      _redo.clear();
    }
    version++;
    notifyListeners();
    await repo.saveElements([
      ...a.added,
      if (!replace)
        for (final e in a.removed) e.markDeleted(),
    ]);
    unawaited(repo.touchNotebook(notebookId));
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final a = _undo.removeLast();
    clearSelection();
    final inverse = await _invert(a);
    _redo.add(inverse);
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    final a = _redo.removeLast();
    clearSelection();
    final inverse = await _invert(a);
    _undo.add(inverse);
  }

  /// Applique l'inverse de [a] et retourne l'action qui l'annule à son tour.
  Future<_EditAction> _invert(_EditAction a) async {
    final isModification = a.added.isNotEmpty &&
        a.removed.isNotEmpty &&
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
    await _apply(_EditAction(added: recreated, removed: a.added), record: false);
    return _EditAction(added: recreated, removed: a.added);
  }

  static PageElement _touch(PageElement e) => switch (e) {
        InkStroke s => s.copyWith(),
        TextBlock t => t.copyWith(),
      };

  static PageElement _clone(PageElement e) => switch (e) {
        InkStroke s => s.copyWith(id: newId(), deleted: false),
        TextBlock t => TextBlock(
            id: newId(),
            notebookId: t.notebookId,
            pageId: t.pageId,
            x: t.x,
            y: t.y,
            width: t.width,
            text: t.text,
            role: t.role,
            size: t.size,
            font: t.font,
          ),
      };

  @override
  void dispose() {
    _pageSub.cancel();
    _rescueSub.cancel();
    repo.removeListener(_onRepo);
    liveVersion.dispose();
    repo.scheduleSync(now: true);
    super.dispose();
  }
}
