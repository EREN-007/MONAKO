import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/roles.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../data/sync_service.dart';
import '../../l10n/app_localizations.dart';
import '../../services/asset_renderer.dart';
import '../../services/export_service.dart';
import '../../services/profile_controller.dart';
import '../editor/editor_screen.dart';
import '../editor/page_menus.dart';
import '../editor/pages_panel.dart';
import '../settings/settings_screen.dart';
import '../widgets/monako_logo.dart';
import '../widgets/profile_pill.dart';
import 'import_actions.dart';

enum LibrarySection { documents, favorites, shared, trash }

enum _Sort { recent, name }

/// Bibliothèque: dossiers, cahiers, favoris, partagés, corbeille,
/// recherche — recolorés par le profil.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibrarySection _section = LibrarySection.documents;
  String? _folderId;
  _Sort _sort = _Sort.recent;
  bool _list = false;
  bool _searching = false;
  final _search = TextEditingController();
  Future<List<SearchHit>>? _results;

  @override
  void initState() {
    super.initState();
    // Corbeille vidée définitivement après 30 jours.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotesRepository>().emptyTrash(olderThan: const Duration(days: 30));
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Notebook n, {NotePage? page}) =>
      openNotebook(context, n.id, pageId: page?.id);

  // ------------------------------------------------------------------
  // Création
  // ------------------------------------------------------------------

  Future<void> _newNotebook({NotebookKind kind = NotebookKind.notebook}) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    if (kind == NotebookKind.quicknote) {
      final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
          .add_Hm()
          .format(DateTime.now());
      final n = await repo.createNotebook(l.quickNoteTitle(date),
          folderId: _folderId, kind: kind, template: PageTemplate.lined);
      if (mounted) _open(n);
      return;
    }
    final spec = await showDialog<_NewNotebookSpec>(
      context: context,
      builder: (_) => _NewNotebookDialog(kind: kind),
    );
    if (spec == null || !mounted) return;
    final n = await repo.createNotebook(
      spec.title,
      folderId: _folderId,
      kind: kind,
      template: spec.template,
      format: spec.format,
      coverRole: spec.coverRole.key,
    );
    if (mounted) _open(n);
  }

  Future<void> _newFolder() async {
    final l = AppLocalizations.of(context);
    final name = await askText(context, l.newFolder, '');
    if (name == null || name.isEmpty || !mounted) return;
    await context.read<NotesRepository>().createFolder(name, parentId: _folderId);
  }

  Future<void> _import() async {
    final n = await importDocument(context, folderId: _folderId);
    if (n != null && mounted) _open(n);
  }

  // ------------------------------------------------------------------
  // Interface
  // ------------------------------------------------------------------

  String _title(AppLocalizations l, NotesRepository repo) {
    if (_section == LibrarySection.documents && _folderId != null) {
      return repo.folders.where((f) => f.id == _folderId).firstOrNull?.name ?? l.documents;
    }
    return switch (_section) {
      LibrarySection.documents => l.documents,
      LibrarySection.favorites => l.favorites,
      LibrarySection.shared => l.sharedWithMe,
      LibrarySection.trash => l.trash,
    };
  }

  List<Notebook> _notebooks(NotesRepository repo) {
    final List<Notebook> list = switch (_section) {
      LibrarySection.documents => _folderId == null
          ? repo.rootNotebooks
          : repo.notebooksIn(_folderId),
      LibrarySection.favorites => repo.favoriteNotebooks,
      LibrarySection.shared => repo.sharedNotebooks,
      LibrarySection.trash => repo.trashedNotebooks,
    };
    if (_sort == _Sort.name) {
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  void _select(LibrarySection s) => setState(() {
        _section = s;
        _folderId = null;
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = context.watch<NotesRepository>();
    final pc = context.watch<ProfileController>();
    final wide = MediaQuery.sizeOf(context).width > 840;
    final sidebar = _Sidebar(
      section: _section,
      onSelect: (s) {
        _select(s);
        if (!wide) Navigator.of(context).maybePop();
      },
      trashCount: repo.trashedNotebooks.length,
    );

    return Scaffold(
      drawer: wide ? null : Drawer(child: SafeArea(child: sidebar)),
      appBar: AppBar(
        titleSpacing: wide ? 16 : 0,
        title: Row(children: [
          MonakoLogo(profile: pc.profile, size: 36),
          const SizedBox(width: 8),
          Semantics(header: true, child: const Text('Monako')),
        ]),
        actions: [
          IconButton(
            tooltip: l.searchHint,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _search.clear();
              _results = null;
            }),
          ),
          const _SyncIndicator(),
          if (MediaQuery.sizeOf(context).width > 520)
            const ProfilePill()
          else
            const _CompactProfileButton(),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) SizedBox(width: 240, child: sidebar),
            if (wide) const VerticalDivider(width: 1),
            Expanded(child: _searching ? _searchView(l, repo) : _content(l, repo, pc)),
          ],
        ),
      ),
    );
  }

  Widget _searchView(AppLocalizations l, NotesRepository repo) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SearchBar(
          controller: _search,
          autoFocus: true,
          hintText: l.searchHint,
          leading: const Icon(Icons.search),
          onChanged: (q) => setState(() {
            _results = q.trim().isEmpty ? null : repo.search(q);
          }),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<SearchHit>>(
          future: _results,
          builder: (context, snap) {
            if (_results == null) return const SizedBox.shrink();
            if (snap.connectionState != ConnectionState.done) {
              return const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator());
            }
            final hits = snap.data ?? const [];
            if (hits.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noResults, textAlign: TextAlign.center),
              );
            }
            return ListView(children: [
              for (final h in hits)
                ListTile(
                  minTileHeight: 56,
                  leading: Icon(h.page == null ? Icons.book_outlined : Icons.article_outlined),
                  title: Text(h.notebook.title),
                  subtitle: h.snippet == null ? null : Text(h.snippet!),
                  onTap: () => _open(h.notebook, page: h.page),
                ),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _content(AppLocalizations l, NotesRepository repo, ProfileController pc) {
    final notebooks = _notebooks(repo);
    final folders = _section == LibrarySection.documents ? repo.foldersIn(_folderId) : <Folder>[];
    final trash = _section == LibrarySection.trash;
    final theme = Theme.of(context);

    final header = [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          if (_folderId != null)
            IconButton(
              tooltip: l.back,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _folderId = repo.folders.where((f) => f.id == _folderId).firstOrNull?.parentId;
              }),
            ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(_title(l, repo),
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          if (_folderId != null) _folderMenu(l, repo),
        ]),
      ),
      if (!trash && _section != LibrarySection.shared)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _Action(icon: Icons.download_outlined, label: l.importShort, onTap: _import),
            _Action(icon: Icons.book_outlined, label: l.notebook, onTap: () => _newNotebook()),
            _Action(
                icon: Icons.dashboard_outlined,
                label: l.whiteboard,
                onTap: () => _newNotebook(kind: NotebookKind.whiteboard)),
            const SizedBox(width: 4),
            _NewMenu(
              onNotebook: () => _newNotebook(),
              onWhiteboard: () => _newNotebook(kind: NotebookKind.whiteboard),
              onQuickNote: () => _newNotebook(kind: NotebookKind.quicknote),
              onImport: _import,
              onFolder: _newFolder,
            ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(children: [
          PopupMenuButton<_Sort>(
            tooltip: l.sortBy,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: _Sort.recent, checked: _sort == _Sort.recent, child: Text(l.sortRecent)),
              CheckedPopupMenuItem(value: _Sort.name, checked: _sort == _Sort.name, child: Text(l.sortName)),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sort),
                const SizedBox(width: 8),
                Text(_sort == _Sort.recent ? l.sortRecent : l.sortName),
              ]),
            ),
          ),
          const Spacer(),
          if (trash && notebooks.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                if (await _confirm(l.emptyTrash, l.emptyTrashConfirm)) {
                  await repo.emptyTrash();
                }
              },
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(l.emptyTrash),
            ),
          IconButton(
            tooltip: _list ? l.gridView : l.listView,
            icon: Icon(_list ? Icons.grid_view : Icons.view_list),
            onPressed: () => setState(() => _list = !_list),
          ),
        ]),
      ),
    ];

    if (notebooks.isEmpty && folders.isEmpty) {
      return ListView(children: [
        ...header,
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            if (_section == LibrarySection.documents && _folderId == null)
              MonakoLogo(profile: pc.profile, size: 160, full: true),
            const SizedBox(height: 16),
            Text(
              switch (_section) {
                LibrarySection.documents => l.emptyLibrary,
                LibrarySection.favorites => l.favoritesEmpty,
                LibrarySection.shared => l.sharedEmpty,
                LibrarySection.trash => l.trashEmpty,
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ]),
        ),
      ]);
    }

    final items = <Widget>[
      for (final f in folders)
        _FolderCard(
          folder: f,
          list: _list,
          count: repo.notebooksIn(f.id).length,
          onOpen: () => setState(() => _folderId = f.id),
        ),
      for (final n in notebooks)
        _NotebookCard(
          notebook: n,
          list: _list,
          trash: trash,
          onOpen: trash ? null : () => _open(n),
        ),
    ];

    return CustomScrollView(slivers: [
      SliverList.list(children: header),
      if (_list)
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 32),
          sliver: SliverList.list(children: items),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverGrid.list(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 0.62,
            ),
            children: items,
          ),
        ),
    ]);
  }

  Widget _folderMenu(AppLocalizations l, NotesRepository repo) {
    final f = repo.folders.where((x) => x.id == _folderId).firstOrNull;
    if (f == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: l.folderOptions,
      onSelected: (v) async {
        if (v == 'rename') {
          final name = await askText(context, l.rename, f.name);
          if (name != null && name.isNotEmpty) await repo.renameFolder(f, name);
        } else if (v == 'delete') {
          if (await _confirm(l.deleteFolder, l.deleteFolderHelp)) {
            setState(() => _folderId = f.parentId);
            await repo.deleteFolder(f);
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: Text(l.rename)),
        PopupMenuItem(value: 'delete', child: Text(l.deleteFolder)),
      ],
    );
  }

  Future<bool> _confirm(String title, String text) async {
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
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.section, required this.onSelect, required this.trashCount});
  final LibrarySection section;
  final ValueChanged<LibrarySection> onSelect;
  final int trashCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget item(LibrarySection s, IconData icon, IconData selectedIcon, String label,
            {String? badge}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            minTileHeight: 52,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            selected: section == s,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            leading: Icon(section == s ? selectedIcon : icon),
            title: Text(label),
            trailing: badge == null ? null : Text(badge),
            onTap: () => onSelect(s),
          ),
        );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          item(LibrarySection.documents, Icons.folder_outlined, Icons.folder, l.documents),
          item(LibrarySection.favorites, Icons.star_outline, Icons.star, l.favorites),
          item(LibrarySection.shared, Icons.people_outline, Icons.people, l.sharedWithMe),
          item(LibrarySection.trash, Icons.delete_outline, Icons.delete, l.trash,
              badge: trashCount > 0 ? '$trashCount' : null),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
}

