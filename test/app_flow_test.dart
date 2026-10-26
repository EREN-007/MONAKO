// Parcours de bout en bout en mode local (sans Supabase):
// accueil + consentement -> test de confort -> bibliothèque -> cahier ->
// trait au stylet -> changement de profil -> geste de secours.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:monako/app.dart';
import 'package:monako/core/profiles/presets.dart';
import 'package:monako/core/roles.dart';
import 'package:monako/data/local_store.dart';
import 'package:monako/data/user_settings.dart';
import 'package:monako/ui/editor/editor_screen.dart';
import 'package:monako/ui/library/library_screen.dart';

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('monako_flow').path);
  });

  testWidgets('parcours complet', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = LocalStore();
    await tester.runAsync(() async {
      await store.open(inMemory: true);
      await store.clearAll();
      // Interface en français pour ce test.
      await store.put(Tables.userSettings,
          const UserSettings(locale: 'fr').toRow(), dirty: false);
    });
    await tester.pumpWidget(MonakoApp(store: store));
    await tester.pump();

    // 1. Accueil: le message médical est affiché, « Suivant » exige le consentement.
    expect(find.textContaining('ne remplace pas un examen de la vue'), findsWidgets);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    // 2. Trois questions sur les symptômes.
    await tester.tap(find.text('Oui, la lumière me fait mal ou m’éblouit'));
    await tester.pump();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Le soir ou la nuit'));
    await tester.pump();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    // 3. Aperçu des profils; le premier proposé est « Lumière, sombre » (A1).
    expect(find.text('Lumière, sombre'), findsWidgets);
    await tester.tap(find.text('Garder ce profil'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    final settings = store.settingsRow!;
    expect(settings['active_profile_id'], Presets.a1Id);
    expect(settings['consent_at'], isNotNull);

    // 4. Nouveau cahier.
    await tester.tap(find.text('Nouveau cahier').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    // 5. Un trait au stylet avec l'encre d'accent 2.
    await tester.tap(find.bySemanticsLabel('Encre d’accent 2'));
    await tester.pump();
    final page = find.byKey(const ValueKey('page-input'));
    final center = tester.getCenter(page);
    final g = await tester.startGesture(center, kind: PointerDeviceKind.stylus);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(center + Offset(i * 8.0, i * 3.0));
    }
    await g.up();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    // Deux traits à la souris: chacun est validé au relâchement.
    for (var k = 0; k < 2; k++) {
      final m = await tester.startGesture(center + Offset(0, 60.0 + k * 40),
          kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
      for (var i = 1; i <= 8; i++) {
        await m.moveTo(center + Offset(i * 10.0, 60.0 + k * 40));
      }
      await m.up();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
    }
    expect(await tester.runAsync(() => store.allElementRows(Tables.strokes)), hasLength(3));
    // Annuler retire le dernier trait (pierre tombale, jamais d'effacement silencieux).
    await tester.tap(find.byTooltip('Annuler'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    final all = await tester.runAsync(() => store.allElementRows(Tables.strokes));
    expect(all!.where((r) => r['deleted'] != true), hasLength(2));

    final rows = (await tester.runAsync(() => store.allElementRows(Tables.strokes)))!
        .where((r) => r['role'] == InkRole.accent2.key && r['deleted'] != true)
        .toList();
    expect(rows, hasLength(2));
    final saved = jsonEncode(rows);

    // 6. Changement de profil via la pastille: le fichier ne change pas.
    await tester.tap(find.bySemanticsLabel(RegExp('Profil d’affichage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faible contraste').first);
    await tester.pumpAndSettle();
    expect(store.settingsRow!['active_profile_id'], Presets.bId);
    final after = (await tester.runAsync(() => store.allElementRows(Tables.strokes)))!
        .where((r) => r['role'] == InkRole.accent2.key && r['deleted'] != true)
        .toList();
    expect(jsonEncode(after), saved);

    // 7. Geste de secours: triple toucher -> profil par défaut (A1).
    await tester.tap(find.byTooltip('Déplacer la vue'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(center + const Offset(0, 200));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();
    expect(store.settingsRow!['active_profile_id'], Presets.a1Id);
    expect(find.textContaining('Profil de secours rétabli'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
