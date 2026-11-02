import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/profiles/palette.dart';
import '../../core/profiles/presets.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/render/page_painter.dart';
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
import '../widgets/profile_names.dart';
import '../widgets/profile_pill.dart';
import 'document_filter_sheet.dart';
import 'editor_controller.dart';
import 'editor_toolbar.dart';
import 'notebook_canvas.dart';
import 'open_tabs.dart';
import 'page_menus.dart';
import 'pages_panel.dart';
import 'text_dialog.dart';

/// Ouvre un cahier dans un onglet de l'éditeur.
Future<void> openNotebook(BuildContext context, String notebookId,
    {String? pageId}) async {
  final tabs = context.read<OpenTabs>();
  tabs.open(notebookId, pageId: pageId);
  if (ModalRoute.of(context)?.settings.name != EditorShell.routeName) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: EditorShell.routeName),
        builder: (_) => const EditorShell(),
      ),
    );
  }
}

/// Onglets des documents ouverts + l'éditeur du document actif.
class EditorShell extends StatelessWidget {
  const EditorShell({super.key});

  static const routeName = '/editor';

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<OpenTabs>();
    final repo = context.watch<NotesRepository>();
    if (tabs.ids.any((id) => repo.notebook(id) == null)) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => tabs.retain((id) => repo.notebook(id) != null));
    }
    final active = tabs.active;
    if (active == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold();
    }
    return EditorScreen(
      key: ValueKey(active),
      notebookId: active,
      initialPageId: tabs.lastPage(active),
    );
  }
}

