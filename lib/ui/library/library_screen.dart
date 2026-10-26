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
import '../settings/settings_screen.dart';
import '../widgets/monako_logo.dart';
import '../widgets/profile_pill.dart';
import 'import_actions.dart';

/// Bibliothèque: dossiers, cahiers, recherche, recolorés par le profil.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String? _folderId;
  final _search = TextEditingController();
  Future<List<SearchHit>>? _results;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Notebook n, {NotePage? page}) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(notebookId: n.id, initialPageId: page?.id),
        ),
      );

  Future<String?> _askName(String title, {String initial = ''}) {
    final l = AppLocalizations.of(context);
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: l.name),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(l.ok)),
        ],
      ),
    );
  }

  Future<void> _newNotebook() async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final name = await _askName(l.newNotebook, initial: l.untitledNotebook);
    if (name == null || name.isEmpty) return;
    final n = await repo.createNotebook(name, folderId: _folderId);
    if (mounted) _open(n);
  }

  Future<void> _newFolder() async {
    final l = AppLocalizations.of(context);
    final name = await _askName(l.newFolder);
    if (name == null || name.isEmpty || !mounted) return;
    final f = await context.read<NotesRepository>().createFolder(name);
    setState(() => _folderId = f.id);
  }

  Future<void> _import() async {
    final n = await importDocument(context, folderId: _folderId);
    if (n != null && mounted) _open(n);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = context.watch<NotesRepository>();
    final pc = context.watch<ProfileController>();
    final folders = repo.folders;
    if (_folderId != null && !folders.any((f) => f.id == _folderId)) {
      _folderId = null;
    }
    final notebooks = repo.notebooksIn(_folderId);
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(children: [
          MonakoLogo(profile: pc.profile, size: 40),
          const SizedBox(width: 8),
          Semantics(header: true, child: const Text('Monako')),
        ]),
        actions: [
          const _SyncIndicator(),
          if (width > 520) const ProfilePill() else const _CompactProfileButton(),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: _AddButton(
        onNotebook: _newNotebook,
        onImport: _import,
        onFolder: _newFolder,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SearchBar(
                  controller: _search,
                  hintText: l.searchHint,
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_search.text.isNotEmpty)
                      IconButton(
                        tooltip: l.clearSearch,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _search.clear();
                          _results = null;
                        }),
                      ),
                  ],
                  onChanged: (q) => setState(() {
                    _results = q.trim().isEmpty ? null : repo.search(q);
                  }),
                ),
              ),
            ),
            if (_results != null)
              _searchResults(l)
            else ...[
              SliverToBoxAdapter(child: _folderBar(l, folders)),
              if (notebooks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _empty(l, pc),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: notebooks.length,
                    itemBuilder: (_, i) => _NotebookCard(
                      notebook: notebooks[i],
                      onOpen: () => _open(notebooks[i]),
                      onRename: () async {
                        final name = await _askName(l.rename, initial: notebooks[i].title);
                        if (name != null && name.isNotEmpty) {
                          await repo.updateNotebook(notebooks[i].copyWith(title: name));
                        }
                      },
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _folderBar(AppLocalizations l, List<Folder> folders) {
    final repo = context.read<NotesRepository>();
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: const Icon(Icons.library_books_outlined),
              label: Text(l.allNotebooks),
              selected: _folderId == null,
              onSelected: (_) => setState(() => _folderId = null),
            ),
          ),
          for (final f in folders)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: () => _folderMenu(f),
                child: ChoiceChip(
                  avatar: const Icon(Icons.folder_outlined),
                  label: Text(f.name),
                  selected: _folderId == f.id,
                  onSelected: (_) => setState(() => _folderId = f.id),
                ),
              ),
            ),
          if (_folderId != null)
            IconButton(
              tooltip: l.folderOptions,
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _folderMenu(repo.folders.firstWhere((f) => f.id == _folderId)),
            ),
        ],
      ),
    );
  }

  Future<void> _folderMenu(Folder f) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.rename),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l.deleteFolder),
            subtitle: Text(l.deleteFolderHelp),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (action == 'rename') {
      final name = await _askName(l.rename, initial: f.name);
      if (name != null && name.isNotEmpty) await repo.renameFolder(f, name);
    } else if (action == 'delete') {
      await repo.deleteFolder(f);
    }
  }

  Widget _searchResults(AppLocalizations l) => FutureBuilder<List<SearchHit>>(
        future: _results,
        builder: (context, snap) {
          final hits = snap.data ?? const [];
          if (snap.connectionState != ConnectionState.done) {
            return const SliverToBoxAdapter(child: LinearProgressIndicator());
          }
          if (hits.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noResults, textAlign: TextAlign.center),
              ),
            );
          }
          return SliverList.builder(
            itemCount: hits.length,
            itemBuilder: (_, i) {
              final h = hits[i];
              return ListTile(
                minTileHeight: 56,
                leading: Icon(h.page == null ? Icons.book_outlined : Icons.article_outlined),
                title: Text(h.notebook.title),
                subtitle: h.snippet == null ? null : Text(h.snippet!),
                onTap: () => _open(h.notebook, page: h.page),
              );
            },
          );
        },
      );

  Widget _empty(AppLocalizations l, ProfileController pc) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MonakoLogo(profile: pc.profile, size: 160, full: true),
            const SizedBox(height: 16),
            Text(l.emptyLibrary,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _newNotebook,
                  icon: const Icon(Icons.add),
                  label: Text(l.newNotebook),
                ),
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l.importPdfOrImage),
                ),
              ],
            ),
          ],
        ),
      );
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

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.onNotebook,
    required this.onImport,
    required this.onFolder,
  });

  final VoidCallback onNotebook, onImport, onFolder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.book_outlined),
          onPressed: onNotebook,
          child: Text(l.newNotebook),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.upload_file_outlined),
          onPressed: onImport,
          child: Text(l.importPdfOrImage),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.create_new_folder_outlined),
          onPressed: onFolder,
          child: Text(l.newFolder),
        ),
      ],
      builder: (context, menu, _) => FloatingActionButton.extended(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.add),
        label: Text(l.add),
      ),
    );
  }
}

