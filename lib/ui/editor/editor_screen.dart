import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:provider/provider.dart';

import '../../core/profiles/palette.dart';
import '../../core/profiles/presets.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/render/page_painter.dart';
import '../../core/render/stroke_geometry.dart';
import '../../core/roles.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../data/sync_service.dart';
import '../../l10n/app_localizations.dart';
import '../../services/asset_renderer.dart';
import '../../services/export_service.dart';
import '../../services/ocr/ocr_service.dart';
import '../../services/profile_controller.dart';
import '../../services/speech_service.dart';
import '../library/import_actions.dart';
import '../share/share_dialog.dart';
import '../widgets/profile_pill.dart';
import 'document_filter_sheet.dart';
import 'editor_controller.dart';
import 'editor_toolbar.dart';
import 'text_dialog.dart';

/// Éditeur de note: page, barre d'outils (stylet, texte, surligneur,
/// gomme), bouton profil toujours visible (section 7).
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.notebookId, this.initialPageId});

  final String notebookId;
  final String? initialPageId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController ctl;
  late final SyncService _sync;
  final TransformationController _view = TransformationController();
  String? _fittedFor;
  bool _showOriginal = false;
  bool _showOcrText = false;
  ui.Image? _lastImage;
  String? _lastImageKey;
  bool _stylusDown = false;
  final Set<int> _pointers = {};
  Offset? _tapDown;

  @override
  void initState() {
    super.initState();
    final repo = context.read<NotesRepository>();
    final pages = repo.pagesOf(widget.notebookId);
    final initial = widget.initialPageId == null
        ? 0
        : pages.indexWhere((p) => p.id == widget.initialPageId).clamp(0, 1 << 20);
    ctl = EditorController(repo, widget.notebookId, initialPage: initial)
      ..addListener(_onCtl)
      ..load();
    _sync = context.read<SyncService>()..watchNotebook(widget.notebookId);
  }

  void _onCtl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ctl.removeListener(_onCtl);
    ctl.dispose();
    _view.dispose();
    _sync.watchNotebook(null);
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Entrées
  // ------------------------------------------------------------------

  bool _drawsWith(PointerEvent e) {
    final finger = context.read<NotesRepository>().settings.fingerDrawing;
    if (e.kind == PointerDeviceKind.touch && !finger) return false;
    // Souris: bouton principal seulement (au relâchement, aucun bouton
    // n'est plus enfoncé).
    if (e.kind == PointerDeviceKind.mouse &&
        e is! PointerUpEvent &&
        e is! PointerCancelEvent &&
        e.buttons != kPrimaryMouseButton) {
      return false;
    }
    return true;
  }

  static double? _pressure(PointerEvent e) {
    if (e.kind != PointerDeviceKind.stylus &&
        e.kind != PointerDeviceKind.invertedStylus) {
      return null;
    }
    final range = e.pressureMax - e.pressureMin;
    if (range <= 0) return null;
    return ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0);
  }

  void _onDown(PointerDownEvent e) {
    _pointers.add(e.pointer);
    if (e.kind == PointerDeviceKind.stylus ||
        e.kind == PointerDeviceKind.invertedStylus) {
      setState(() => _stylusDown = true);
    }
    if (_pointers.length > 1) {
      // Deuxième doigt: zoom / défilement, pas de dessin.
      if (ctl.hasLiveStroke) ctl.strokeCancel();
      return;
    }
    if (!_drawsWith(e)) return;
    final p = e.localPosition;
    _tapDown = p;
    final tool = e.kind == PointerDeviceKind.invertedStylus
        ? EditorTool.eraser
        : ctl.tool;
    switch (tool) {
      case EditorTool.pen:
      case EditorTool.highlighter:
        ctl.strokeStart(e.pointer, p, _pressure(e));
      case EditorTool.eraser:
        ctl.eraseAt(p);
      case EditorTool.select:
        ctl.selectStart(p);
      case EditorTool.text:
      case EditorTool.hand:
        break;
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (_pointers.length > 1 || !_drawsWith(e)) return;
    final p = e.localPosition;
    final tool = e.kind == PointerDeviceKind.invertedStylus
        ? EditorTool.eraser
        : ctl.tool;
    switch (tool) {
      case EditorTool.pen:
      case EditorTool.highlighter:
        ctl.strokeExtend(e.pointer, p, _pressure(e));
      case EditorTool.eraser:
        ctl.eraseAt(p);
      case EditorTool.select:
        ctl.selectUpdate(p);
      case EditorTool.text:
      case EditorTool.hand:
        break;
    }
  }

  void _onUp(PointerEvent e) {
    final wasMulti = _pointers.length > 1;
    _pointers.remove(e.pointer);
    if (_stylusDown &&
        (e.kind == PointerDeviceKind.stylus ||
            e.kind == PointerDeviceKind.invertedStylus)) {
      setState(() => _stylusDown = false);
    }
    if (wasMulti || !_drawsWith(e)) return;
    final tool = e.kind == PointerDeviceKind.invertedStylus
        ? EditorTool.eraser
        : ctl.tool;
    switch (tool) {
      case EditorTool.pen:
      case EditorTool.highlighter:
        if (e is PointerCancelEvent) {
          ctl.strokeCancel();
        } else {
          ctl.strokeEnd(e.pointer);
        }
      case EditorTool.eraser:
        ctl.eraseEnd();
      case EditorTool.select:
        ctl.selectEnd();
      case EditorTool.text:
        final down = _tapDown;
        if (down != null && (e.localPosition - down).distance < 12) {
          _editTextAt(e.localPosition);
        }
      case EditorTool.hand:
        break;
    }
    _tapDown = null;
  }

  Future<void> _editTextAt(Offset p) async {
    final existing = ctl.textAt(p);
    final result = await showTextBlockDialog(
      context,
      initialText: existing?.text ?? '',
      initialRole: existing?.role ?? ctl.inkRole,
      initialSize: existing?.size ?? 16,
    );
    if (result == null) return;
    if (existing != null) {
      if (result.delete) {
        await ctl.deleteText(existing);
      } else {
        await ctl.updateText(existing,
            text: result.text, role: result.role, size: result.size);
      }
    } else if (!result.delete) {
      await ctl.addText(p, result.text, result.role, result.size);
    }
  }

  // ------------------------------------------------------------------
  // Vue
  // ------------------------------------------------------------------

  void _fit(NotePage page, VisualProfile profile, Size viewport) {
    final key = '${page.id}|${profile.text.defaultZoom}|${viewport.width.round()}';
    if (_fittedFor == key) return;
    _fittedFor = key;
    final fit = ((viewport.width - 24) / page.width).clamp(0.2, 3.0);
    final s = fit * profile.text.defaultZoom;
    final dx = ((viewport.width - page.width * s) / 2).clamp(-double.infinity, 12.0);
    _view.value = Matrix4.identity()
      ..translateByDouble(dx < 12 ? 12 : dx, 12, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = context.watch<NotesRepository>();
    final pc = context.watch<ProfileController>();
    final notebook = repo.notebook(widget.notebookId);
    if (notebook == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.notebookMissing)));
    }
    final profile = pc.profileFor(notebook);
    final palette = pc.paletteOf(profile);
    final page = ctl.page;
    final simplified = profile.simplifiedUi;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): ctl.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): ctl.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): ctl.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): ctl.redo,
        const SingleActivator(LogicalKeyboardKey.delete): ctl.deleteSelection,
        const SingleActivator(LogicalKeyboardKey.backspace): ctl.deleteSelection,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Semantics(
              header: true,
              child: Text(notebook.title, overflow: TextOverflow.ellipsis),
            ),
            actions: [
              IconButton(
                tooltip: l.undo,
                onPressed: ctl.canUndo ? ctl.undo : null,
                icon: const Icon(Icons.undo),
              ),
              if (!simplified)
                IconButton(
                  tooltip: l.redo,
                  onPressed: ctl.canRedo ? ctl.redo : null,
                  icon: const Icon(Icons.redo),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ProfilePill(notebook: notebook),
              ),
              _menu(context, notebook, page, profile),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EditorToolbar(controller: ctl, palette: palette, simplified: simplified),
              Expanded(
                child: page == null
                    ? const SizedBox.shrink()
                    : LayoutBuilder(builder: (context, c) {
                        _fit(page, profile, c.biggest);
                        return _canvas(context, page, profile, palette, repo);
                      }),
              ),
              _pageBar(context, l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvas(BuildContext context, NotePage page, VisualProfile profile,
      ResolvedPalette palette, NotesRepository repo) {
    final l = AppLocalizations.of(context);
    final finger = repo.settings.fingerDrawing;
    final panEnabled = !_stylusDown &&
        (ctl.tool == EditorTool.hand || !finger || ctl.tool == EditorTool.text);
    final asset = repo.asset(page.assetId);
    final fontScale = profile.text.sizeMultiplier;
    final ocrMode = _showOcrText && page.ocrText != null;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: ClipRect(
        child: InteractiveViewer(
          transformationController: _view,
          constrained: false,
          minScale: 0.3,
          maxScale: 6,
          boundaryMargin: const EdgeInsets.all(400),
          panEnabled: panEnabled,
          child: SizedBox(
            width: page.width,
            height: page.height,
            child: Semantics(
              label: l.pageSemantics(ctl.pageIndex + 1, ctl.pages.length),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: asset == null || ocrMode
                          ? CustomPaint(
                              painter: PageBackgroundPainter(
                                  palette: palette, template: page.template))
                          : _assetLayer(context, asset, page, profile, palette),
                    ),
                  ),
                  if (ocrMode)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Text(
                          page.ocrText!,
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 16 * fontScale,
                            height: profile.text.lineHeight,
                            fontFamily: profile.text.font.family,
                          ),
                        ),
                      ),
                    ),
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
                            strokes: ctl.strokes,
                            highlights: ctl.highlights,
                            cache: ctl.geometry,
                            version: ctl.version,
                            hidden: ctl.dragging ? ctl.selection : const {},
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final t in ctl.texts)
                    Positioned(
                      left: t.x + (ctl.dragging && ctl.selection.contains(t.id) ? ctl.dragDelta.dx : 0),
                      top: t.y + (ctl.dragging && ctl.selection.contains(t.id) ? ctl.dragDelta.dy : 0),
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
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _OverlayPainter(ctl, palette),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _LiveStrokePainter(ctl, palette),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Listener(
                      key: const ValueKey('page-input'),
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _onDown,
                      onPointerMove: _onMove,
                      onPointerUp: _onUp,
                      onPointerCancel: _onUp,
                    ),
                  ),
                  if (ctl.loading)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _assetLayer(BuildContext context, ImportedAsset asset, NotePage page,
      VisualProfile profile, ResolvedPalette palette) {
    final renderer = context.read<AssetRenderer>();
    final key = '${asset.id}#${page.assetPage}#${AssetRenderer.profileKey(profile)}'
        '#${asset.filter.cacheKey}#$_showOriginal';
    return FutureBuilder<ui.Image?>(
      future: renderer.pageImage(asset, page.assetPage ?? 1, profile,
          original: _showOriginal),
      builder: (context, snap) {
        if (snap.hasData) {
          _lastImage = snap.data;
          _lastImageKey = key;
        }
        final img = snap.data ?? (_lastImageKey?.startsWith(asset.id) == true ? _lastImage : null);
        if (snap.connectionState == ConnectionState.done && snap.data == null) {
          return Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PageBackgroundPainter(
                    palette: palette, template: PageTemplate.blank),
              ),
            ),
            Center(child: Text(AppLocalizations.of(context).assetUnavailable)),
          ]);
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: CustomPaint(
            key: ValueKey(img),
            size: page.size,
            painter: PageBackgroundPainter(
              palette: palette,
              template: PageTemplate.blank,
              image: img,
            ),
          ),
        );
      },
    );
  }

  Widget _pageBar(BuildContext context, AppLocalizations l) {
    final n = ctl.pages.length;
    final i = ctl.pageIndex;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: l.previousPage,
              onPressed: i > 0 ? () => ctl.goToPage(i - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  child: Text(l.pageOf(i + 1, n)),
                ),
              ),
            ),
            IconButton(
              tooltip: l.nextPage,
              onPressed: i < n - 1 ? () => ctl.goToPage(i + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: l.addPage,
              onPressed: () => ctl.addPage(),
              icon: const Icon(Icons.note_add_outlined),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Menu
  // ------------------------------------------------------------------

  Widget _menu(BuildContext context, Notebook notebook, NotePage? page,
      VisualProfile profile) {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final speech = context.watch<SpeechService>();
    final ocr = context.read<OcrService>();
    final asset = repo.asset(page?.assetId);
    final sync = context.read<SyncService>();
    return PopupMenuButton<String>(
      tooltip: l.moreActions,
      icon: const Icon(Icons.more_vert),
      onSelected: (v) => _onMenu(v, notebook, page, profile),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'export_normal', child: _item(Icons.picture_as_pdf_outlined, l.exportNormal)),
        PopupMenuItem(value: 'export_profile', child: _item(Icons.palette_outlined, l.exportInProfile)),
        if (sync.enabled && !repo.isShared(notebook))
          PopupMenuItem(value: 'share', child: _item(Icons.group_add_outlined, l.shareNotebook)),
        PopupMenuItem(
          value: speech.speaking ? 'stop_reading' : 'read',
          child: _item(speech.speaking ? Icons.stop_circle_outlined : Icons.record_voice_over_outlined,
              speech.speaking ? l.stopReading : l.readAloud),
        ),
        if (ocr.available && page != null)
          PopupMenuItem(value: 'ocr', child: _item(Icons.document_scanner_outlined, l.recognizeText)),
        if (page?.ocrText != null)
          CheckedPopupMenuItem(value: 'ocr_text', checked: _showOcrText, child: Text(l.showRecognizedText)),
        if (asset != null)
          CheckedPopupMenuItem(value: 'original', checked: _showOriginal, child: Text(l.showOriginal)),
        if (asset != null)
          PopupMenuItem(value: 'filter', child: _item(Icons.filter_b_and_w_outlined, l.documentFilter)),
        PopupMenuItem(value: 'import', child: _item(Icons.upload_file_outlined, l.importIntoNotebook)),
        if (asset == null)
          PopupMenuItem(value: 'template', child: _item(Icons.grid_on_outlined, l.pageTemplate)),
        PopupMenuItem(value: 'delete_page', child: _item(Icons.delete_outline, l.deletePage)),
      ],
    );
  }

  Widget _item(IconData icon, String text) => Row(children: [
        Icon(icon),
        const SizedBox(width: 12),
        Flexible(child: Text(text)),
      ]);

  Future<void> _onMenu(String v, Notebook notebook, NotePage? page,
      VisualProfile profile) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final export = ExportService(repo, context.read<AssetRenderer>());
    final messenger = ScaffoldMessenger.of(context);
    switch (v) {
      case 'export_normal':
        await _guard(() => export.shareNotebookPdf(notebook));
      case 'export_profile':
        await _guard(() => export.shareNotebookPdf(notebook, profile: profile));
      case 'share':
        await showShareDialog(context, notebook);
      case 'read':
        await context.read<SpeechService>().speak(_pageText(page),
            languageCode: Localizations.localeOf(context).languageCode);
      case 'stop_reading':
        await context.read<SpeechService>().stopSpeaking();
      case 'ocr':
        if (page != null) await _runOcr(page);
      case 'ocr_text':
        setState(() => _showOcrText = !_showOcrText);
      case 'original':
        setState(() => _showOriginal = !_showOriginal);
      case 'filter':
        final asset = repo.asset(page?.assetId);
        if (asset != null) await showDocumentFilterSheet(context, asset);
      case 'import':
        await importDocument(context, into: notebook);
        await ctl.load();
      case 'template':
        final t = await showDialog<PageTemplate>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(l.pageTemplate),
            children: [
              for (final t in PageTemplate.values)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(templateLabel(l, t)),
                  ),
                ),
            ],
          ),
        );
        if (t != null) await ctl.setTemplate(t);
      case 'delete_page':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.deletePage),
            content: Text(l.deletePageConfirm),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.delete)),
            ],
          ),
        );
        if (ok == true) await ctl.deleteCurrentPage();
    }
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
  }

  Future<void> _guard(Future<void> Function() f) async {
    final l = AppLocalizations.of(context);
    try {
      await f();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorGeneric('$e'))));
      }
    }
  }

  String _pageText(NotePage? page) {
    final texts = [...ctl.texts]..sort((a, b) {
        final dy = a.y.compareTo(b.y);
        return dy != 0 ? dy : a.x.compareTo(b.x);
      });
    return [
      for (final t in texts) t.text,
      if (page?.ocrText != null) page!.ocrText!,
    ].join('\n');
  }

  /// OCR sur l'appareil: page de PDF/image, ou écriture manuscrite rendue
  /// en noir sur blanc.
  Future<void> _runOcr(NotePage page) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final ocr = context.read<OcrService>();
    final renderer = context.read<AssetRenderer>();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l.ocrRunning)));
    ui.Image? image;
    final asset = repo.asset(page.assetId);
    if (asset != null) {
      image = await renderer.pageImage(asset, page.assetPage ?? 1, Presets.standard,
          original: true);
    } else {
      image = await _renderPageForOcr(page);
    }
    final png = await image?.toByteData(format: ui.ImageByteFormat.png);
    final text = png == null ? null : await ocr.recognizePng(png.buffer.asUint8List());
    messenger.hideCurrentSnackBar();
    if (text == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.ocrFailed)));
      return;
    }
    await repo.updatePage(repo.page(page.id)!.copyWith(ocrText: text));
    if (!mounted) return;
    setState(() => _showOcrText = asset != null);
    messenger.showSnackBar(SnackBar(content: Text(l.ocrDone)));
  }

  Future<ui.Image> _renderPageForOcr(NotePage page) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final palette = ResolvedPalette.of(Presets.standard);
    canvas.drawRect(Offset.zero & page.size, Paint()..color = palette.paper);
    paintStrokes(canvas, palette, ctl.strokes, ctl.geometry);
    return recorder.endRecording().toImage(page.width.round(), page.height.round());
  }
}

