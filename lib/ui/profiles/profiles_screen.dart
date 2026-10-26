import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profiles/profile_tools.dart';
import '../../core/profiles/visual_profile.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/asset_renderer.dart';
import '../../services/export_service.dart';
import '../../services/profile_controller.dart';
import '../widgets/profile_names.dart';
import '../widgets/profile_pill.dart';
import 'profile_editor_screen.dart';

/// Profils prédéfinis (besoins A à E) et profils personnels: appliquer,
/// modifier, fusionner (A + C…), exporter, importer.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final Set<String> _fuse = {};
  bool _fusing = false;

  Future<void> _doFuse() async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final pc = context.read<ProfileController>();
    final sources = [for (final id in _fuse) repo.profileById(id)!];
    final result = fuseProfiles(sources,
        id: 'prof_${newId()}',
        name: sources.map((p) => profileDisplayName(context, p)).join(' + '));
    if (result.conflicts.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: Text(l.fusionConflictTitle),
          content: Text([
            for (final c in result.conflicts)
              switch (c) {
                FusionConflict.contrastCappedByLight => l.conflictCappedByLight,
                FusionConflict.contrastNoOverlap => l.conflictNoOverlap,
                FusionConflict.backgroundChosen => l.conflictBackground,
              },
          ].join('\n\n')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.useSafest)),
          ],
        ),
      );
      if (go != true) return;
    }
    final saved = await repo.saveProfile(result.profile);
    await pc.setActive(saved.id);
    setState(() {
      _fusing = false;
      _fuse.clear();
    });
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: const ['json']);
    if (files.isEmpty) return;
    try {
      final j = jsonDecode(utf8.decode(await files.first.xFile.readAsBytes()))
          as Map<String, dynamic>;
      final p = VisualProfile.fromJson(
        {...j, 'id': 'prof_${newId()}'},
        base: baseProfileFor(j['baseId'] as String?),
      );
      await repo.saveProfile(p);
      messenger.showSnackBar(SnackBar(content: Text(l.profileImported(p.name))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = context.watch<NotesRepository>();
    final pc = context.watch<ProfileController>();
    final export = ExportService(repo, context.read<AssetRenderer>());
    final active = pc.profile.id;

    Widget tile(VisualProfile p) {
      final name = profileDisplayName(context, p);
      return ListTile(
        minTileHeight: 64,
        leading: _fusing
            ? Checkbox(
                value: _fuse.contains(p.id),
                onChanged: (v) => setState(() => v == true ? _fuse.add(p.id) : _fuse.remove(p.id)),
              )
            : ProfileSwatch(profile: p, size: 44),
        title: Text(name),
        subtitle: Text('${profileNeedsLabel(context, p)} · ${p.contrastRange}'),
        selected: p.id == active,
        onTap: _fusing
            ? () => setState(() => _fuse.contains(p.id) ? _fuse.remove(p.id) : _fuse.add(p.id))
            : () => pc.setActive(p.id),
        trailing: _fusing
            ? null
            : PopupMenuButton<String>(
                tooltip: l.profileOptions(name),
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileEditorScreen(profile: p)),
                      );
                    case 'json':
                      await export.shareProfileJson(p);
                    case 'sheet':
                      await export.shareProfileSheet(p, labels: {
                        'title': l.profileSheetTitle,
                        'needs': l.needsLabel,
                        'range': l.contrastRangeLabel,
                        'role': l.roleColumn,
                        'color': l.colorColumn,
                        'ratio': l.ratioColumn,
                        'filters': l.filtersLabel,
                        'text': l.textLabel,
                        'stroke': l.strokeLabel,
                        'disclaimer': l.medicalNotice,
                      });
                    case 'delete':
                      await repo.deleteProfile(p.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'edit',
                      child: Text(p.isPreset ? l.customizeCopy : l.edit)),
                  PopupMenuItem(value: 'json', child: Text(l.exportProfile)),
                  PopupMenuItem(value: 'sheet', child: Text(l.exportForOptometrist)),
                  if (!p.isPreset) PopupMenuItem(value: 'delete', child: Text(l.delete)),
                ],
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.visualProfiles),
        actions: [
          IconButton(
            tooltip: l.importProfile,
            onPressed: _import,
            icon: const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            tooltip: _fusing ? l.cancel : l.combineNeeds,
            onPressed: () => setState(() {
              _fusing = !_fusing;
              _fuse.clear();
            }),
            icon: Icon(_fusing ? Icons.close : Icons.join_inner),
          ),
        ],
      ),
      floatingActionButton: _fusing
          ? FloatingActionButton.extended(
              onPressed: _fuse.length >= 2 ? _doFuse : null,
              icon: const Icon(Icons.join_inner),
              label: Text(l.combineCount(_fuse.length)),
            )
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileEditorScreen(profile: pc.profile)),
              ),
              icon: const Icon(Icons.add),
              label: Text(l.newProfile),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (_fusing)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.combineHelp),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(l.presetProfiles, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final p in repo.allProfiles.where((p) => p.isPreset)) tile(p),
            if (repo.customProfiles.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(l.myProfiles, style: Theme.of(context).textTheme.titleSmall),
              ),
              for (final p in repo.customProfiles) tile(p),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.medicalNotice, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
