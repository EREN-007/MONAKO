import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profiles/visual_profile.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/profile_controller.dart';
import '../auth/auth_screen.dart';
import '../editor/editor_screen.dart';
import '../profiles/calibration_screen.dart';
import '../widgets/monako_logo.dart';
import '../widgets/profile_names.dart';
import '../widgets/profile_pill.dart';
import '../widgets/sample_note.dart';

/// Page d'accueil à chaque ouverture: « mon profil » en vedette, essai
/// d'autres affichages d'un toucher, reprise du dernier cahier.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  /// Ouvre la bibliothèque.
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pc = context.watch<ProfileController>();
    final repo = context.watch<NotesRepository>();
    final auth = context.watch<AuthService>();
    final theme = Theme.of(context);
    final home = pc.home;
    final recent = repo.allNotebooks.firstOrNull;
    final others = repo.allProfiles.where((p) => p.id != home.id).toList();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: MonakoLogo(profile: pc.profile, size: 170, full: true)),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(
                    auth.signedIn ? l.welcomeBackUser(auth.user?.email ?? '') : l.welcomeBack,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 4),
                Text(l.welcomeTagline, textAlign: TextAlign.center),
                const SizedBox(height: 24),

                // Mon profil
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        const Icon(Icons.star),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l.myProfileNamed(profileDisplayName(context, home)),
                              style: theme.textTheme.titleMedium),
                        ),
                        if (pc.isTrying)
                          TextButton.icon(
                            onPressed: pc.backToHome,
                            icon: const Icon(Icons.home_outlined),
                            label: Text(l.backToMyProfile),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      SampleNote(profile: pc.profile, compact: true),
                      if (pc.isTrying) ...[
                        const SizedBox(height: 8),
                        Text(l.tryingProfile(profileDisplayName(context, pc.profile)),
                            style: theme.textTheme.bodySmall),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Essayer un autre affichage
                Text(l.tryAnotherLook, style: theme.textTheme.titleMedium),
                Text(l.tryAnotherLookHelp, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: 128,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final VisualProfile p in [home, ...others])
                        LookTile(
                          profile: p,
                          selected: p.id == pc.chosen.id,
                          onTap: () => pc.setActive(p.id),
                          onMakeHome: () => pc.setHome(p.id),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => showProfileSheet(context, customize: true),
                  icon: const Icon(Icons.format_color_fill),
                  label: Text(l.customizeLook),
                ),
                const SizedBox(height: 24),

                // Actions
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: onContinue,
                  icon: const Icon(Icons.library_books_outlined),
                  label: Text(l.openMyNotes),
                ),
                if (recent != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () {
                      onContinue();
                      openNotebook(context, recent.id);
                    },
                    icon: const Icon(Icons.history_edu),
                    label: Text(l.resumeNotebook(recent.title), overflow: TextOverflow.ellipsis),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final p = await Navigator.push<VisualProfile>(
                        context, MaterialPageRoute(builder: (_) => const CalibrationScreen()));
                    if (p != null) await pc.setHome(p.id);
                  },
                  icon: const Icon(Icons.tune),
                  label: Text(l.calibrateMyVision),
                ),
                if (auth.configured && !auth.signedIn)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const AuthScreen())),
                    icon: const Icon(Icons.login),
                    label: Text(l.signInToSync),
                  ),
                const SizedBox(height: 16),
                Text(l.medicalNotice,
                    textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
