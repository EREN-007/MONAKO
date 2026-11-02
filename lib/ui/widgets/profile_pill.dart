import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color/contrast.dart';
import '../../core/color/oklch.dart';
import '../../core/profiles/profile_builder.dart';
import '../../core/profiles/profile_tools.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/roles.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/profile_controller.dart';
import '../profiles/profiles_screen.dart';
import 'contrast_badge.dart';
import 'sample_note.dart';
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
    final pill = _pill(context, l, p, name);
    if (!pc.isTrying || notebook?.linkedProfileId != null) return pill;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: l.backToMyProfile,
        onPressed: pc.backToHome,
        icon: const Icon(Icons.home_outlined),
      ),
      pill,
    ]);
  }

  Widget _pill(BuildContext context, AppLocalizations l, VisualProfile p, String name) {
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

Future<void> showProfileSheet(BuildContext context,
        {Notebook? notebook, bool customize = false}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProfileSheet(notebook: notebook, customize: customize),
    );

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({this.notebook, this.customize = false});
  final Notebook? notebook;

  /// Ouvre directement « Choisir mon fond et mon encre ».
  final bool customize;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  bool _adjusting = false;
  late bool _customizing = widget.customize;

  /// Applique un profil tout de suite: la feuille reste ouverte pour voir
  /// toute l'app changer derrière (fond, encres, interface).
  Future<void> _apply(VisualProfile p) async {
    final pc = context.read<ProfileController>();
    final repo = context.read<NotesRepository>();
    final n = widget.notebook == null ? null : repo.notebook(widget.notebook!.id);
    if (n != null && n.linkedProfileId != null && !repo.isShared(n)) {
      await repo.updateNotebook(n.copyWith(linkedProfileId: p.id));
    }
    await pc.setActive(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pc = context.watch<ProfileController>();
    final repo = context.watch<NotesRepository>();
    final n = widget.notebook == null ? null : repo.notebook(widget.notebook!.id);
    final current = pc.profileFor(n);
    final home = pc.home;
    if (_adjusting) {
      return _QuickAdjust(base: current, onDone: () => setState(() => _adjusting = false));
    }
    if (_customizing) {
      return CustomizeLook(
        base: current,
        onDone: () => widget.customize
            ? Navigator.pop(context)
            : setState(() => _customizing = false),
      );
    }
    final theme = Theme.of(context);
    final others = repo.allProfiles.where((p) => p.id != home.id).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // --- Mon profil (prioritaire) ---
            Text(l.myProfileTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  ProfileSwatch(profile: home, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.star, size: 18),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(profileDisplayName(context, home),
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      Text(profileNeedsLabel(context, home), style: theme.textTheme.bodySmall),
                    ]),
                  ),
                  if (pc.isTrying)
                    FilledButton.icon(
                      onPressed: pc.backToHome,
                      icon: const Icon(Icons.home_outlined),
                      label: Text(l.backToMyProfile),
                    )
                  else
                    Chip(
                      avatar: const Icon(Icons.check, size: 18),
                      label: Text(l.inUse),
                    ),
                ]),
              ),
            ),
            if (pc.isTrying) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.science_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(l.tryingProfile(profileDisplayName(context, current)))),
                TextButton(
                  onPressed: () => pc.setHome(current.id),
                  child: Text(l.makeItMyProfile),
                ),
              ]),
            ],
            const SizedBox(height: 16),

            // --- Essayer un autre affichage (un toucher) ---
            Text(l.tryAnotherLook, style: theme.textTheme.titleMedium),
            Text(l.tryAnotherLookHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 128,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in others)
                    LookTile(
                      profile: p,
                      selected: p.id == current.id,
                      onTap: () => _apply(p),
                      onMakeHome: () => pc.setHome(p.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => setState(() => _customizing = true),
              icon: const Icon(Icons.format_color_fill),
              label: Text(l.customizeLook),
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
            const Divider(height: 24),
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
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.keep)),
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
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(l.useRescueProfile),
              subtitle: Text(profileDisplayName(context, pc.rescueProfile)),
              onTap: () async {
                await pc.rescue();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l.manageProfiles),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilesScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Grande vignette d'un affichage à essayer: fond, encre et trois accents.
class LookTile extends StatelessWidget {
  const LookTile({
    super.key,
    required this.profile,
    required this.selected,
    required this.onTap,
    required this.onMakeHome,
  });

