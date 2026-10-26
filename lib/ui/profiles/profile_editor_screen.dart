import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color/contrast.dart';
import '../../core/profiles/contrast_targets.dart';
import '../../core/profiles/profile_tools.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/roles.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/profile_controller.dart';
import '../widgets/color_picker.dart';
import '../widgets/contrast_badge.dart';
import '../widgets/profile_names.dart';
import '../widgets/sample_note.dart';

/// Réglages du profil (section 7, écran 4): fond, encre, accents, contraste
/// avec ratio en direct, taille du texte, filtres, aperçu immédiat.
class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key, required this.profile});

  final VisualProfile profile;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late VisualProfile _p;
  late final TextEditingController _name;
  late final ProfileController _pc;
  bool _previewEverywhere = false;

  @override
  void initState() {
    super.initState();
    _p = widget.profile;
    _pc = context.read<ProfileController>();
    _name = TextEditingController(text: widget.profile.isPreset ? '' : widget.profile.name);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty && widget.profile.isPreset) {
      _name.text = AppLocalizations.of(context)
          .adjustedName(profileDisplayName(context, widget.profile));
    }
  }

  @override
  void dispose() {
    final pc = _pc;
    WidgetsBinding.instance.addPostFrameCallback((_) => pc.preview(null));
    _name.dispose();
    super.dispose();
  }

  void _set(VisualProfile p) {
    setState(() => _p = p);
    if (_previewEverywhere) _pc.preview(p);
  }

  /// Rôles hors de la plage de contraste du profil.
  List<InkRole> get _outOfRange {
    final range = _p.contrastRange;
    return [
      for (final r in InkRole.contrastChecked)
        if (!range.contains(contrastRatio(_p.color(r), _p.paper))) r,
    ];
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    if (_outOfRange.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: Text(l.outOfRangeTitle),
          content: Text(l.outOfRangeText(
              _outOfRange.map((r) => roleLabel(context, r)).join(', '),
              _p.contrastRange.toString())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: Text(l.saveAnyway)),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'fix'), child: Text(l.fixAutomatically)),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'fix') _p = fitProfileToRange(_p);
    }
    final name = _name.text.trim().isEmpty ? l.myProfile : _name.text.trim();
    final saved = await repo.saveProfile(_p.copyWith(name: name));
    await _pc.setActive(saved.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final range = _p.contrastRange;
    final wide = MediaQuery.sizeOf(context).width > 900;
    final preview = Padding(
      padding: const EdgeInsets.all(16),
      child: SampleNote(profile: _p),
    );
    final form = ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: l.profileName),
        ),
        const SizedBox(height: 16),
        Text(l.displayNeeds, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in VisionNeed.values)
            FilterChip(
              label: Text(needLabel(context, n)),
              selected: _p.needs.contains(n),
              onSelected: (v) => _set(_p.copyWith(
                  needs: v ? {..._p.needs, n} : ({..._p.needs}..remove(n)))),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(range.conflict ? Icons.warning_amber_rounded : Icons.contrast),
          const SizedBox(width: 8),
          Expanded(
            child: Text(range.conflict
                ? l.rangeConflict(range.toString())
                : l.targetRange(range.toString())),
          ),
        ]),
        if (_outOfRange.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _set(fitProfileToRange(_p)),
              icon: const Icon(Icons.auto_fix_high),
              label: Text(l.fixAutomaticallyCount(_outOfRange.length)),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.previewEverywhere),
          value: _previewEverywhere,
          onChanged: (v) {
            setState(() => _previewEverywhere = v);
            _pc.preview(v ? _p : null);
          },
        ),
        const Divider(height: 32),
        Text(l.colors, style: Theme.of(context).textTheme.titleMedium),
        for (final r in InkRole.values) _roleTile(context, r, range),
        const Divider(height: 32),
        Text(l.filters, style: Theme.of(context).textTheme.titleMedium),
        _slider(l.warmTint, _p.filters.warmTint, 0, 1,
            (v) => _set(_p.copyWith(filters: _p.filters.copyWith(warmTint: v)))),
        _slider(l.pdfBrightnessCap, _p.filters.pdfBrightnessCap, 0.3, 1,
            (v) => _set(_p.copyWith(filters: _p.filters.copyWith(pdfBrightnessCap: v)))),
        _slider(l.glareReduction, _p.filters.glareReduction, 0, 1,
            (v) => _set(_p.copyWith(filters: _p.filters.copyWith(glareReduction: v)))),
        _slider(l.haloReduction, _p.filters.haloReduction, 0, 1,
            (v) => _set(_p.copyWith(filters: _p.filters.copyWith(haloReduction: v)))),
        const Divider(height: 32),
        Text(l.textSettings, style: Theme.of(context).textTheme.titleMedium),
        _slider(l.textSizeValue(_p.text.baseSize.round()), _p.text.baseSize,
            ProfileText.minSize, ProfileText.maxSize,
            (v) => _set(_p.copyWith(text: _p.text.copyWith(baseSize: v.roundToDouble()))),
            percent: false),
        const SizedBox(height: 8),
        SegmentedButton<ProfileFont>(
          segments: [
            ButtonSegment(value: ProfileFont.system, label: Text(l.fontSystem)),
            ButtonSegment(value: ProfileFont.legible, label: Text(l.fontLegible)),
            ButtonSegment(value: ProfileFont.dyslexic, label: Text(l.fontDyslexic)),
          ],
          selected: {_p.text.font},
          onSelectionChanged: (s) => _set(_p.copyWith(text: _p.text.copyWith(font: s.first))),
        ),
        _slider(l.lineHeightValue(_p.text.lineHeight.toStringAsFixed(1)), _p.text.lineHeight, 1.1, 2.2,
            (v) => _set(_p.copyWith(text: _p.text.copyWith(lineHeight: v))),
            percent: false),
        _slider(l.wordSpacing, _p.text.wordSpacing, 0, 0.4,
            (v) => _set(_p.copyWith(text: _p.text.copyWith(wordSpacing: v)))),
        _slider(l.defaultZoomValue((_p.text.defaultZoom * 100).round()), _p.text.defaultZoom, 1, 2.5,
            (v) => _set(_p.copyWith(text: _p.text.copyWith(defaultZoom: v))),
            percent: false),
        const Divider(height: 32),
        Text(l.strokeSettings, style: Theme.of(context).textTheme.titleMedium),
        _slider(l.strokeWidthValue((_p.stroke.widthMultiplier * 100).round()),
            _p.stroke.widthMultiplier, 1, 2,
            (v) => _set(_p.copyWith(stroke: _p.stroke.copyWith(widthMultiplier: v))),
            percent: false),
        _slider(l.highlightOpacity, _p.stroke.highlightOpacity, 0.2, 0.7,
            (v) => _set(_p.copyWith(stroke: _p.stroke.copyWith(highlightOpacity: v)))),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.rolePatterns),
          subtitle: Text(l.rolePatternsHelp),
          value: _p.stroke.rolePatterns,
          onChanged: (v) => _set(_p.copyWith(stroke: _p.stroke.copyWith(rolePatterns: v))),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.simplifiedUi),
          value: _p.simplifiedUi,
          onChanged: (v) => _set(_p.copyWith(simplifiedUi: v)),
        ),
        const SizedBox(height: 16),
        Text(l.medicalNotice, style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileSettings),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(l.save),
          ),
        ],
      ),
      body: SafeArea(
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: SingleChildScrollView(child: preview)),
                Expanded(child: form),
              ])
            : Column(children: [preview, Expanded(child: form)]),
      ),
    );
  }

  Widget _roleTile(BuildContext context, InkRole r, ContrastRange range) {
    final l = AppLocalizations.of(context);
    final color = _p.color(r);
    final label = roleLabel(context, r);
    Widget? badge;
    if (InkRole.contrastChecked.contains(r)) {
      badge = ContrastBadge(foreground: color, background: _p.paper, range: range, compact: true);
    } else if (r.isHighlight) {
      // Le texte doit rester lisible sur le surlignage.
      badge = ContrastBadge(
        foreground: _p.ink,
        background: composite(color.withValues(alpha: _p.stroke.highlightOpacity), _p.paper),
        range: ContrastRange(range.min, 21),
        compact: true,
      );
    } else if (r == InkRole.paper) {
      badge = ContrastBadge(foreground: _p.ink, background: color, range: range, compact: true);
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 56,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: r.isHighlight
              ? composite(color.withValues(alpha: _p.stroke.highlightOpacity), _p.paper)
              : color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      title: Text(label),
      subtitle: Text(r.key),
      trailing: badge,
      onTap: () async {
        final picked = await showOklchPicker(
          context,
          title: label,
          initial: color,
          background: r == InkRole.paper ? _p.ink : _p.paper,
          range: r.isHighlight || r == InkRole.paperLine ? ContrastRange.standard : range,
        );
        if (picked != null) _set(_p.withRole(r, picked));
      },
      onLongPress: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.roleHelp))),
    );
  }

  Widget _slider(String label, double value, double min, double max,
          ValueChanged<double> onChanged,
          {bool percent = true}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(percent ? '$label : ${(value * 100).round()} %' : label),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            semanticFormatterCallback: (v) =>
                percent ? '${(v * 100).round()} %' : v.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ],
      );
}