class _NewMenu extends StatelessWidget {
  const _NewMenu({
    required this.onNotebook,
    required this.onWhiteboard,
    required this.onQuickNote,
    required this.onImport,
    required this.onFolder,
  });

  final VoidCallback onNotebook, onWhiteboard, onQuickNote, onImport, onFolder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(leadingIcon: const Icon(Icons.book_outlined), onPressed: onNotebook, child: Text(l.notebook)),
        MenuItemButton(leadingIcon: const Icon(Icons.dashboard_outlined), onPressed: onWhiteboard, child: Text(l.whiteboard)),
        MenuItemButton(leadingIcon: const Icon(Icons.edit_note), onPressed: onQuickNote, child: Text(l.quickNote)),
        const Divider(),
        MenuItemButton(leadingIcon: const Icon(Icons.download_outlined), onPressed: onImport, child: Text(l.importPdfOrImage)),
        MenuItemButton(leadingIcon: const Icon(Icons.create_new_folder_outlined), onPressed: onFolder, child: Text(l.newFolder)),
      ],
      builder: (context, menu, _) => FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.add),
        label: Text(l.newItem),
      ),
    );
  }
}

class _NewNotebookSpec {
  _NewNotebookSpec(this.title, this.template, this.format, this.coverRole);
  final String title;
  final PageTemplate template;
  final PageFormat format;
  final InkRole coverRole;
}