  final VisualProfile profile;
  final bool selected;
  final VoidCallback onTap, onMakeHome;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = profile;
    return Semantics(
      button: true,
      selected: selected,
      label: profileDisplayName(context, p),
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: onMakeHome,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 112,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 3),
            ),
            child: Column(children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.color(InkRole.paperLine), width: 1.5),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Aa', style: TextStyle(color: p.ink, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: p.text.font.family)),
                    const Spacer(),
                    Row(children: [
                      for (final r in const [InkRole.accent1, InkRole.accent2, InkRole.accent3])
                        Container(
                          width: 18,
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(color: p.color(r), borderRadius: BorderRadius.circular(3)),
                        ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Text(profileDisplayName(context, p),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              if (selected) Text(l.inUse, style: TextStyle(fontSize: 11, color: scheme.primary)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// « Fond et encre »: l'élève choisit librement la couleur du fond et de
/// l'encre; Monako ajuste la luminosité pour garder un contraste sûr. Tout
/// change en direct; on enregistre dans « Mon affichage personnalisé ».
class CustomizeLook extends StatefulWidget {
  const CustomizeLook({super.key, required this.base, required this.onDone});
  final VisualProfile base;
  final VoidCallback onDone;

  @override
  State<CustomizeLook> createState() => _CustomizeLookState();
}

class _CustomizeLookState extends State<CustomizeLook> {
  static const backgrounds = <Oklch>[
    Oklch(0.2, 0.0, 0), // noir doux
    Oklch(0.27, 0.012, 280), // anthracite
    Oklch(0.22, 0.035, 250), // bleu nuit
    Oklch(0.24, 0.03, 160), // vert ardoise
    Oklch(0.26, 0.03, 40), // brun chocolat
    Oklch(0.9, 0.035, 85), // sépia
    Oklch(0.95, 0.025, 95), // crème
    Oklch(0.9, 0.03, 230), // bleu pâle
    Oklch(0.92, 0.03, 145), // vert d'eau
    Oklch(0.9, 0.0, 0), // gris clair
  ];
  static const inks = <Oklch>[
    Oklch(0.6, 0.04, 90), // crème / brun
    Oklch(0.6, 0.12, 95), // jaune
    Oklch(0.6, 0.0, 0), // gris neutre
    Oklch(0.6, 0.09, 240), // bleu
    Oklch(0.6, 0.09, 150), // vert
    Oklch(0.6, 0.09, 30), // rouge-orangé
  ];

  late final ProfileController _pc = context.read<ProfileController>();
  late Oklch _paper = Oklch.fromColor(widget.base.paper);
  late Oklch _ink = Oklch.fromColor(widget.base.ink);
  late double _contrast = contrastRatio(widget.base.ink, widget.base.paper).clamp(5.0, 16.0);
  late double _size = widget.base.text.baseSize;
  bool _makeHome = false;
  VisualProfile? _current;

  VisualProfile _build(String id, String name) => buildCalibratedProfile(
        CalibrationAnswers(
          paper: _paper,
          ink: _ink,
          contrast: _contrast,
          textSize: _size,
          colorConfusion: widget.base.stroke.rolePatterns,
          lineHeight: widget.base.text.lineHeight,
          wordSpacing: widget.base.text.wordSpacing,
          font: widget.base.text.font,
          warmTint: widget.base.filters.warmTint,
        ),
        id: id,
        name: name,
      );

  void _update() {
    final p = _build('preview_look', '');
    setState(() => _current = p);
    _pc.preview(p);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _pc.preview(null);
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final existing = repo.settings.quickProfileId;
    final id = existing != null && repo.profileById(existing) != null ? existing : 'prof_${newId()}';
    final saved = await repo.saveProfile(_build(id, l.myCustomLook));
    await repo.updateSettings(repo.settings.copyWith(quickProfileId: saved.id));
    if (_makeHome) {
      await _pc.setHome(saved.id);
    } else {
      await _pc.setActive(saved.id);
    }
    widget.onDone();
  }

  Widget _swatch(Color color, bool selected, String label, VoidCallback onTap) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected ? Icon(Icons.check, size: 18, color: contrastRatio(color, const Color(0xFF000000)) > 7 ? const Color(0xFF202020) : const Color(0xFFF0F0F0)) : null,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = _current ?? widget.base;
    final dark = _paper.l < 0.55;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(l.customizeLook, style: Theme.of(context).textTheme.titleLarge),
            Text(l.customizeLookHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text(l.background, style: Theme.of(context).textTheme.titleSmall),
            Wrap(children: [
              for (final (i, bg) in backgrounds.indexed)
                _swatch(bg.toColor(), _paper == bg, '${l.background} ${i + 1}', () {
                  _paper = bg;
                  _update();
                }),
            ]),
            const SizedBox(height: 8),
            Text(l.ink, style: Theme.of(context).textTheme.titleSmall),
            Wrap(children: [
              for (final (i, ink) in inks.indexed)
                _swatch(
                  solveForContrast(_paper.toColor(), ink.copyWith(l: dark ? 0.85 : 0.3), _contrast),
                  (_ink.h - ink.h).abs() < 1 && (_ink.c - ink.c).abs() < 0.01,
                  '${l.ink} ${i + 1}',
                  () {
                    _ink = ink;
                    _update();
                  },
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(l.contrast)),
              ContrastBadge(foreground: p.ink, background: p.paper, range: p.contrastRange, compact: true),
            ]),
            Slider(
              value: _contrast,
              min: 5,
              max: 16,
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
            SampleNote(profile: p, compact: true),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _makeHome,
              title: Text(l.makeItMyProfile),
              onChanged: (v) => setState(() => _makeHome = v ?? false),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: widget.onDone, child: Text(l.cancel)),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: Text(l.apply)),
            ]),
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
