import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profiles/presets.dart';
import '../../data/repository.dart';
import '../../data/sync_service.dart';
import '../../l10n/app_localizations.dart';
import '../../services/asset_renderer.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../auth/auth_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../profiles/profiles_screen.dart';
import '../widgets/profile_names.dart';
import 'legal_texts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = context.watch<NotesRepository>();
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();
    final s = repo.settings;
    final profiles = repo.allProfiles;

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Semantics(
            header: true,
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              children: [
                section(l.visualProfiles),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l.manageProfiles),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfilesScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.health_and_safety_outlined),
                  title: Text(l.rescueProfile),
                  subtitle: Text(l.rescueProfileHelp),
                  trailing: DropdownButton<String>(
                    value: Presets.all.any((p) => p.id == s.rescueProfileId)
                        ? s.rescueProfileId
                        : Presets.standardId,
                    onChanged: (v) => repo.updateSettings(s.copyWith(rescueProfileId: v)),
                    items: [
                      for (final p in Presets.all)
                        DropdownMenuItem(value: p.id, child: Text(profileDisplayName(context, p))),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.quiz_outlined),
                  title: Text(l.redoComfortTest),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const OnboardingScreen())),
                ),
                section(l.automaticModes),
                SwitchListTile(
                  secondary: const Icon(Icons.nights_stay_outlined),
                  title: Text(l.autoNight),
                  subtitle: Text(l.autoNightHelp(s.nightStartHour, s.nightEndHour)),
                  value: s.autoNight,
                  onChanged: (v) => repo.updateSettings(s.copyWith(
                      autoNight: v, nightProfileId: s.nightProfileId ?? Presets.a1Id)),
                ),
                if (s.autoNight) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 72, right: 16),
                    title: Text(l.nightProfile),
                    trailing: DropdownButton<String>(
                      value: profiles.any((p) => p.id == s.nightProfileId)
                          ? s.nightProfileId
                          : Presets.a1Id,
                      onChanged: (v) => repo.updateSettings(s.copyWith(nightProfileId: v)),
                      items: [
                        for (final p in profiles)
                          DropdownMenuItem(value: p.id, child: Text(profileDisplayName(context, p))),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 72, right: 16),
                    title: Text(l.nightHours),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      _HourPicker(
                        value: s.nightStartHour,
                        label: l.nightStart,
                        onChanged: (h) => repo.updateSettings(s.copyWith(nightStartHour: h)),
                      ),
                      const Text(' – '),
                      _HourPicker(
                        value: s.nightEndHour,
                        label: l.nightEnd,
                        onChanged: (h) => repo.updateSettings(s.copyWith(nightEndHour: h)),
                      ),
                    ]),
                  ),
                ],
                SwitchListTile(
                  secondary: const Icon(Icons.wb_twilight_outlined),
                  title: Text(l.eveningWarmth),
                  subtitle: Text(l.eveningWarmthHelp),
                  value: s.eveningWarmth,
                  onChanged: (v) => repo.updateSettings(s.copyWith(eveningWarmth: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_outlined),
                  title: Text(l.pauseReminder),
                  subtitle: Text(l.pauseReminderHelp),
                  value: s.pauseReminder,
                  onChanged: (v) => repo.updateSettings(s.copyWith(pauseReminder: v)),
                ),
                section(l.writing),
                SwitchListTile(
                  secondary: const Icon(Icons.touch_app_outlined),
                  title: Text(l.fingerDrawing),
                  subtitle: Text(l.fingerDrawingHelp),
                  value: s.fingerDrawing,
                  onChanged: (v) => repo.updateSettings(s.copyWith(fingerDrawing: v)),
                ),
                section(l.language),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(l.language),
                  trailing: DropdownButton<String?>(
                    value: s.locale,
                    onChanged: (v) => repo.updateSettings(
                        v == null ? s.copyWith(clearLocale: true) : s.copyWith(locale: v)),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.systemLanguage)),
                      const DropdownMenuItem(value: 'fr', child: Text('Français')),
                      const DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                  ),
                ),
                section(l.account),
                if (!auth.configured)
                  ListTile(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: Text(l.localModeTitle),
                    subtitle: Text(l.localModeHelp),
                  )
                else if (!auth.signedIn)
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: Text(l.signIn),
                    subtitle: Text(l.accountWhy),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AuthScreen())),
                  )
                else ...[
                  ListTile(
                    leading: const Icon(Icons.account_circle_outlined),
                    title: Text(auth.user?.email ?? ''),
                    subtitle: Text(sync.lastSync == null
                        ? l.neverSynced
                        : l.lastSynced(TimeOfDay.fromDateTime(sync.lastSync!).format(context))),
                    trailing: IconButton(
                      tooltip: l.syncNow,
                      icon: const Icon(Icons.sync),
                      onPressed: sync.sync,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(l.signOut),
                    subtitle: Text(l.signOutHelp),
                    onTap: () => auth.signOut(),
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(l.exportMyData),
                  subtitle: Text(l.exportMyDataHelp),
                  onTap: () =>
                      ExportService(repo, context.read<AssetRenderer>()).shareAllData(),
                ),
                if (auth.signedIn)
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined,
                        color: Theme.of(context).colorScheme.error),
                    title: Text(l.deleteAccount),
                    subtitle: Text(l.deleteAccountHelp),
                    onTap: () => _confirmDelete(context, auth),
                  ),
                section(l.about),
                ListTile(
                  leading: const Icon(Icons.medical_information_outlined),
                  title: Text(l.medicalNoticeTitle),
                  subtitle: Text(l.medicalNotice),
                  onTap: () => showLegalText(context, LegalText.medical),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l.privacyPolicyTitle),
                  onTap: () => showLegalText(context, LegalText.privacy),
                ),
                ListTile(
                  leading: const Icon(Icons.accessibility_new),
                  title: Text(l.accessibilityTitle),
                  onTap: () => showLegalText(context, LegalText.accessibility),
                ),
                AboutListTile(
                  icon: const Icon(Icons.info_outline),
                  applicationName: 'Monako',
                  applicationVersion: '1.0.0',
                  applicationLegalese: l.medicalNotice,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AuthService auth) async {
    final l = AppLocalizations.of(context);
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.deleteAccount),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.deleteAccountConfirm),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              decoration: InputDecoration(labelText: l.typeDelete),
              onChanged: (_) => setState(() {}),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: confirm.text.trim().toUpperCase() == l.deleteWord.toUpperCase()
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text(l.deleteAccount),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.deleteAccount();
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric('$e'))));
    }
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({required this.value, required this.label, required this.onChanged});
  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: DropdownButton<int>(
          value: value,
          onChanged: (v) => v == null ? null : onChanged(v),
          items: [
            for (var h = 0; h < 24; h++)
              DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')} h')),
          ],
        ),
      );
}