class _NewNotebookDialog extends StatefulWidget {
  const _NewNotebookDialog({required this.kind});
  final NotebookKind kind;

  @override
  State<_NewNotebookDialog> createState() => _NewNotebookDialogState();
}

class _NewNotebookDialogState extends State<_NewNotebookDialog> {
  late final _title = TextEditingController();
  PageTemplate _template = PageTemplate.lined;
  bool _landscape = false;
  InkRole _cover = InkRole.accent2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = AppLocalizations.of(context);
    if (_title.text.isEmpty) {
      _title.text = widget.kind == NotebookKind.whiteboard ? l.whiteboard : l.untitledNotebook;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = context.watch<ProfileController>().palette;
    final whiteboard = widget.kind == NotebookKind.whiteboard;
    return AlertDialog(
      title: Text(whiteboard ? l.whiteboard : l.newNotebook),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: InputDecoration(labelText: l.name),
              ),
              const SizedBox(height: 16),
              Text(l.coverColor),
              Wrap(children: [
                for (final r in const [
                  InkRole.accent1,
                  InkRole.accent2,
                  InkRole.accent3,
                  InkRole.accent4,
                  InkRole.heading,
                ])
                  Semantics(
                    button: true,
                    selected: _cover == r,
                    label: r == InkRole.heading
                        ? l.roleHeading
                        : l.roleAccent(r.index - InkRole.accent1.index + 1),
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: () => setState(() => _cover = r),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: palette[r],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _cover == r
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: _cover == r ? Icon(Icons.check, size: 18, color: palette.paper) : null,
                        ),
                      ),
                    ),
                  ),
              ]),
              if (!whiteboard) ...[
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l.portrait), icon: const Icon(Icons.crop_portrait)),
                    ButtonSegment(value: true, label: Text(l.landscape), icon: const Icon(Icons.crop_landscape)),
                  ],
                  selected: {_landscape},
                  onSelectionChanged: (s) => setState(() => _landscape = s.first),
                ),
                const SizedBox(height: 16),
                Text(l.templates),
                const SizedBox(height: 8),
                SizedBox(
                  height: _landscape ? 110 : 150,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final t in PageTemplate.values)
                        Semantics(
                          button: true,
                          selected: _template == t,
                          label: templateLabel(l, t),
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: () => setState(() => _template = t),
                            child: Container(
                              width: _landscape ? 120 : 90,
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _template == t
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: Column(children: [
                                Expanded(child: TemplatePreview(template: t, landscape: _landscape)),
                                Text(templateLabel(l, t),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _NewNotebookSpec(
              _title.text.trim().isEmpty ? l.untitledNotebook : _title.text.trim(),
              _template,
              _landscape ? PageFormat.landscape : PageFormat.portrait,
              _cover,
            ),
          ),
          child: Text(l.create),
        ),
      ],
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.list,
    required this.count,
    required this.onOpen,
  });

  final Folder folder;
  final bool list;
  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = context.watch<ProfileController>().palette;
    final color = palette[InkRole.heading];
    if (list) {
      return ListTile(
        minTileHeight: 64,
        leading: Icon(Icons.folder, color: color, size: 36),
        title: Text(folder.name),
        subtitle: Text(l.notebookCount(count)),
        onTap: onOpen,
      );
    }
    return Semantics(
      button: true,
      label: '${folder.name}, ${l.notebookCount(count)}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Column(children: [
          Expanded(child: FittedBox(child: Icon(Icons.folder, color: color))),
          Text(folder.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          Text(l.notebookCount(count), style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class _NotebookCard extends StatelessWidget {
  const _NotebookCard({
    required this.notebook,
    required this.list,
    required this.trash,
    required this.onOpen,
  });

  final Notebook notebook;
  final bool list;
  final bool trash;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final pc = context.watch<ProfileController>();
    final profile = pc.profileFor(notebook);
    final palette = pc.paletteOf(profile);
    final cover = palette[InkRole.parse(notebook.coverRole, fallback: InkRole.accent2)];
    final pages = repo.pagesOf(notebook.id);
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(notebook.modifiedAt.toLocal());
    final kindIcon = switch (notebook.kind) {
      NotebookKind.whiteboard => Icons.dashboard_outlined,
      NotebookKind.quicknote => Icons.edit_note,
      NotebookKind.notebook => null,
    };
    final semantics = l.notebookSemantics(notebook.title, pages.length, date);
    final menu = IconButton(
      tooltip: l.notebookOptions,
      icon: const Icon(Icons.more_vert),
      onPressed: () => _menu(context),
    );

    final thumb = pages.isEmpty
        ? ColoredBox(color: palette.paper)
        : Stack(children: [
            PageThumbnail(page: pages.first, profile: profile, palette: palette),
            if (notebook.kind == NotebookKind.notebook)
              Positioned(left: 0, top: 0, bottom: 0, width: 10, child: ColoredBox(color: cover)),
          ]);

    if (list) {
      return Semantics(
        button: true,
        label: semantics,
        child: ListTile(
          minTileHeight: 72,
          leading: SizedBox(width: 44, child: thumb),
          title: Row(children: [
            if (kindIcon != null) ...[Icon(kindIcon, size: 18), const SizedBox(width: 6)],
            Flexible(child: Text(notebook.title, overflow: TextOverflow.ellipsis)),
          ]),
          subtitle: Text(date),
          onTap: onOpen,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!trash) _star(context, l, repo),
            menu,
          ]),
        ),
      );
    }

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        onLongPress: () => _menu(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: FittedBox(fit: BoxFit.cover, alignment: Alignment.topCenter, clipBehavior: Clip.hardEdge, child: SizedBox(width: 160, height: 160 * 1.414, child: thumb)),
                    ),
                  ),
                ),
                if (!trash)
                  Positioned(right: 0, top: 0, child: _star(context, l, repo)),
                if (repo.isShared(notebook))
                  Positioned(
                    left: 14,
                    bottom: 6,
                    child: Icon(Icons.people, color: palette.ink, semanticLabel: l.sharedWithMe),
                  ),
                if (kindIcon != null)
                  Positioned(right: 6, bottom: 6, child: Icon(kindIcon, color: palette.ink)),
              ]),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(notebook.title,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(date, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              SizedBox(width: 40, child: menu),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _star(BuildContext context, AppLocalizations l, NotesRepository repo) => IconButton(
        tooltip: notebook.favorite ? l.removeFavorite : l.addFavorite,
        icon: Icon(notebook.favorite ? Icons.star : Icons.star_outline),
        onPressed: () => repo.toggleFavorite(notebook),
      );

  Future<void> _menu(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final export = ExportService(repo, context.read<AssetRenderer>());
    final shared = repo.isShared(notebook);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (trash) ...[
              ListTile(
                leading: const Icon(Icons.restore_from_trash_outlined),
                title: Text(l.restore),
                onTap: () => Navigator.pop(ctx, 'restore'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: Text(l.deleteForever),
                onTap: () => Navigator.pop(ctx, 'forever'),
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l.rename),
                onTap: () => Navigator.pop(ctx, 'rename'),
              ),
              ListTile(
                leading: Icon(notebook.favorite ? Icons.star : Icons.star_outline),
                title: Text(notebook.favorite ? l.removeFavorite : l.addFavorite),
                onTap: () => Navigator.pop(ctx, 'favorite'),
              ),
              if (!shared)
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: Text(l.moveToFolder),
                  onTap: () => Navigator.pop(ctx, 'move'),
                ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l.coverColor),
                onTap: () => Navigator.pop(ctx, 'cover'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(l.exportNormal),
                onTap: () => Navigator.pop(ctx, 'export'),
              ),
              if (!shared)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l.moveToTrash),
                  onTap: () => Navigator.pop(ctx, 'trash'),
                ),
            ],
          ]),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'restore':
        await repo.restoreFromTrash(notebook);
      case 'forever':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.deleteForever),
            content: Text(l.deleteNotebookConfirm(notebook.title)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.delete)),
            ],
          ),
        );
        if (ok == true) await repo.deleteNotebook(notebook);
      case 'rename':
        final name = await askText(context, l.rename, notebook.title);
        if (name != null && name.isNotEmpty) {
          await repo.updateNotebook(notebook.copyWith(title: name));
        }
      case 'favorite':
        await repo.toggleFavorite(notebook);
      case 'move':
        final target = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(l.moveToFolder),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, ''),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l.noFolder),
                ),
              ),
              for (final f in repo.folders)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, f.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(f.name),
                  ),
                ),
            ],
          ),
        );
        if (target != null) {
          await repo.updateNotebook(target.isEmpty
              ? notebook.copyWith(clearFolder: true)
              : notebook.copyWith(folderId: target));
        }
      case 'cover':
        final palette = context.read<ProfileController>().palette;
        final role = await showDialog<InkRole>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(l.coverColor),
            children: [
              for (final r in const [
                InkRole.accent1,
                InkRole.accent2,
                InkRole.accent3,
                InkRole.accent4,
                InkRole.heading,
              ])
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r),
                  child: Row(children: [
                    CircleAvatar(radius: 14, backgroundColor: palette[r]),
                    const SizedBox(width: 12),
                    Text(r == InkRole.heading
                        ? l.roleHeading
                        : l.roleAccent(r.index - InkRole.accent1.index + 1)),
                  ]),
                ),
            ],
          ),
        );
        if (role != null) await repo.updateNotebook(notebook.copyWith(coverRole: role.key));
      case 'export':
        await export.shareNotebookPdf(notebook);
      case 'trash':
        await repo.moveToTrash(notebook);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.movedToTrash(notebook.title)),
            action: SnackBarAction(
              label: l.undo,
              onPressed: () => repo.restoreFromTrash(repo.notebook(notebook.id) ?? notebook),
            ),
          ));
        }
    }
  }
}

class _CompactProfileButton extends StatelessWidget {
  const _CompactProfileButton();

  @override
  Widget build(BuildContext context) {
    final pc = context.watch<ProfileController>();
    final l = AppLocalizations.of(context);
    return IconButton(
      tooltip: l.changeProfile,
      onPressed: () => showProfileSheet(context),
      icon: ProfileSwatch(profile: pc.profile, size: 30),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final l = AppLocalizations.of(context);
    final (icon, label) = switch (sync.state) {
      SyncState.disabled => (Icons.cloud_off_outlined, l.syncLocalOnly),
      SyncState.idle when !sync.enabled => (Icons.cloud_off_outlined, l.syncSignedOut),
      SyncState.idle => (Icons.cloud_done_outlined, l.syncDone),
      SyncState.syncing => (Icons.cloud_sync_outlined, l.syncRunning),
      SyncState.offline => (Icons.cloud_off_outlined, l.syncOffline),
      SyncState.error => (Icons.sync_problem_outlined, l.syncError(sync.lastError ?? '')),
    };
    return IconButton(
      tooltip: label,
      onPressed: sync.enabled ? sync.sync : null,
      icon: Icon(icon),
    );
  }
}
