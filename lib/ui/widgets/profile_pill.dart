import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color/contrast.dart';
import '../../core/color/oklch.dart';
import '../../core/profiles/profile_tools.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/roles.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/profile_controller.dart';
import '../profiles/profiles_screen.dart';
import 'contrast_badge.dart';
import 'profile_names.dart';

/// Pastille profil (section 7): toujours visible; un toucher ouvre les
/// profils enregistrés, un second toucher applique.
class ProfilePill extends StatelessWidget {
  const ProfilePill({super.key, this.notebook});

  final Notebook? notebook;

  @override
  Widget build(BuildContext context) {
    final pc = context.watch<ProfileController>();
    final l = AppLocalizations.of(context);
    final p = pc.profileFor(notebook);
    final name = profileDisplayName(context, p);
    return Semantics(
      button: true,
      label: l.profilePillSemantics(name),
      excludeSemantics: true,
      child: Tooltip(
        message: l.changeProfile,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => showProfileSheet(context, notebook: notebook),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileSwatch(profile: p, size: 26),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.expand_more, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille « Aa » montrant le fond et l'encre d'un profil.
class ProfileSwatch extends StatelessWidget {
  const ProfileSwatch({super.key, required this.profile, this.size = 40});
  final VisualProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: profile.paper,
            shape: BoxShape.circle,
            border: Border.all(color: profile.color(InkRole.paperLine), width: 1.5),
          ),
          child: Text(
            'Aa',
            style: TextStyle(
              color: profile.ink,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
              fontFamily: profile.text.font.family,
            ),
          ),
        ),
      );
}

Future<void> showProfileSheet(BuildContext context, {Notebook? notebook}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProfileSheet(notebook: notebook),
    );

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({this.notebook});
  final Notebook? notebook;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  bool _adjusting = false;

  Future<void> _apply(VisualProfile p) async {
    final pc = context.read<ProfileController>();
    final repo = context.read<NotesRepository>();
    final n = widget.notebook == null ? null : repo.notebook(widget.notebook!.id);
    if (n != null && n.linkedProfileId != null && !repo.isShared(n)) {
      await repo.updateNotebook(n.copyWith(linkedProfileId: p.id));
    }
    await pc.setActive(p.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pc = context.watch<ProfileController>();
    final repo = context.watch<NotesRepository>();
    final n = widget.notebook == null ? null : repo.notebook(widget.notebook!.id);
    final current = pc.profileFor(n);
    if (_adjusting) {
      return _QuickAdjust(
        base: current,
        onDone: () => setState(() => _adjusting = false),
      );
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(l.profilesTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final p in repo.allProfiles)
              ListTile(
                minTileHeight: 56,
                leading: ProfileSwatch(profile: p),
                title: Text(profileDisplayName(context, p)),
                subtitle: Text(profileNeedsLabel(context, p)),
                selected: p.id == current.id,
                trailing: p.id == current.id
                    ? Icon(Icons.check, semanticLabel: l.selected)
                    : null,
                onTap: () => _apply(p),
              ),
            if (n != null && !repo.isShared(n))
              SwitchListTile(
                secondary: const Icon(Icons.push_pin_outlined),
                title: Text(l.linkProfileToNotebook),
                subtitle: Text(l.linkProfileToNotebookHelp),
                value: n.linkedProfileId != null,
                onChanged: (v) => repo.updateNotebook(v
                    ? n.copyWith(linkedProfileId: current.id)
                    : n.copyWith(clearLinkedProfile: true)),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(l.useRescueProfile),
              subtitle: Text(profileDisplayName(context, pc.rescueProfile)),
              onTap: () async {
                await pc.rescue();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l.quickAdjust),
              onTap: () => setState(() => _adjusting = true),
            ),
            ListTile(
              leading: const Icon(Icons.spa_outlined),
              title: Text(l.profileTiresMe),
              subtitle: Text(l.profileTiresMeHelp),
              onTap: () async {
                final softer = softerProfile(current).copyWith(
                    name: l.softerName(profileDisplayName(context, current)));
                pc.preview(softer);
                final keep = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.profileTiresMe),
                    content: Text(l.softerPreviewText),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l.cancel)),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l.keep)),
                    ],
                  ),
                );
                pc.preview(null);
                if (keep == true) {
                  final saved = await repo.saveProfile(softer);
                  await _apply(saved);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l.manageProfiles),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfilesScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Curseurs rapides: luminosité du fond, contraste, taille. Aperçu
/// immédiat, puis enregistrement comme profil personnel.
class _QuickAdjust extends StatefulWidget {
  const _QuickAdjust({required this.base, required this.onDone});
  final VisualProfile base;
  final VoidCallback onDone;

  @override
  State<_QuickAdjust> createState() => _QuickAdjustState();
}

class _QuickAdjustState extends State<_QuickAdjust> {
  late final VisualProfile _base = widget.base;
  late double _lightness = Oklch.fromColor(_base.paper).l;
  late double _contrast = contrastRatio(_base.ink, _base.paper);
  late double _size = _base.text.baseSize;
  late VisualProfile _current = _base;
  late final ProfileController _pc = context.read<ProfileController>();

  void _update() {
    var p = adjustPaperLightness(_base, _lightness);
    p = adjustContrast(p, _contrast);
    p = p.copyWith(text: p.text.copyWith(baseSize: _size));
    setState(() => _current = p);
    _pc.preview(p);
  }

  @override
  void dispose() {
    _pc.preview(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final range = _base.contrastRange;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.quickAdjust, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l.backgroundBrightness),
            Slider(
              value: _lightness.clamp(0.08, 0.97),
              min: 0.08,
              max: 0.97,
              semanticFormatterCallback: (v) => '${(v * 100).round()} %',
              onChanged: (v) {
                _lightness = v;
                _update();
              },
            ),
            Row(children: [
              Expanded(child: Text(l.contrast)),
              ContrastBadge(
                  foreground: _current.ink,
                  background: _current.paper,
                  range: range),
            ]),
            Slider(
              value: _contrast.clamp(3, 21),
              min: 3,
              max: 21,
              semanticFormatterCallback: (v) => '${v.toStringAsFixed(1)}:1',
              onChanged: (v) {
                _contrast = v;
                _update();
              },
            ),
            Text(l.textSizeValue(_size.round())),
            Slider(
              value: _size,
              min: ProfileText.minSize,
              max: ProfileText.maxSize,
              divisions: 26,
              semanticFormatterCallback: (v) => '${v.round()} pt',
              onChanged: (v) {
                _size = v;
                _update();
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onDone, child: Text(l.cancel)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final repo = context.read<NotesRepository>();
                    final named = _current.isPreset
                        ? _current.copyWith(
                            name: l.adjustedName(profileDisplayName(context, _base)))
                        : _current;
                    final saved = await repo.saveProfile(named);
                    await _pc.setActive(saved.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(l.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
