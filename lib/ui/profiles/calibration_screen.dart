import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color/contrast.dart';
import '../../core/color/oklch.dart';
import '../../core/profiles/profile_builder.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/roles.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/profile_names.dart';
import '../widgets/sample_note.dart';

/// Test guidé « Calibrer ma vue »: l'élève compare des échantillons et
/// garde ce qui le soulage (fond, contraste, taille, couleurs, espacement,
/// police, teinte chaude). Le profil est calculé à partir des réponses;
/// aucune maladie n'est demandée. Retourne le profil enregistré.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

enum _Step { background, contrast, size, colors, spacing, warmth, result }

class _CalibrationScreenState extends State<CalibrationScreen> {
  _Step _step = _Step.background;
  CalibrationAnswers _a = const CalibrationAnswers();

  static const _backgrounds = <Oklch>[
    Oklch(0.2, 0.0, 0), // gris très foncé
    Oklch(0.27, 0.012, 280), // gris anthracite
    Oklch(0.22, 0.035, 250), // bleu nuit
    Oklch(0.9, 0.035, 85), // sépia
    Oklch(0.95, 0.025, 95), // crème
    Oklch(0.9, 0.0, 0), // gris clair
  ];

  static const _contrasts = [7.5, 9.0, 12.5, 15.0];
  static const _sizes = [14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 40.0];
  static const _spacings = [(1.4, 0.0), (1.6, 0.08), (1.9, 0.15)];

  VisualProfile get _profile => buildCalibratedProfile(_a, id: 'calibration', name: '');

  void _next() => setState(() => _step = _Step.values[_step.index + 1]);
  void _back() => setState(() => _step = _Step.values[_step.index - 1]);

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final repo = context.read<NotesRepository>();
    final profile = buildCalibratedProfile(_a, id: 'prof_${newId()}', name: l.myCalibratedProfile);
    final saved = await repo.saveProfile(profile);
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = _Step.values.length;
    return Scaffold(
      appBar: AppBar(title: Text(l.calibrationTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Semantics(
                    label: l.stepOf(_step.index + 1, steps),
                    child: LinearProgressIndicator(value: (_step.index + 1) / steps),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: _content(l),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(children: [
                    if (_step.index > 0)
                      TextButton.icon(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(l.back),
                      ),
                    const Spacer(),
                    if (_step == _Step.result)
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check),
                        label: Text(l.saveAndUse),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _next,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(l.next),
                      ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String title, String help) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: 6),
            Text(help),
          ],
        ),
      );

