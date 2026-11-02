import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/render/page_painter.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/asset_renderer.dart';
import '../../services/profile_controller.dart';
import '../library/import_actions.dart';
import 'editor_controller.dart';
import 'notebook_canvas.dart';

String templateLabel(AppLocalizations l, PageTemplate t) => switch (t) {
      PageTemplate.blank => l.templateBlank,
      PageTemplate.lined => l.templateLined,
      PageTemplate.narrow => l.templateNarrow,
      PageTemplate.grid => l.templateGrid,
      PageTemplate.dotted => l.templateDotted,
      PageTemplate.cornell => l.templateCornell,
    };

/// Petite question texte (titre, renommage…).
Future<String?> askText(BuildContext context, String title, String initial) {
  final l = AppLocalizations.of(context);
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(l.ok)),
      ],
    ),
  );
}

/// « Aller à la page »: retourne l'index (0 = première page).
Future<int?> showGoToPage(BuildContext context, int count) {
  final l = AppLocalizations.of(context);
  final c = TextEditingController();
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      void submit() {
        final n = int.tryParse(c.text.trim());
        if (n != null && n >= 1 && n <= count) Navigator.pop(ctx, n - 1);
      }

      return AlertDialog(
        title: Text(l.goToPage),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(helperText: '1 – $count'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: submit, child: Text(l.ok)),
        ],
      );
    },
  );
}

/// Aperçu d'un gabarit dans les couleurs du profil.
class TemplatePreview extends StatelessWidget {
  const TemplatePreview({super.key, required this.template, this.landscape = false});
  final PageTemplate template;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ProfileController>().palette;
    final size = landscape ? const Size(1131, 800) : const Size(800, 1131);
    return AspectRatio(
      aspectRatio: size.width / size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: FittedBox(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(
              painter: PageBackgroundPainter(
                  palette: palette, template: template, lineWidth: 6),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Ajouter une page »: avant, après ou à la fin; gabarit; format;
/// image ou document importé.
Future<void> showAddPageSheet(
    BuildContext context, EditorController ctl, CanvasViewController view) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddPageSheet(ctl: ctl, view: view),
  );
}

class _AddPageSheet extends StatefulWidget {
  const _AddPageSheet({required this.ctl, required this.view});
  final EditorController ctl;
  final CanvasViewController view;

  @override
  State<_AddPageSheet> createState() => _AddPageSheetState();
}

class _AddPageSheetState extends State<_AddPageSheet> {
  PageInsert _where = PageInsert.after;
  bool _landscape = false;

  Future<void> _add(PageTemplate t) async {
    final p = await widget.ctl.addPage(
      template: t,
      where: _where,
      format: _landscape ? PageFormat.landscape : PageFormat.portrait,
    );
    if (!mounted) return;
    Navigator.pop(context);
    widget.view.jumpToPage(widget.ctl.pages.indexWhere((x) => x.id == p.id));
  }

  Future<void> _imagePage() async {
    final ctl = widget.ctl;
    final repo = ctl.repo;
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final bytes = await files.first.xFile.readAsBytes();
    final size = await AssetRenderer.imageSize(bytes);
    final page = await ctl.addPage(template: PageTemplate.blank, where: _where);
    final asset = await repo.createImageAsset(ctl.notebookId, bytes, files.first.name);
    await ctl.ensureLoadedNow(page.id);
    await ctl.addImage(page.id, asset, Size(size.width, size.height),
        center: Offset(page.width / 2, page.height / 2));
    if (!mounted) return;
    Navigator.pop(context);
    widget.view.jumpToPage(ctl.pages.indexWhere((x) => x.id == page.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final current = widget.ctl.currentPage;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(l.addPage, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<PageInsert>(
              segments: [
                ButtonSegment(value: PageInsert.before, label: Text(l.insertBefore)),
                ButtonSegment(value: PageInsert.after, label: Text(l.insertAfter)),
                ButtonSegment(value: PageInsert.last, label: Text(l.insertLast)),
              ],
              selected: {_where},
              onSelectionChanged: (s) => setState(() => _where = s.first),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.portrait), icon: const Icon(Icons.crop_portrait)),
                ButtonSegment(value: true, label: Text(l.landscape), icon: const Icon(Icons.crop_landscape)),
              ],
              selected: {_landscape},
              onSelectionChanged: (s) => setState(() => _landscape = s.first),
            ),
            const SizedBox(height: 16),
            Text(l.templates, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            GridView.extent(
              maxCrossAxisExtent: 130,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: _landscape ? 1.1 : 0.62,
              children: [
                for (final t in PageTemplate.values)
                  Semantics(
                    button: true,
                    selected: current?.template == t && current?.assetId == null,
                    label: templateLabel(l, t),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => _add(t),
                      child: Column(children: [
                        Expanded(child: TemplatePreview(template: t, landscape: _landscape)),
                        const SizedBox(height: 4),
                        Text(
                          current?.template == t && current?.assetId == null
                              ? '${templateLabel(l, t)} ✓'
                              : templateLabel(l, t),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l.imagePage),
              onTap: _imagePage,
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l.importPdfOrImage),
              onTap: () async {
                final nb = widget.ctl.repo.notebook(widget.ctl.notebookId);
                Navigator.pop(context);
                await importDocument(context, into: nb, at: current, where: _where);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu d'une page: signet, plan, dupliquer, gabarit, aller à, défilement,
/// effacer, corbeille.
Future<void> showPageMenu(BuildContext context, EditorController ctl,
    CanvasViewController view, NotePage page) {
  final l = AppLocalizations.of(context);
  final repo = context.read<NotesRepository>();
  final index = ctl.pages.indexWhere((p) => p.id == page.id);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l.pageNumber(index + 1),
                  style: Theme.of(sheet).textTheme.titleLarge),
            ),
            ListTile(
              leading: Icon(page.bookmarked ? Icons.bookmark : Icons.bookmark_outline),
              title: Text(page.bookmarked ? l.removeBookmark : l.addBookmark),
              onTap: () {
                Navigator.pop(sheet);
                repo.updatePage(page.copyWith(bookmarked: !page.bookmarked));
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_list_bulleted),
              title: Text(page.outlineTitle == null ? l.addToOutline : l.renameInOutline),
              onTap: () async {
                Navigator.pop(sheet);
                final title = await askText(context, l.outlineTitle,
                    page.outlineTitle ?? l.pageNumber(index + 1));
                if (title == null) return;
                await repo.updatePage(title.isEmpty
                    ? page.copyWith(clearOutline: true)
                    : page.copyWith(outlineTitle: title));
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: Text(l.duplicatePage),
              onTap: () async {
                Navigator.pop(sheet);
                final copy = await ctl.duplicatePage(page);
                view.jumpToPage(ctl.pages.indexWhere((p) => p.id == copy.id));
              },
            ),
            if (page.assetId == null)
              ListTile(
                leading: const Icon(Icons.grid_on_outlined),
                title: Text(l.changeTemplate),
                onTap: () async {
                  Navigator.pop(sheet);
                  final t = await showDialog<PageTemplate>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: Text(l.changeTemplate),
                      children: [
                        for (final t in PageTemplate.values)
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, t),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(t == page.template
                                  ? '${templateLabel(l, t)} ✓'
                                  : templateLabel(l, t)),
                            ),
                          ),
                      ],
                    ),
                  );
                  if (t != null) await ctl.setTemplate(page, t);
                },
              ),
            ListTile(
              leading: const Icon(Icons.input),
              title: Text(l.goToPage),
              trailing: Text('1 – ${ctl.pages.length}'),
              onTap: () async {
                Navigator.pop(sheet);
                final i = await showGoToPage(context, ctl.pages.length);
                if (i != null) view.jumpToPage(i);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.swap_vert),
              title: Text(l.scrollHorizontal),
              value: repo.settings.scrollHorizontal,
              onChanged: (v) {
                Navigator.pop(sheet);
                repo.updateSettings(repo.settings.copyWith(scrollHorizontal: v));
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.layers_clear_outlined, color: Theme.of(sheet).colorScheme.error),
              title: Text(l.clearPage),
              onTap: () async {
                Navigator.pop(sheet);
                if (await _confirm(context, l.clearPage, l.clearPageConfirm)) {
                  await ctl.clearPage(page);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(sheet).colorScheme.error),
              title: Text(l.deletePage),
              onTap: () async {
                Navigator.pop(sheet);
                if (await _confirm(context, l.deletePage, l.deletePageConfirm)) {
                  await ctl.deletePage(page);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> _confirm(BuildContext context, String title, String text) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.ok)),
          ],
        ),
      ) ??
      false;
}

/// Recherche dans le document: texte tapé, texte reconnu (OCR) et plan.
/// Retourne l'index de la page choisie.
Future<int?> showDocumentSearch(BuildContext context, EditorController ctl) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DocSearch(ctl: ctl),
  );
}

class _DocSearch extends StatefulWidget {
  const _DocSearch({required this.ctl});
  final EditorController ctl;