String templateLabel(AppLocalizations l, PageTemplate t) => switch (t) {
      PageTemplate.blank => l.templateBlank,
      PageTemplate.lined => l.templateLined,
      PageTemplate.grid => l.templateGrid,
      PageTemplate.dotted => l.templateDotted,
    };

/// Trait en cours, redessiné à chaque point sans toucher aux autres couches.
class _LiveStrokePainter extends CustomPainter {
  _LiveStrokePainter(this.ctl, this.palette) : super(repaint: ctl.liveVersion);

  final EditorController ctl;
  final ResolvedPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = ctl.live;
    if (pts.isEmpty) return;
    final highlight = ctl.tool == EditorTool.highlighter;
    final hasPressure = pts[2] >= 0;
    final vectors = <PointVector>[
      for (var i = 0; i + 2 < pts.length; i += 3)
        PointVector(pts[i], pts[i + 1], hasPressure ? pts[i + 2] : null),
    ];
    final width = highlight ? ctl.highlighterWidth : ctl.penWidth;
    final path = StrokeGeometryCache.outlinePath(vectors, width,
        highlight: highlight, complete: false);
    final color = highlight
        ? palette.highlight(ctl.highlightRole)
        : palette[ctl.inkRole];
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

  @override
  bool shouldRepaint(_LiveStrokePainter old) => old.palette != palette;
}

/// Rectangle de sélection et cadre des éléments sélectionnés (tirets:
/// visible sans dépendre de la couleur).
class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.ctl, this.palette);
  final EditorController ctl;
  final ResolvedPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette[InkRole.accent2]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = ctl.selectionRect;
    if (r != null) {
      canvas.drawPath(
          dashPath(Path()..addRect(r), StrokePattern.dashed, 2), paint);
    }
    var b = ctl.selectionBounds;
    if (b != null) {
      if (ctl.dragging) {
        b = b.shift(ctl.dragDelta);
        final ghost = ctl.strokes.where((s) => ctl.selection.contains(s.id)).toList();
        canvas.save();
        canvas.translate(ctl.dragDelta.dx, ctl.dragDelta.dy);
        paintStrokes(canvas, palette, ghost, ctl.geometry);
        paintHighlights(canvas, palette,
            ctl.highlights.where((s) => ctl.selection.contains(s.id)).toList(),
            ctl.geometry);
        canvas.restore();
      }
      canvas.drawPath(
          dashPath(Path()..addRRect(RRect.fromRectAndRadius(b.inflate(8), const Radius.circular(6))),
              StrokePattern.dashed, 2),
          paint);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}
