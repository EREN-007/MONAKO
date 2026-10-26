import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profiles/presets.dart';
import '../../core/profiles/profile_tools.dart';
import '../../core/profiles/visual_profile.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/profile_controller.dart';
import '../auth/auth_screen.dart';
import '../settings/legal_texts.dart';
import '../widgets/monako_logo.dart';
import '../widgets/profile_names.dart';
import '../widgets/sample_note.dart';

/// Accueil / test de confort (section 7, écran 1): message médical et
/// confidentialité, trois questions sur les symptômes (jamais la maladie),
/// puis aperçu de 2 ou 3 profils sur un texte exemple.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Light { hurts, sometimes, fine }

enum _Time { day, evening, both }

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _consent = false;
  _Light? _light;
  final Set<VisionNeed> _reading = {};
  _Time? _time;
  String? _chosen;

  /// Profils proposés selon les réponses (2 ou 3).
  List<VisualProfile> _suggestions(BuildContext context) {
    final out = <VisualProfile>[];
    void add(VisualProfile p) {
      if (!out.any((o) => o.id == p.id)) out.add(p);
    }

    final light = _light == _Light.hurts || _light == _Light.sometimes;
    if (light) {
      if (_time == _Time.day) {
        add(Presets.a2);
        add(Presets.a1);
      } else {
        add(Presets.a1);
        add(Presets.a2);
      }
    }
    final needs = [..._reading]..sort((a, b) => a.index.compareTo(b.index));
    for (final n in needs) {
      add(switch (n) {
        VisionNeed.a => Presets.a1,
        VisionNeed.b => Presets.b,
        VisionNeed.c => Presets.c,
        VisionNeed.d => Presets.d,
        VisionNeed.e => Presets.e,
      });
    }
    // Besoin combiné (ex. A + C): profil fusionné proposé en premier.
    if (light && needs.isNotEmpty) {
      final r = fuseProfiles(
        [Presets.a1, ...needs.map((n) => _presetFor(n))],
        id: 'prof_fused_onboarding',
        name: [VisionNeed.a, ...needs].map((n) => needLabel(context, n)).join(' + '),
      );
      out.insert(0, r.profile);
    }
    if (out.isEmpty) {
      add(Presets.standard);
      add(Presets.a2);
      add(Presets.e);
    }
    if (out.length == 1) add(out.first.id == Presets.a1Id ? Presets.a2 : Presets.a1);
    return out.take(3).toList();
  }

  static VisualProfile _presetFor(VisionNeed n) => switch (n) {
        VisionNeed.a => Presets.a1,
        VisionNeed.b => Presets.b,
        VisionNeed.c => Presets.c,
        VisionNeed.d => Presets.d,
        VisionNeed.e => Presets.e,
      };

  Future<void> _finish() async {
    final repo = context.read<NotesRepository>();
    final pc = context.read<ProfileController>();
    final auth = context.read<AuthService>();
    final suggestions = _suggestions(context);
    final suggestion = suggestions.firstWhere(
        (p) => p.id == _chosen, orElse: () => suggestions.first);
    // Proposer le compte avant d'entrer dans la bibliothèque.
    if (auth.configured && !auth.signedIn) {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AuthScreen(fromOnboarding: true)));
      // Un compte existant a déjà fait le test sur un autre appareil.
      await repo.sync.sync();
      if (repo.settings.onboardingDone) return;
    }
    var chosen = suggestion;
    if (!Presets.all.any((p) => p.id == suggestion.id)) {
      chosen = await repo.saveProfile(suggestion.copyWith(id: 'prof_${newId()}'));
    }
    // Profil de secours: toujours un profil prédéfini (lisible).
    final rescue = chosen.isPreset ? chosen.id : (chosen.baseId ?? Presets.a1Id);
    await repo.updateSettings(repo.settings.copyWith(
      onboardingDone: true,
      consentAt: nowUtc(),
      activeProfileId: chosen.id,
      rescueProfileId: rescue,
      autoNight: _time == _Time.both && chosen.id != Presets.a1Id,
      nightProfileId: Presets.a1Id,
    ));
    await pc.setActive(chosen.id);
    // Test refait depuis les réglages: retour à l'écran précédent.
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pc = context.watch<ProfileController>();
    final steps = [_welcome, _q1, _q2, _q3, _choose];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Semantics(
                    label: l.stepOf(_step + 1, steps.length),
                    child: LinearProgressIndicator(value: (_step + 1) / steps.length),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: steps[_step](l, pc),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    children: [
                      if (_step > 0)
                        TextButton.icon(
                          onPressed: () => setState(() => _step--),
                          icon: const Icon(Icons.arrow_back),
                          label: Text(l.back),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _canContinue
                            ? () => _step == steps.length - 1
                                ? _finish()
                                : setState(() => _step++)
                            : null,
                        icon: Icon(_step == steps.length - 1 ? Icons.check : Icons.arrow_forward),
                        label: Text(_step == steps.length - 1 ? l.keepThisProfile : l.next),
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

  bool get _canContinue => switch (_step) {
        0 => _consent,
        1 => _light != null,
        2 => true,
        3 => _time != null,
        _ => true,
      };

  Widget _welcome(AppLocalizations l, ProfileController pc) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: MonakoLogo(profile: pc.profile, size: 180, full: true)),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(l.welcomeTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 8),
          Text(l.welcomeBody, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          _notice(Icons.medical_information_outlined, l.medicalNoticeTitle, l.medicalNotice),
          const SizedBox(height: 12),
          _notice(Icons.lock_outline, l.privacyNoticeTitle, l.privacySummary),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showLegalText(context, LegalText.privacy),
              child: Text(l.readPrivacyPolicy),
            ),
          ),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: Text(l.consentLabel),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          Center(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fr', label: Text('Français')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {Localizations.localeOf(context).languageCode},
              onSelectionChanged: (s) {
                final repo = context.read<NotesRepository>();
                repo.updateSettings(repo.settings.copyWith(locale: s.first));
              },
            ),
          ),
        ],
      );

  Widget _notice(IconData icon, String title, String body) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(body),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _question(String title, String? help, List<Widget> options) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ),
          if (help != null) ...[
            const SizedBox(height: 8),
            Text(help),
          ],
          const SizedBox(height: 16),
          ...options,
        ],
      );

  Widget _q1(AppLocalizations l, ProfileController pc) => _question(
        l.q1Title,
        null,
        [
          RadioGroup<_Light>(
            groupValue: _light,
            onChanged: (x) => setState(() => _light = x),
            child: Column(children: [
              for (final (v, label) in [
                (_Light.hurts, l.q1Hurts),
                (_Light.sometimes, l.q1Sometimes),
                (_Light.fine, l.q1Fine),
              ])
                RadioListTile<_Light>(value: v, title: Text(label)),
            ]),
          ),
        ],
      );

  Widget _q2(AppLocalizations l, ProfileController pc) => _question(
        l.q2Title,
        l.q2Help,
        [
          for (final (n, label) in [
            (VisionNeed.b, l.symptomBlends),
            (VisionNeed.c, l.symptomColors),
            (VisionNeed.e, l.symptomBlurry),
            (VisionNeed.d, l.symptomField),
          ])
            CheckboxListTile(
              value: _reading.contains(n),
              title: Text(label),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => v == true ? _reading.add(n) : _reading.remove(n)),
            ),
        ],
      );

  Widget _q3(AppLocalizations l, ProfileController pc) => _question(
        l.q3Title,
        null,
        [
          RadioGroup<_Time>(
            groupValue: _time,
            onChanged: (x) => setState(() => _time = x),
            child: Column(children: [
              for (final (v, label) in [
                (_Time.day, l.q3Day),
                (_Time.evening, l.q3Evening),
                (_Time.both, l.q3Both),
              ])
                RadioListTile<_Time>(value: v, title: Text(label)),
            ]),
          ),
        ],
      );

  Widget _choose(AppLocalizations l, ProfileController pc) {
    final suggestions = _suggestions(context);
    _chosen ??= suggestions.first.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.chooseTitle, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: 8),
        Text(l.chooseHelp),
        const SizedBox(height: 16),
        for (final p in suggestions) ...[
          Semantics(
            selected: _chosen == p.id,
            button: true,
            label: profileDisplayName(context, p),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() => _chosen = p.id);
                pc.preview(p);
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    width: 3,
                    color: _chosen == p.id
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                      child: Row(children: [
                        Icon(_chosen == p.id ? Icons.radio_button_checked : Icons.radio_button_off),
                        const SizedBox(width: 8),
                        Expanded(child: Text(profileDisplayName(context, p),
                            style: Theme.of(context).textTheme.titleMedium)),
                      ]),
                    ),
                    SampleNote(profile: p, compact: true),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(l.changeLaterHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  late final ProfileController _pc;

  @override
  void initState() {
    super.initState();
    _pc = context.read<ProfileController>();
  }

  @override
  void dispose() {
    // L'aperçu ne doit pas survivre à l'écran.
    final pc = _pc;
    WidgetsBinding.instance.addPostFrameCallback((_) => pc.preview(null));
    super.dispose();
  }
}