/// Éditeur de note: pages en défilement continu, barre d'outils, panneau
/// des pages, bouton profil toujours visible (section 7).
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
  late final OpenTabs _tabs;
  final CanvasViewController view = CanvasViewController();
  bool _panel = false;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    final repo = context.read<NotesRepository>();
    ctl = EditorController(repo, widget.notebookId,
        initialPageId: widget.initialPageId)
      ..addListener(_onCtl);
    _sync = context.read<SyncService>()..watchNotebook(widget.notebookId);
    _tabs = context.read<OpenTabs>();
  }

  void _onCtl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.rememberPage(widget.notebookId, ctl.currentPage?.id);
    ctl.removeListener(_onCtl);
    ctl.dispose();
    view.dispose();
    _sync.watchNotebook(null);
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  Future<void> _onTap(String pageId, Offset p) async {
    if (ctl.tool != EditorTool.text && ctl.tool != EditorTool.lasso) return;
    final existing = ctl.textAt(pageId, p);
    if (existing == null && ctl.tool != EditorTool.text) return;
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
      await ctl.addText(pageId, p, result.text, result.role, result.size);
    }
  }

  Future<void> _insertImage() async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final page = ctl.currentPage;
    if (page == null) return;
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    try {
      final bytes = await files.first.xFile.readAsBytes();
      final size = await AssetRenderer.imageSize(bytes);
      final asset = await repo.createImageAsset(widget.notebookId, bytes, files.first.name);
      await ctl.addImage(page.id, asset, Size(size.width, size.height));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.importFailed('$e'))));
    }
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

  // ------------------------------------------------------------------
  // Interface
  // ------------------------------------------------------------------

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
    final simplified = profile.simplifiedUi;
    final wide = MediaQuery.sizeOf(context).width > 700;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): ctl.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): ctl.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): ctl.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): ctl.redo,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): ctl.copySelection,
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true): ctl.copySelection,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true): ctl.cutSelection,
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true): ctl.cutSelection,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _paste,
        const SingleActivator(LogicalKeyboardKey.delete): ctl.deleteSelection,
        const SingleActivator(LogicalKeyboardKey.backspace): ctl.deleteSelection,
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            view.jumpToPage(ctl.currentIndex + 1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            view.jumpToPage(ctl.currentIndex - 1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DocumentTabsBar(),
                _topBar(context, l, notebook, profile, simplified),
                EditorToolbar(
                  controller: ctl,
                  palette: palette,
                  simplified: simplified,
                  onImage: _insertImage,
                  onPaste: EditorController.clipboard.isEmpty ? null : _paste,
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_panel)
                        SizedBox(
                          width: wide ? 260 : 200,
                          child: PagesPanel(
                            controller: ctl,
                            view: view,
                            profile: profile,
                            palette: palette,
                          ),
                        ),
                      if (_panel) const VerticalDivider(width: 1),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: NotebookCanvas(
                                controller: ctl,
                                view: view,
                                profile: profile,
                                palette: palette,
                                horizontal: repo.settings.scrollHorizontal,
                                fingerDrawing: repo.settings.fingerDrawing,
                                showOriginal: _showOriginal,
                                onTap: _onTap,
                              ),
                            ),
                            if (ctl.hasSelection && !ctl.dragging)
                              Positioned(
                                top: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _SelectionBar(controller: ctl, palette: palette),
                                ),
                              ),
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Center(child: _pageIndicator(context, l)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _paste() {
    final page = ctl.currentPage;
    if (page != null) ctl.paste(page.id);
  }

  Widget _topBar(BuildContext context, AppLocalizations l, Notebook notebook,
      VisualProfile profile, bool simplified) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              tooltip: l.library,
              icon: const Icon(Icons.home_outlined),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            IconButton(
              tooltip: l.pagesPanel,
              isSelected: _panel,
              icon: const Icon(Icons.view_sidebar_outlined),
              onPressed: () => setState(() => _panel = !_panel),
            ),
            IconButton(
              tooltip: l.searchInDocument,
              icon: const Icon(Icons.search),
              onPressed: () async {
                final i = await showDocumentSearch(context, ctl);
                if (i != null) view.jumpToPage(i);
              },
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: InkWell(
                  onTap: () async {
                    final name = await askText(context, l.rename, notebook.title);
                    if (name != null && name.isNotEmpty) {
                      await ctl.repo.updateNotebook(notebook.copyWith(title: name));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(notebook.title,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
              ),
            ),
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
            IconButton(
              tooltip: l.addPage,
              icon: const Icon(Icons.note_add_outlined),
              onPressed: () => showAddPageSheet(context, ctl, view),
            ),
            _shareMenu(context, l, notebook, profile),
            IconButton(
              tooltip: l.moreActions,
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                final page = ctl.currentPage;
                if (page != null) showPageMenu(context, ctl, view, page);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageIndicator(BuildContext context, AppLocalizations l) {
    return ValueListenableBuilder<int>(
      valueListenable: ctl.currentPageNotifier,
      builder: (context, _, _) {
        final n = ctl.pages.length;
        final i = ctl.currentIndex;
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: const StadiumBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () async {
              final target = await showGoToPage(context, n);
              if (target != null) view.jumpToPage(target);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(l.pageOf(i + 1, n)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _shareMenu(BuildContext context, AppLocalizations l, Notebook notebook,
      VisualProfile profile) {
    final repo = context.read<NotesRepository>();
    final speech = context.watch<SpeechService>();
    final ocr = context.read<OcrService>();
    final page = ctl.currentPage;
    final asset = repo.asset(page?.assetId);
    final sync = context.read<SyncService>();
    Widget item(IconData icon, String text) => Row(children: [
          Icon(icon),
          const SizedBox(width: 12),
          Flexible(child: Text(text)),
        ]);
    return PopupMenuButton<String>(
      tooltip: l.shareAndExport,
      icon: const Icon(Icons.ios_share),
      onSelected: (v) => _onShareMenu(v, notebook, profile),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'export_normal', child: item(Icons.picture_as_pdf_outlined, l.exportNormal)),
        PopupMenuItem(value: 'export_profile', child: item(Icons.palette_outlined, l.exportInProfile)),
        if (sync.enabled && !repo.isShared(notebook))
          PopupMenuItem(value: 'share', child: item(Icons.group_add_outlined, l.shareNotebook)),
        PopupMenuItem(
          value: speech.speaking ? 'stop_reading' : 'read',
          child: item(speech.speaking ? Icons.stop_circle_outlined : Icons.record_voice_over_outlined,
              speech.speaking ? l.stopReading : l.readAloud),
        ),
        if (ocr.available && page != null)
          PopupMenuItem(value: 'ocr', child: item(Icons.document_scanner_outlined, l.recognizeText)),
        if (page?.ocrText != null)
          PopupMenuItem(value: 'ocr_text', child: item(Icons.text_snippet_outlined, l.showRecognizedText)),
        if (asset != null)
          CheckedPopupMenuItem(value: 'original', checked: _showOriginal, child: Text(l.showOriginal)),
        if (asset != null)
          PopupMenuItem(value: 'filter', child: item(Icons.filter_b_and_w_outlined, l.documentFilter)),
        PopupMenuItem(value: 'import', child: item(Icons.upload_file_outlined, l.importIntoNotebook)),
      ],
    );
  }

  Future<void> _onShareMenu(String v, Notebook notebook, VisualProfile profile) async {
    final repo = context.read<NotesRepository>();
    final export = ExportService(repo, context.read<AssetRenderer>());
    final page = ctl.currentPage;
    switch (v) {
      case 'export_normal':
        await _guard(() => export.shareNotebookPdf(notebook));
      case 'export_profile':
        await _guard(() => export.shareNotebookPdf(notebook, profile: profile));
      case 'share':
        await showShareDialog(context, notebook);
      case 'read':
        final speech = context.read<SpeechService>();
        final lang = Localizations.localeOf(context).languageCode;
        await speech.speak(await _pageText(page), languageCode: lang);
      case 'stop_reading':
        await context.read<SpeechService>().stopSpeaking();
      case 'ocr':
        if (page != null) await _runOcr(page);
      case 'ocr_text':
        if (page?.ocrText != null) await _showRecognized(page!.ocrText!, profile);
      case 'original':
        setState(() => _showOriginal = !_showOriginal);
      case 'filter':
        final asset = repo.asset(page?.assetId);
        if (asset != null) await showDocumentFilterSheet(context, asset);
      case 'import':
        await importDocument(context, into: notebook, at: page);
    }
  }

  Future<String> _pageText(NotePage? page) async {
    if (page == null) return '';
    final c = ctl.content(page.id) ?? await ctl.repo.loadPage(page);
    final texts = [...c.texts]..sort((a, b) {
        final dy = a.y.compareTo(b.y);
        return dy != 0 ? dy : a.x.compareTo(b.x);
      });
    return [
      for (final t in texts) t.text,
      if (page.ocrText != null) page.ocrText!,
    ].join('\n');
  }

  /// Texte reconnu affiché en vrai texte recoloré (plus net que le filtre
  /// d'image), avec lecture à voix haute.
  Future<void> _showRecognized(String text, VisualProfile profile) {
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Row(children: [
                Expanded(child: Text(l.showRecognizedText, style: Theme.of(ctx).textTheme.titleLarge)),
                IconButton(
                  tooltip: l.readAloud,
                  icon: const Icon(Icons.record_voice_over_outlined),
                  onPressed: () => ctx.read<SpeechService>().speak(text,
                      languageCode: Localizations.localeOf(ctx).languageCode),
                ),
              ]),
              const SizedBox(height: 12),
              SelectableText(
                text,
                style: TextStyle(
                  fontSize: profile.text.baseSize,
                  height: profile.text.lineHeight,
                  fontFamily: profile.text.font.family,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      final c = ctl.content(page.id) ?? await repo.loadPage(page);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final palette = ResolvedPalette.of(Presets.standard);
      canvas.drawRect(Offset.zero & page.size, Paint()..color = palette.paper);
      paintStrokes(canvas, palette, c.strokes, ctl.geometry);
      image = await recorder.endRecording().toImage(page.width.round(), page.height.round());
    }
    final png = await image?.toByteData(format: ui.ImageByteFormat.png);
    final text = png == null ? null : await ocr.recognizePng(png.buffer.asUint8List());
    messenger.hideCurrentSnackBar();
    if (text == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.ocrFailed)));
      return;
    }
    await repo.updatePage(repo.page(page.id)!.copyWith(ocrText: text));
    messenger.showSnackBar(SnackBar(content: Text(l.ocrDone)));
  }
}

/// Barre flottante au-dessus d'une sélection au lasso.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.controller, required this.palette});
  final EditorController controller;
  final ResolvedPalette palette;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctl = controller;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(28),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(tooltip: l.copy, icon: const Icon(Icons.copy_outlined), onPressed: ctl.copySelection),
            IconButton(tooltip: l.cut, icon: const Icon(Icons.content_cut), onPressed: ctl.cutSelection),
            IconButton(tooltip: l.duplicate, icon: const Icon(Icons.control_point_duplicate), onPressed: ctl.duplicateSelection),
            PopupMenuButton<InkRole>(
              tooltip: l.changeInk,
              icon: const Icon(Icons.palette_outlined),
              onSelected: ctl.setSelectionRole,
              itemBuilder: (_) => [
                for (final r in [...InkRole.writingInks, ...InkRole.highlights])
                  PopupMenuItem(
                    value: r,
                    child: Row(children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: r.isHighlight
                            ? Color.alphaBlend(palette.highlight(r), palette.paper)
                            : palette[r],
                      ),
                      const SizedBox(width: 12),
                      Text(roleLabel(context, r)),
                    ]),
                  ),
              ],
            ),
            IconButton(tooltip: l.deleteSelection, icon: const Icon(Icons.delete_outline), onPressed: ctl.deleteSelection),
          ],
        ),
      ),
    );
  }
}

/// Barre des onglets de documents ouverts.
class DocumentTabsBar extends StatelessWidget {
  const DocumentTabsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<OpenTabs>();
    final repo = context.watch<NotesRepository>();
    final l = AppLocalizations.of(context);
    if (tabs.ids.length < 2) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final id in tabs.ids)
              Semantics(
                selected: id == tabs.active,
                button: true,
                child: InkWell(
                  onTap: () => tabs.activate(id),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 220, minWidth: 120),
                    padding: const EdgeInsets.only(left: 14),
                    decoration: BoxDecoration(
                      color: id == tabs.active ? scheme.surfaceContainerHigh : null,
                      border: Border(
                        bottom: BorderSide(
                          color: id == tabs.active ? scheme.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(repo.notebook(id)?.title ?? '',
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        tooltip: l.closeTab,
                        iconSize: 18,
                        icon: const Icon(Icons.close),
                        onPressed: () => tabs.close(id),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
