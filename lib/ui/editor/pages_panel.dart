import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profiles/palette.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/render/page_painter.dart';
import '../../core/render/stroke_geometry.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import 'editor_controller.dart';
import 'notebook_canvas.dart';
import 'page_menus.dart';

enum _PanelTab { pages, outline, bookmarks }

/// Panneau latéral: vignettes des pages (glisser pour réordonner), plan
/// du cahier et signets.
class PagesPanel extends StatefulWidget {
  const PagesPanel({
    super.key,
    required this.controller,
    required this.view,
    required this.profile,
    required this.palette,
  });

  final EditorController controller;
  final CanvasViewController view;
  final VisualProfile profile;
  final ResolvedPalette palette;

  @override
  State<PagesPanel> createState() => _PagesPanelState();
}

class _PagesPanelState extends State<PagesPanel> {
  _PanelTab _tab = _PanelTab.pages;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctl = widget.controller;
    final pages = ctl.pages;
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    switch (_tab) {
      case _PanelTab.pages:
        body = ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: pages.length,
          onReorderItem: (from, to) => ctl.repo.movePage(pages[from], to),
          itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
            key: ValueKey(pages[i].id),
            index: i,
            child: _ThumbTile(
              page: pages[i],
              index: i,
              selected: i == ctl.currentIndex,
              onTap: () => widget.view.jumpToPage(i),
              onMenu: () => showPageMenu(context, ctl, widget.view, pages[i]),
              controller: ctl,
              profile: widget.profile,
              palette: widget.palette,
            ),
          ),
        );
      case _PanelTab.outline:
        final outline = [
          for (var i = 0; i < pages.length; i++)
            if (pages[i].outlineTitle != null) (i, pages[i]),
        ];
        body = outline.isEmpty
            ? _empty(l.outlineEmpty)
            : ListView(children: [
                for (final (i, p) in outline)
                  ListTile(
                    title: Text(p.outlineTitle!),
                    trailing: Text('${i + 1}'),
                    onTap: () => widget.view.jumpToPage(i),
                    onLongPress: () => showPageMenu(context, ctl, widget.view, p),
                  ),
              ]);
      case _PanelTab.bookmarks:
        final marks = [
          for (var i = 0; i < pages.length; i++)
            if (pages[i].bookmarked) (i, pages[i]),
        ];
        body = marks.isEmpty
            ? _empty(l.bookmarksEmpty)
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final (i, p) in marks)
                    _ThumbTile(
                      page: p,
                      index: i,
                      selected: i == ctl.currentIndex,
                      onTap: () => widget.view.jumpToPage(i),
                      onMenu: () => showPageMenu(context, ctl, widget.view, p),
                      controller: ctl,
                      profile: widget.profile,
                      palette: widget.palette,
                    ),
                ],
              );
    }

    return Material(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<_PanelTab>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: _PanelTab.pages, tooltip: l.pages, icon: const Icon(Icons.description_outlined)),
                ButtonSegment(value: _PanelTab.outline, tooltip: l.outline, icon: const Icon(Icons.format_list_bulleted)),
                ButtonSegment(value: _PanelTab.bookmarks, tooltip: l.bookmarks, icon: const Icon(Icons.bookmark_outline)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _empty(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    required this.page,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onMenu,
    required this.controller,
    required this.profile,
    required this.palette,
  });

  final NotePage page;
  final int index;
  final bool selected;
  final VoidCallback onTap, onMenu;
  final EditorController controller;
  final VisualProfile profile;
  final ResolvedPalette palette;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: l.pageNumber(index + 1),
      child: InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: PageThumbnail(
                  page: page,
                  controller: controller,
                  profile: profile,
                  palette: palette,
                ),
              ),
              Row(children: [
                Text('${index + 1}'),
                if (page.bookmarked) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.bookmark, size: 16, color: scheme.primary),
                ],
                const Spacer(),
                IconButton(
                  tooltip: l.pageMenu,
                  iconSize: 20,
                  icon: const Icon(Icons.expand_more),
                  onPressed: onMenu,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vignette d'une page dans les couleurs du profil.
class PageThumbnail extends StatefulWidget {
  const PageThumbnail({
    super.key,
    required this.page,
    required this.profile,
    required this.palette,
    this.controller,
  });

  final NotePage page;
  final EditorController? controller;
  final VisualProfile profile;
  final ResolvedPalette palette;

  @override
  State<PageThumbnail> createState() => _PageThumbnailState();
}

class _PageThumbnailState extends State<PageThumbnail> {
  static final _geometry = StrokeGeometryCache();
  PageContent? _content;
  int _version = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(PageThumbnail old) {
    super.didUpdateWidget(old);
    if (old.page.id != widget.page.id) _load();
  }

  void _load() {
    final live = widget.controller?.content(widget.page.id);
    if (live != null) {
      _content = live;
      return;
    }
    context.read<NotesRepository>().loadPage(widget.page).then((c) {
      if (mounted) setState(() => _content = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.controller;
    final live = ctl?.content(widget.page.id);
    if (live != null) _content = live;
    final version = ctl?.versionOf(widget.page.id) ?? 0;
    if (version != _version) _version = version;
    final repo = context.read<NotesRepository>();
    final asset = repo.asset(widget.page.assetId);
    final page = widget.page;
    return AspectRatio(
      aspectRatio: page.width / page.height,
      child: FittedBox(
        child: SizedBox.fromSize(
          size: page.size,
          child: Stack(children: [
            Positioned.fill(
              child: asset == null
                  ? CustomPaint(
                      painter: PageBackgroundPainter(
                          palette: widget.palette, template: page.template))
                  : PdfLayer(
                      asset: asset,
                      page: page,
                      profile: widget.profile,
                      palette: widget.palette,
                      thumbnail: true,
                    ),
            ),
            if (_content != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: InkPainter(
                    palette: widget.palette,
                    strokes: _content!.strokes,
                    highlights: _content!.highlights,
                    cache: _geometry,
                    version: version,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