class _NotebookCard extends StatelessWidget {
  const _NotebookCard({
    required this.notebook,
    required this.onOpen,
    required this.onRename,
  });

  final Notebook notebook;
  final VoidCallback onOpen, onRename;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final pc = context.watch<ProfileController>();
    final palette = pc.paletteOf(pc.profileFor(notebook));
    final cover = palette[InkRole.parse(notebook.coverRole, fallback: InkRole.accent2)];
    final shared = repo.isShared(notebook);
    final pages = repo.pagesOf(notebook.id);
    final hasPdf = pages.any((p) => p.assetId != null);
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(notebook.modifiedAt.toLocal());

    return Semantics(
      button: true,
      label: l.notebookSemantics(notebook.title, pages.length, date),
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          onLongPress: () => _menu(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: palette.paper,
                  child: Stack(children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 14,
                      child: ColoredBox(color: cover),
                    ),
                    Center(
                      child: Icon(
                        hasPdf ? Icons.picture_as_pdf_outlined : Icons.edit_note,
                        size: 48,
                        color: palette.ink,
                      ),
                    ),
                    if (shared)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Icon(Icons.group_outlined, color: palette.ink),
                      ),
                    if (notebook.linkedProfileId != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Icon(Icons.push_pin_outlined, color: palette.ink, size: 20),
                      ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notebook.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(date, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.notebookOptions,
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _menu(context),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.rename),
              onTap: () => Navigator.pop(ctx, 'rename'),
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
                title: Text(l.deleteNotebook),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ]),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        onRename();
      case 'move':
        final folders = repo.folders;
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
              for (final f in folders)
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
                    CircleAvatar(
                        radius: 14,
                        backgroundColor: context.read<ProfileController>().palette[r]),
                    const SizedBox(width: 12),
                    Text(r == InkRole.heading ? l.roleHeading : l.roleAccent(r.index - InkRole.accent1.index + 1)),
                  ]),
                ),
            ],
          ),
        );
        if (role != null) await repo.updateNotebook(notebook.copyWith(coverRole: role.key));
      case 'export':
        await export.shareNotebookPdf(notebook);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.deleteNotebook),
            content: Text(l.deleteNotebookConfirm(notebook.title)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.delete)),
            ],
          ),
        );
        if (ok == true) await repo.deleteNotebook(notebook);
    }
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
