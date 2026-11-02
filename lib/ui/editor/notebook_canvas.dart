import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:provider/provider.dart';

import '../../core/profiles/palette.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/render/page_painter.dart';
import '../../core/render/stroke_geometry.dart';
import '../../core/roles.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/asset_renderer.dart';
import 'editor_controller.dart';

/// Pilote la vue: position, zoom, saut vers une page.
class CanvasViewController extends ChangeNotifier {
  double scale = 1;
  Offset offset = Offset.zero;
  int? _jumpTo;

  void jumpToPage(int index) {
    _jumpTo = index;
    notifyListeners();
  }

  void setView(double s, Offset o) {
    scale = s;
    offset = o;
    notifyListeners();
  }
}

/// Surface d'écriture: toutes les pages du cahier, en défilement continu
/// (vertical par défaut, horizontal en option).
///
/// Une seule couche reçoit toutes les entrées et décide:
/// - stylet (ou souris): écrit;
/// - doigt: défile et zoome dès qu'un stylet a été utilisé (rejet de la
///   paume: une main posée sur l'écran n'interrompt jamais le trait);
///   sinon, un doigt écrit si « écrire avec le doigt » est activé, deux
///   doigts défilent et zooment;
/// - molette / pavé tactile: défile, Ctrl + molette ou pincement: zoome.
class NotebookCanvas extends StatefulWidget {
  const NotebookCanvas({
    super.key,
    required this.controller,
    required this.view,
    required this.profile,
    required this.palette,
    required this.horizontal,
    required this.fingerDrawing,
    required this.onTap,
    this.showOriginal = false,
  });

  final EditorController controller;
  final CanvasViewController view;
  final VisualProfile profile;
  final ResolvedPalette palette;
  final bool horizontal;
  final bool fingerDrawing;
  final bool showOriginal;

  /// Toucher bref sur une page (outil texte, sélection d'un texte…).
  final void Function(String pageId, Offset pagePoint) onTap;

  @override
  State<NotebookCanvas> createState() => _NotebookCanvasState();
}

enum _Role { draw, gesture, ignore }

class _Pointer {
  _Pointer(this.kind, this.position, this.role, this.downAt);
  final PointerDeviceKind kind;
  Offset position;
  _Role role;
  final DateTime downAt;
  Offset? start;
}