  /// Échantillon cliquable: fond + texte dans les couleurs données.
  Widget _choice({
    required bool selected,
    required VoidCallback onTap,
    required Color paper,
    required Color ink,
    required String label,
    String? sample,
    double size = 18,
    double height = 1.4,
    double wordSpacing = 0,
    String? fontFamily,
  }) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  sample ?? l.calibrationSample,
                  style: TextStyle(
                    color: ink,
                    fontSize: size,
                    height: height,
                    wordSpacing: size * wordSpacing,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: ink),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: ink, fontSize: 12)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations l) {
    final p = _profile;
    switch (_step) {
      case _Step.background:
        return [
          _title(l.calBackgroundTitle, l.calBackgroundHelp),
          for (final (i, bg) in _backgrounds.indexed)
            Builder(builder: (_) {
              final paper = bg.toColor();
              final ink = solveForContrast(
                  paper,
                  bg.l < 0.55 ? const Oklch(0.85, 0.045, 90) : const Oklch(0.3, 0.02, 70),
                  9);
              return _choice(
                selected: _a.paper == bg,
                onTap: () => setState(() => _a = _a.copyWith(paper: bg)),
                paper: paper,
                ink: ink,
                label: '${i + 1}',
              );
            }),
        ];
      case _Step.contrast:
        final paper = _a.paper.toColor();
        return [
          _title(l.calContrastTitle, l.calContrastHelp),
          for (final c in _contrasts)
            _choice(
              selected: _a.contrast == c,
              onTap: () => setState(() => _a = _a.copyWith(contrast: c)),
              paper: paper,
              ink: solveForContrast(
                  paper,
                  _a.darkPaper ? const Oklch(0.85, 0.045, 90) : const Oklch(0.3, 0.02, 70),
                  c),
              label: '${c.toStringAsFixed(1)}:1',
              sample: switch (c) {
                7.5 => l.calSoft,
                9.0 => l.calMedium,
                12.5 => l.calStrong,
                _ => l.calVeryStrong,
              },
            ),
        ];
      case _Step.size:
        return [
          _title(l.calSizeTitle, l.calSizeHelp),
          for (final s in _sizes)
            _choice(
              selected: _a.textSize == (s * 1.1).roundToDouble(),
              onTap: () => setState(() => _a = _a.copyWith(textSize: (s * 1.1).roundToDouble())),
              paper: p.paper,
              ink: p.ink,
              label: '${s.round()} pt',
              size: s,
              sample: l.calSizeSample,
            ),
        ];
      case _Step.colors:
        final std = buildCalibratedProfile(_a.copyWith(colorConfusion: false), id: 'x', name: '');
        return [
          _title(l.calColorsTitle, l.calColorsHelp),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: std.paper, borderRadius: BorderRadius.circular(12)),
            child: Wrap(spacing: 24, runSpacing: 12, children: [
              for (final r in const [InkRole.accent1, InkRole.accent2, InkRole.accent3, InkRole.accent4])
                Container(width: 72, height: 40, color: std.color(r)),
            ]),
          ),
          const SizedBox(height: 16),
          RadioGroup<bool>(
            groupValue: _a.colorConfusion,
            onChanged: (v) => setState(() => _a = _a.copyWith(colorConfusion: v)),
            child: Column(children: [
              RadioListTile<bool>(value: false, title: Text(l.calColorsDistinct)),
              RadioListTile<bool>(value: true, title: Text(l.calColorsConfused)),
            ]),
          ),
        ];
      case _Step.spacing:
        return [
          _title(l.calSpacingTitle, l.calSpacingHelp),
          for (final (h, w) in _spacings)
            _choice(
              selected: _a.lineHeight == h,
              onTap: () => setState(() => _a = _a.copyWith(lineHeight: h, wordSpacing: w)),
              paper: p.paper,
              ink: p.ink,
              label: h.toStringAsFixed(1),
              height: h,
              wordSpacing: w,
              fontFamily: _a.font.family,
              sample: l.calSpacingSample,
            ),
          const SizedBox(height: 8),
          Text(l.calFontTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final f in ProfileFont.values)
            _choice(
              selected: _a.font == f,
              onTap: () => setState(() => _a = _a.copyWith(font: f)),
              paper: p.paper,
              ink: p.ink,
              label: switch (f) {
                ProfileFont.system => l.fontSystem,
                ProfileFont.legible => l.fontLegible,
                ProfileFont.dyslexic => l.fontDyslexic,
              },
              fontFamily: f.family,
              sample: l.calFontSample,
            ),
        ];
      case _Step.warmth:
        return [
          _title(l.calWarmthTitle, l.calWarmthHelp),
          ColorFiltered(
            colorFilter: ColorFilter.matrix([
              1, 0, 0, 0, 0, //
              0, 1 - 0.12 * _a.warmTint, 0, 0, 0, //
              0, 0, 1 - 0.55 * _a.warmTint, 0, 0, //
              0, 0, 0, 1, 0, //
            ]),
            child: SampleNote(profile: p),
          ),
          const SizedBox(height: 12),
          Text(l.warmTint),
          Slider(
            value: _a.warmTint,
            max: 0.6,
            divisions: 12,
            semanticFormatterCallback: (v) => '${(v * 100).round()} %',
            onChanged: (v) => setState(() => _a = _a.copyWith(warmTint: v)),
          ),
        ];
      case _Step.result:
        final ratio = contrastRatio(p.ink, p.paper);
        return [
          _title(l.calResultTitle, l.calResultHelp),
          SampleNote(profile: p),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: Text(l.displayNeeds),
            subtitle: Text(profileNeedsLabel(context, p)),
          ),
          ListTile(
            leading: const Icon(Icons.contrast),
            title: Text(l.targetRange(p.contrastRange.toString())),
            subtitle: Text('${l.contrast} : ${ratio.toStringAsFixed(1)}:1'),
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(l.textSizeValue(p.text.baseSize.round())),
          ),
          if (p.contrastRange.conflict)
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(l.rangeConflict(p.contrastRange.toString())),
            ),
          const SizedBox(height: 8),
          Text(l.medicalNotice, style: Theme.of(context).textTheme.bodySmall),
        ];
    }
  }
}
