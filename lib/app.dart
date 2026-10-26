import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/local_store.dart';
import 'data/repository.dart';
import 'data/sync_service.dart';
import 'l10n/app_localizations.dart';
import 'services/asset_renderer.dart';
import 'services/auth_service.dart';
import 'services/ocr/ocr_service.dart';
import 'services/profile_controller.dart';
import 'services/speech_service.dart';
import 'ui/library/library_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/pause_reminder.dart';
import 'ui/widgets/rescue_gesture.dart';

class MonakoApp extends StatefulWidget {
  const MonakoApp({super.key, required this.store, this.client});

  final LocalStore store;
  final SupabaseClient? client;

  @override
  State<MonakoApp> createState() => _MonakoAppState();
}

class _MonakoAppState extends State<MonakoApp> with WidgetsBindingObserver {
  late final SyncService sync = SyncService(widget.client, widget.store);
  late final NotesRepository repo = NotesRepository(widget.store, sync);
  late final ProfileController profiles = ProfileController(repo);
  late final AuthService auth = AuthService(widget.client, widget.store, repo);
  late final AssetRenderer renderer = AssetRenderer(repo);
  final SpeechService speech = SpeechService();
  final OcrService ocr = OcrService();
  Timer? _periodic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Filet de sécurité: synchronisation périodique en plus de
    // l'enregistrement automatique (5 s) et du temps réel.
    _periodic = Timer.periodic(const Duration(seconds: 60), (_) => sync.sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync.sync();
    if (state == AppLifecycleState.paused) repo.scheduleSync(now: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodic?.cancel();
    profiles.dispose();
    auth.dispose();
    repo.dispose();
    sync.dispose();
    speech.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: profiles),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: speech),
        Provider.value(value: renderer),
        Provider.value(value: ocr),
      ],
      child: Consumer2<ProfileController, NotesRepository>(
        builder: (context, pc, repo, _) {
          final profile = pc.profile;
          final locale = repo.settings.locale;
          return MaterialApp(
            title: 'Monako',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(profile),
            themeAnimationDuration: const Duration(milliseconds: 200),
            locale: locale == null ? null : Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              // Le texte de l'interface suit la taille du système (Dynamic
              // Type) et grandit un peu avec le profil (D: vision réduite).
              final boost = profile.text.sizeMultiplier.clamp(1.0, 1.3);
              Widget app = MediaQuery(
                data: mq.copyWith(
                  textScaler: _ScaledTextScaler(mq.textScaler, boost),
                ),
                child: RescueGesture(child: PauseReminder(child: child!)),
              );
              final warm = profile.filters.warmTint;
              if (warm > 0.001) {
                app = ColorFiltered(
                  colorFilter: ColorFilter.matrix(warmTintMatrix(warm)),
                  child: app,
                );
              }
              return app;
            },
            home: repo.settings.onboardingDone
                ? const LibraryScreen()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}

class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this.base, this.factor);
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.scale(14) / 14 * factor;

  @override
  bool operator ==(Object other) =>
      other is _ScaledTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