class _NotebookCanvasState extends State<NotebookCanvas>
    with SingleTickerProviderStateMixin {
  static const gap = 28.0;
  static const minScale = 0.25, maxScale = 6.0;

  final Map<int, _Pointer> _pointers = {};
  bool _stylusSeen = false;
  int? _drawPointer;
  String? _drawPage;
  Size _viewport = Size.zero;
  bool _fitted = false;
  String? _fitKey;

  // Pincement / défilement
  Offset? _lastFocal;
  double? _lastSpan;

  // Lancer (inertie)
  late final Ticker _ticker = createTicker(_onFling);
  Offset _velocity = Offset.zero;
  Duration _lastTick = Duration.zero;
  final List<(Duration, Offset)> _samples = [];

  EditorController get ctl => widget.controller;
  CanvasViewController get view => widget.view;

  @override
  void initState() {
    super.initState();
    view.addListener(_onView);
  }

  @override
  void didUpdateWidget(NotebookCanvas old) {
    super.didUpdateWidget(old);
    if (old.view != view) {
      old.view.removeListener(_onView);
      view.addListener(_onView);
    }
    if (old.horizontal != widget.horizontal) _fitted = false;
  }

  @override
  void dispose() {
    view.removeListener(_onView);
    _ticker.dispose();
    super.dispose();
  }

  void _onView() {
    final target = view._jumpTo;
    if (target != null) {
      view._jumpTo = null;
      _scrollToPage(target);
      return;
    }
    setState(() {});
  }

  // ------------------------------------------------------------------
  // Mise en page
  // ------------------------------------------------------------------

  List<NotePage> get _pages => ctl.pages;

  /// Rectangles des pages dans la scène.
  List<Rect> _layout(List<NotePage> pages) {
    final rects = <Rect>[];
    final maxW = pages.fold<double>(0, (m, p) => math.max(m, p.width));
    final maxH = pages.fold<double>(0, (m, p) => math.max(m, p.height));
    var cursor = 0.0;
    for (final p in pages) {
      if (widget.horizontal) {
        rects.add(Rect.fromLTWH(cursor, (maxH - p.height) / 2, p.width, p.height));
        cursor += p.width + gap;
      } else {
        rects.add(Rect.fromLTWH((maxW - p.width) / 2, cursor, p.width, p.height));
        cursor += p.height + gap;
      }
    }
    return rects;
  }

  Size _sceneSize(List<Rect> rects) {
    if (rects.isEmpty) return Size.zero;
    return Size(
      rects.map((r) => r.right).reduce(math.max),
      rects.map((r) => r.bottom).reduce(math.max),
    );
  }

  void _fit(List<NotePage> pages, List<Rect> rects) {
    final key = '${widget.profile.text.defaultZoom}|${_viewport.width.round()}|${widget.horizontal}';
    if (_fitted && _fitKey == key) return;
    if (pages.isEmpty || _viewport.isEmpty) return;
    _fitted = true;
    _fitKey = key;
    final scene = _sceneSize(rects);
    final fitW = (_viewport.width - 32) / (widget.horizontal ? rects.first.width : scene.width);
    final fitH = (_viewport.height - 32) / rects.first.height;
    var s = widget.horizontal ? math.min(fitW, fitH) : fitW;
    s = (s * widget.profile.text.defaultZoom).clamp(minScale, maxScale);
    final i = ctl.currentIndex.clamp(0, rects.length - 1);
    final r = rects[i];
    final x = widget.horizontal
        ? 16 - r.left * s
        : math.max(16, (_viewport.width - scene.width * s) / 2);
    final y = widget.horizontal
        ? (_viewport.height - scene.height * s) / 2
        : 16 - r.top * s;
    view.scale = s;
    view.offset = Offset(x.toDouble(), y.toDouble());
  }

  void _scrollToPage(int index) {
    final pages = _pages;
    if (pages.isEmpty) return;
    final rects = _layout(pages);
    final r = rects[index.clamp(0, rects.length - 1)];
    final s = view.scale;
    setState(() {
      view.offset = widget.horizontal
          ? Offset(16 - r.left * s, view.offset.dy)
          : Offset(view.offset.dx, 16 - r.top * s);
    });
    ctl.setCurrentPage(pages[index.clamp(0, pages.length - 1)].id);
  }

  /// Garde la scène atteignable (on ne peut pas la perdre hors de l'écran).
  void _clamp(List<Rect> rects) {
    final scene = _sceneSize(rects) * view.scale;
    final margin = _viewport.shortestSide * 0.5;
    double c(double v, double content, double port) {
      final lo = math.min(port - content - margin, margin);
      final hi = math.max(margin, port - content - margin);
      return v.clamp(math.min(lo, hi), math.max(lo, hi));
    }

    view.offset = Offset(
      c(view.offset.dx, scene.width, _viewport.width),
      c(view.offset.dy, scene.height, _viewport.height),
    );
  }

  Offset _toScene(Offset local) => (local - view.offset) / view.scale;

  /// Page sous un point de l'écran, avec la position dans la page.
  (NotePage, Offset)? _hitPage(Offset local, {String? onlyPage}) {
    final scene = _toScene(local);
    final pages = _pages;
    final rects = _layout(pages);
    for (var i = 0; i < pages.length; i++) {
      if (onlyPage != null && pages[i].id != onlyPage) continue;
      if (onlyPage != null || rects[i].contains(scene)) {
        return (pages[i], scene - rects[i].topLeft);
      }
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Entrées
  // ------------------------------------------------------------------

  static bool _isStylus(PointerDeviceKind k) =>
      k == PointerDeviceKind.stylus || k == PointerDeviceKind.invertedStylus;

  static double? _pressure(PointerEvent e) {
    if (!_isStylus(e.kind)) return null;
    final range = e.pressureMax - e.pressureMin;
    if (range <= 0) return null;
    return ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0);
  }

  bool get _toolDraws => ctl.tool != EditorTool.hand;

  void _onDown(PointerDownEvent e) {
    _ticker.stop();
    if (_isStylus(e.kind) && !_stylusSeen) setState(() => _stylusSeen = true);
    final drawing = _drawPointer != null;
    _Role role;
    if (_isStylus(e.kind)) {
      role = drawing ? _Role.ignore : _Role.draw;
    } else if (e.kind == PointerDeviceKind.mouse) {
      role = e.buttons == kPrimaryMouseButton && _toolDraws && !drawing
          ? _Role.draw
          : _Role.gesture;
    } else {
      // Doigt.
      if (drawing && _isStylus(_pointers[_drawPointer]!.kind)) {
        // Rejet de la paume: un stylet écrit, la main est ignorée.
        role = _Role.ignore;
      } else if (drawing) {
        // Deuxième doigt pendant un trait au doigt: c'est un pincement.
        ctl.strokeCancel();
        ctl.eraseEnd();
        _pointers[_drawPointer]!.role = _Role.gesture;
        _drawPointer = null;
        role = _Role.gesture;
      } else if (_toolDraws &&
          widget.fingerDrawing &&
          !_stylusSeen &&
          _pointers.values.where((p) => p.role == _Role.gesture).isEmpty) {
        role = _Role.draw;
      } else {
        role = _Role.gesture;
      }
    }
    final p = _Pointer(e.kind, e.localPosition, role, DateTime.now())
      ..start = e.localPosition;
    _pointers[e.pointer] = p;
    if (role == _Role.gesture) {
      _resetGesture();
      _samples.clear();
      return;
    }
    if (role == _Role.draw) _startDraw(e);
  }

  void _startDraw(PointerDownEvent e) {
    final hit = _hitPage(e.localPosition);
    if (hit == null) {
      _pointers[e.pointer]!.role = _Role.gesture;
      _resetGesture();
      return;
    }
    final (page, pt) = hit;
    _drawPointer = e.pointer;
    _drawPage = page.id;
    ctl.setCurrentPage(page.id);
    final tool = e.kind == PointerDeviceKind.invertedStylus ? EditorTool.eraser : ctl.tool;
    switch (tool) {
      case EditorTool.pen:
      case EditorTool.highlighter:
      case EditorTool.shapes:
        ctl.strokeStart(page.id, e.pointer, pt, _pressure(e));
      case EditorTool.eraser:
        ctl.eraseAt(page.id, pt);
      case EditorTool.lasso:
        ctl.lassoStart(page.id, pt);
      case EditorTool.laser:
        ctl.laserAt(page.id, pt);
      case EditorTool.text:
      case EditorTool.hand:
        break;
    }
  }

  void _onMove(PointerMoveEvent e) {
    final p = _pointers[e.pointer];
    if (p == null) return;
    p.position = e.localPosition;
    switch (p.role) {
      case _Role.ignore:
        return;
      case _Role.gesture:
        _updateGesture(e.timeStamp);
      case _Role.draw:
        if (e.pointer != _drawPointer) return;
        final hit = _hitPage(e.localPosition, onlyPage: _drawPage);
        if (hit == null) return;
        final pt = hit.$2;
        final tool = e.kind == PointerDeviceKind.invertedStylus ? EditorTool.eraser : ctl.tool;
        switch (tool) {
          case EditorTool.pen:
          case EditorTool.highlighter:
          case EditorTool.shapes:
            ctl.strokeExtend(e.pointer, pt, _pressure(e));
          case EditorTool.eraser:
            ctl.eraseAt(_drawPage!, pt);
          case EditorTool.lasso:
            ctl.lassoUpdate(pt);
          case EditorTool.laser:
            ctl.laserAt(_drawPage!, pt);
          case EditorTool.text:
          case EditorTool.hand:
            break;
        }
    }
  }

  void _onUp(PointerEvent e) {
    final p = _pointers.remove(e.pointer);
    if (p == null) return;
    final moved = (e.localPosition - (p.start ?? e.localPosition)).distance;
    final quick = DateTime.now().difference(p.downAt) < const Duration(milliseconds: 350);
    if (p.role == _Role.gesture) {
      _resetGesture();
      if (_pointers.values.where((q) => q.role == _Role.gesture).isEmpty) {
        _startFling();
      }
      // Toucher bref au doigt avec l'outil texte.
      if (moved < 10 && quick && ctl.tool == EditorTool.text && e is PointerUpEvent) {
        final hit = _hitPage(e.localPosition);
        if (hit != null) widget.onTap(hit.$1.id, hit.$2);
      }
      return;
    }
    if (p.role != _Role.draw || e.pointer != _drawPointer) return;
    _drawPointer = null;
    final tool = p.kind == PointerDeviceKind.invertedStylus ? EditorTool.eraser : ctl.tool;
    final cancel = e is PointerCancelEvent;
    switch (tool) {
      case EditorTool.pen:
      case EditorTool.highlighter:
      case EditorTool.shapes:
        cancel ? ctl.strokeCancel() : ctl.strokeEnd(e.pointer);
      case EditorTool.eraser:
        ctl.eraseEnd();
      case EditorTool.lasso:
        ctl.lassoEnd();
      case EditorTool.text:
        if (moved < 10 && !cancel) {
          final hit = _hitPage(e.localPosition);
          if (hit != null) widget.onTap(hit.$1.id, hit.$2);
        }
      case EditorTool.laser:
      case EditorTool.hand:
        break;
    }
    _drawPage = null;
  }

  // ------------------------------------------------------------------
  // Défilement, zoom, inertie
  // ------------------------------------------------------------------

  List<_Pointer> get _gesturePointers =>
      _pointers.values.where((p) => p.role == _Role.gesture).toList();

  void _resetGesture() {
    _lastFocal = null;
    _lastSpan = null;
  }

  void _updateGesture(Duration time) {
    final g = _gesturePointers;
    if (g.isEmpty) return;
    final focal = g.map((p) => p.position).reduce((a, b) => a + b) / g.length.toDouble();
    final span = g.length < 2
        ? null
        : g.map((p) => (p.position - focal).distance).reduce((a, b) => a + b) / g.length;
    if (_lastFocal != null) {
      final pan = focal - _lastFocal!;
      var s = view.scale;
      var o = view.offset + pan;
      if (span != null && _lastSpan != null && _lastSpan! > 0) {
        final ns = (s * span / _lastSpan!).clamp(minScale, maxScale);
        // Zoom autour du point focal.
        o = focal - (focal - o) * (ns / s);
        s = ns;
      }
      view.scale = s;
      view.offset = o;
      _clamp(_layout(_pages));
      _samples.add((time, pan));
      if (_samples.length > 6) _samples.removeAt(0);
      setState(() {});
    }
    _lastFocal = focal;
    _lastSpan = span;
  }

  void _startFling() {
    if (_samples.length < 2) return;
    final dt = (_samples.last.$1 - _samples.first.$1).inMicroseconds / 1e6;
    if (dt <= 0) return;
    final total = _samples.skip(1).fold(Offset.zero, (a, b) => a + b.$2);
    _velocity = total / dt;
    _samples.clear();
    if (_velocity.distance < 120) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onFling(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    view.offset += _velocity * dt;
    _velocity *= math.pow(0.04, dt).toDouble(); // freinage
    _clamp(_layout(_pages));
    setState(() {});
    if (_velocity.distance < 20) _ticker.stop();
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isMetaPressed) {
        _zoomAt(e.localPosition, math.pow(0.998, e.scrollDelta.dy).toDouble());
      } else {
        final d = keys.isShiftPressed
            ? Offset(e.scrollDelta.dy, e.scrollDelta.dx)
            : e.scrollDelta;
        view.offset -= d;
        _clamp(_layout(_pages));
        setState(() {});
      }
    } else if (e is PointerScaleEvent) {
      _zoomAt(e.localPosition, e.scale);
    }
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e) {
    view.offset += e.localPanDelta;
    _clamp(_layout(_pages));
    setState(() {});
    if (e.scale != 1 && _lastSpan != null) {
      _zoomAt(e.localPosition, e.scale / _lastSpan!);
    }
    _lastSpan = e.scale;
  }

  void _zoomAt(Offset focal, double factor) {
    final s = view.scale;
    final ns = (s * factor).clamp(minScale, maxScale);
    view.offset = focal - (focal - view.offset) * (ns / s);
    view.scale = ns;
    _clamp(_layout(_pages));
    setState(() {});
  }

  // ------------------------------------------------------------------
  // Rendu
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _viewport = constraints.biggest;
      final pages = _pages;
      final rects = _layout(pages);
      _fit(pages, rects);

      // Pages visibles (+ marge) et page courante (la plus visible).
      final visibleRect = Rect.fromLTWH(
        -view.offset.dx / view.scale,
        -view.offset.dy / view.scale,
        _viewport.width / view.scale,
        _viewport.height / view.scale,
      );
      final margin = visibleRect.longestSide * 0.5;
      final near = visibleRect.inflate(margin);
      final visible = <int>[];
      var best = -1;
      var bestArea = 0.0;
      for (var i = 0; i < rects.length; i++) {
        if (rects[i].overlaps(near)) visible.add(i);
        final inter = rects[i].intersect(visibleRect);
        final area = inter.width > 0 && inter.height > 0 ? inter.width * inter.height : 0.0;
        if (area > bestArea) {
          bestArea = area;
          best = i;
        }
      }
      final ids = [for (final i in visible) pages[i].id];
      final keep = [
        if (ctl.selectionPage != null) ctl.selectionPage!,
        if (ctl.livePage != null) ctl.livePage!,
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ctl.ensureLoaded(ids, keep: keep);
        if (best >= 0 && _drawPointer == null) ctl.setCurrentPage(pages[best].id);
      });

      final matrix = Matrix4.identity()
        ..translateByDouble(view.offset.dx, view.offset.dy, 0, 1)
        ..scaleByDouble(view.scale, view.scale, 1, 1);

      return Listener(
        key: const ValueKey('page-input'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onUp,
        onPointerSignal: _onSignal,
        onPointerPanZoomStart: (_) => _lastSpan = 1,
        onPointerPanZoomUpdate: _onPanZoomUpdate,
        onPointerPanZoomEnd: (_) => _lastSpan = null,
        child: ClipRect(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SizedBox.expand(
              child: IgnorePointer(
                child: Transform(
                  transform: matrix,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: 0,
                    minHeight: 0,
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: SizedBox(
                      width: _sceneSize(rects).width,
                      height: _sceneSize(rects).height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final i in visible)
                            Positioned.fromRect(
                              rect: rects[i],
                              child: NotePageView(
                                key: ValueKey(pages[i].id),
                                page: pages[i],
                                controller: ctl,
                                profile: widget.profile,
                                palette: widget.palette,
                                showOriginal: widget.showOriginal,
                                pageNumber: i + 1,
                                pageCount: pages.length,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Une page: fond (gabarit ou PDF recoloré), images, encre, texte,
/// sélection et trait en cours, chacun sur sa propre couche.
class NotePageView extends StatelessWidget {
  const NotePageView({
    super.key,
    required this.page,
    required this.controller,
    required this.profile,
    required this.palette,
    required this.pageNumber,
    required this.pageCount,
    this.showOriginal = false,
  });

  final NotePage page;
  final EditorController controller;
  final VisualProfile profile;
  final ResolvedPalette palette;
  final bool showOriginal;
  final int pageNumber, pageCount;

  @override
  Widget build(BuildContext context) {
    final ctl = controller;
    final content = ctl.content(page.id);
    final repo = context.read<NotesRepository>();
    final asset = repo.asset(page.assetId);
    final fontScale = profile.text.sizeMultiplier;
    final dragging = ctl.dragging && ctl.selectionPage == page.id;
    final hidden = dragging ? ctl.selection : const <String>{};

    return Semantics(
      label: 'Page $pageNumber / $pageCount',
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: asset == null
                    ? CustomPaint(
                        painter: PageBackgroundPainter(
                            palette: palette, template: page.template))
                    : PdfLayer(
                        asset: asset,
                        page: page,
                        profile: profile,
                        palette: palette,
                        original: showOriginal,
                      ),
              ),
            ),
            if (content != null)
              for (final img in content.images)
                if (!hidden.contains(img.id))
                  Positioned.fromRect(
                    rect: img.bounds,
                    child: PageImageView(image: img, profile: profile),
                  ),
            if (content != null)
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedSwitcher(
                    // Fondu de 200 ms au changement de profil: pas de flash.
                    duration: const Duration(milliseconds: 200),
                    child: CustomPaint(
                      key: ValueKey(palette),
                      size: page.size,
                      painter: InkPainter(
                        palette: palette,
                        strokes: content.strokes,
                        highlights: content.highlights,
                        cache: ctl.geometry,
                        version: ctl.versionOf(page.id),
                        hidden: hidden,
                      ),
                    ),
                  ),
                ),
              ),
            if (content != null)
              for (final t in content.texts)
                if (!hidden.contains(t.id))
                  Positioned(
                    left: t.x,
                    top: t.y,
                    width: t.width,
                    child: Text(
                      t.text,
                      style: TextStyle(
                        color: palette[t.role],
                        fontSize: t.size * fontScale,
                        fontWeight: t.role == InkRole.heading ? FontWeight.w700 : null,
                        height: profile.text.lineHeight,
                        wordSpacing: t.size * fontScale * profile.text.wordSpacing,
                        fontFamily: profile.text.font.family,
                      ),
                    ),
                  ),
            if (content != null && ctl.selectionPage == page.id)
              Positioned.fill(
                child: CustomPaint(
                  painter: SelectionPainter(ctl, palette, content, profile),
                ),
              ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: LivePainter(ctl, page.id, palette),
                ),
              ),
            ),
            if (content == null)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

/// Fond d'une page de PDF ou d'image, recoloré par le profil.
class PdfLayer extends StatefulWidget {
  const PdfLayer({
    super.key,
    required this.asset,
    required this.page,
    required this.profile,
    required this.palette,
    this.original = false,
    this.thumbnail = false,
  });

  final ImportedAsset asset;
  final NotePage page;
  final VisualProfile profile;
  final ResolvedPalette palette;
  final bool original;
  final bool thumbnail;

  @override
  State<PdfLayer> createState() => _PdfLayerState();
}

class _PdfLayerState extends State<PdfLayer> {
  ui.Image? _image;
  Future<ui.Image?>? _future;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(PdfLayer old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile ||
        old.original != widget.original ||
        old.asset.filter.cacheKey != widget.asset.filter.cacheKey) {
      _load();
    }
  }

  void _load() {
    final renderer = context.read<AssetRenderer>();
    final f = renderer.pageImage(
      widget.asset,
      widget.page.assetPage ?? 1,
      widget.profile,
      original: widget.original,
      width: widget.thumbnail ? AssetRenderer.thumbnailWidth : AssetRenderer.renderWidth,
    );
    _future = f;
    f.then((img) {
      if (!mounted || _future != f) return;
      setState(() {
        _image = img ?? _image;
        _failed = img == null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: CustomPaint(
            key: ValueKey(_image),
            size: widget.page.size,
            painter: PageBackgroundPainter(
              palette: widget.palette,
              template: PageTemplate.blank,
              image: _image,
            ),
          ),
        ),
      ),
      if (_failed && _image == null && !widget.thumbnail)
        const Center(child: Icon(Icons.cloud_download_outlined, size: 40)),
    ]);
  }
}

/// Image posée sur une page. Sa luminosité est plafonnée par le profil
/// (une photo très claire n'éblouit pas un élève sensible à la lumière).
class PageImageView extends StatefulWidget {
  const PageImageView({super.key, required this.image, required this.profile});
  final PageImage image;
  final VisualProfile profile;

  @override
  State<PageImageView> createState() => _PageImageViewState();
}

class _PageImageViewState extends State<PageImageView> {
  ui.Image? _img;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<NotesRepository>();
    final asset = repo.asset(widget.image.assetId);
    if (asset == null) return;
    context
        .read<AssetRenderer>()
        .pageImage(asset, 1, widget.profile, original: true)
        .then((img) {
      if (mounted) setState(() => _img = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cap = widget.profile.filters.pdfBrightnessCap.clamp(0.3, 1.0);
    final img = _img;
    if (img == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: const Center(child: Icon(Icons.image_outlined)),
      );
    }
    return ColorFiltered(
      colorFilter: ColorFilter.matrix([
        cap, 0, 0, 0, 0, //
        0, cap, 0, 0, 0, //
        0, 0, cap, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
      child: RawImage(image: img, fit: BoxFit.fill),
    );
  }
}

/// Trait en cours et pointeur laser, redessinés à chaque point sans toucher
/// aux autres couches.
class LivePainter extends CustomPainter {
  LivePainter(this.ctl, this.pageId, this.palette)
      : super(repaint: Listenable.merge([ctl.liveVersion, ctl.laserVersion]));

  final EditorController ctl;
  final String pageId;
  final ResolvedPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLaser(canvas);
    if (ctl.livePage != pageId) return;
    final pts = ctl.live;
    if (pts.isEmpty) return;
    final highlight = ctl.liveIsHighlight;
    final width = highlight ? ctl.highlighterWidth : ctl.penWidth;
    final color = highlight ? palette.highlight(ctl.highlightRole) : palette[ctl.inkRole];
    final shape = ctl.liveShape;
    if (shape != null) {
      canvas.drawPath(
        StrokeGeometryCache.centerlinePath(shape.points),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * palette.widthMultiplier
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      return;
    }
    final hasPressure = pts[2] >= 0;
    final vectors = <PointVector>[
      for (var i = 0; i + 2 < pts.length; i += 3)
        PointVector(pts[i], pts[i + 1], hasPressure ? pts[i + 2] : null),
    ];
    final path = StrokeGeometryCache.outlinePath(vectors, width,
        highlight: highlight,
        complete: false,
        pen: ctl.tool == EditorTool.shapes ? PenType.ball : ctl.penType);
    canvas.drawPath(path, Paint()..color = color);
    final m = palette.widthMultiplier;
    if (!highlight && m > 1.01) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = width * (m - 1),
      );
    }
  }

  void _paintLaser(Canvas canvas) {
    final trail = ctl.laser[pageId];
    if (trail == null || trail.length < 2) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final color = palette[InkRole.accent1];
    for (var i = 1; i < trail.length; i++) {
      final age = (now - trail[i].$2) / EditorController.laserLife;
      final a = (1 - age).clamp(0.0, 1.0);
      canvas.drawLine(
        trail[i - 1].$1,
        trail[i].$1,
        Paint()
          ..color = color.withValues(alpha: a)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(trail.last.$1, 7, Paint()..color = color);
  }

  @override
  bool shouldRepaint(LivePainter old) => old.palette != palette || old.pageId != pageId;
}

/// Lasso, cadre de sélection (tirets: visible sans la couleur), poignée de
/// redimensionnement et aperçu du déplacement.
class SelectionPainter extends CustomPainter {
  SelectionPainter(this.ctl, this.palette, this.content, this.profile);
  final EditorController ctl;
  final ResolvedPalette palette;
  final PageContent content;
  final VisualProfile profile;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette[InkRole.accent2]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (ctl.lasso.length > 1) {
      final path = Path()..addPolygon(ctl.lasso, false);
      canvas.drawPath(dashPath(path, StrokePattern.dashed, 2), paint);
    }
    var b = ctl.selectionBounds;
    if (b == null) return;
    if (ctl.dragging) {
      final els = ctl.selectedElements;
      final strokes = els.whereType<InkStroke>().where((s) => !s.highlight).toList();
      final highlights = els.whereType<InkStroke>().where((s) => s.highlight).toList();
      canvas.save();
      if (ctl.dragScale != 1) {
        canvas.translate(b.left, b.top);
        canvas.scale(ctl.dragScale);
        canvas.translate(-b.left, -b.top);
        b = Rect.fromLTWH(b.left, b.top, b.width * ctl.dragScale, b.height * ctl.dragScale);
      } else {
        canvas.translate(ctl.dragDelta.dx, ctl.dragDelta.dy);
        b = b.shift(ctl.dragDelta);
      }
      paintHighlights(canvas, palette, highlights, ctl.geometry);
      paintStrokes(canvas, palette, strokes, ctl.geometry);
      for (final t in els.whereType<TextBlock>()) {
        final tp = TextPainter(
          text: TextSpan(
            text: t.text,
            style: TextStyle(
              color: palette[t.role],
              fontSize: t.size * profile.text.sizeMultiplier,
              fontFamily: profile.text.font.family,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: t.width);
        tp.paint(canvas, Offset(t.x, t.y));
      }
      for (final i in els.whereType<PageImage>()) {
        canvas.drawRect(i.bounds, paint);
      }
      canvas.restore();
    }
    final frame = RRect.fromRectAndRadius(b.inflate(10), const Radius.circular(6));
    canvas.drawPath(dashPath(Path()..addRRect(frame), StrokePattern.dashed, 2), paint);
    final handle = b.inflate(10).bottomRight;
    canvas.drawCircle(handle, 11, Paint()..color = palette.paper);
    canvas.drawCircle(handle, 11, paint);
    canvas.drawLine(handle + const Offset(-5, 5), handle + const Offset(5, -5), paint);
  }

  @override
  bool shouldRepaint(SelectionPainter old) => true;
}