  @override
  State<_DocSearch> createState() => _DocSearchState();
}

class _DocSearchState extends State<_DocSearch> {
  final _q = TextEditingController();
  List<(int, String)> _hits = [];
  bool _busy = false;

  Future<void> _search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _hits = []);
      return;
    }
    setState(() => _busy = true);
    final pages = widget.ctl.pages;
    final hits = <(int, String)>[];
    for (var i = 0; i < pages.length; i++) {
      final p = pages[i];
      final c = widget.ctl.content(p.id) ?? await widget.ctl.repo.loadPage(p);
      for (final text in [
        if (p.outlineTitle != null) p.outlineTitle!,
        ...c.texts.map((t) => t.text),
        if (p.ocrText != null) p.ocrText!,
      ]) {
        final at = text.toLowerCase().indexOf(q);
        if (at >= 0) {
          final start = (at - 30).clamp(0, text.length);
          final end = (at + q.length + 30).clamp(0, text.length);
          hits.add((i, text.substring(start, end).replaceAll('\n', ' ')));
        }
      }
    }
    if (!mounted || _q.text.trim().toLowerCase() != q) return;
    setState(() {
      _hits = hits;
      _busy = false;
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.searchInDocument,
                  ),
                  onChanged: _search,
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (!_busy && _q.text.trim().isNotEmpty && _hits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.noResults, textAlign: TextAlign.center),
                      ),
                    for (final (i, snippet) in _hits)
                      ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(context, i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
