// « Mon profil » reste prioritaire: l'élève essaie librement d'autres
// affichages, y revient d'un toucher, et le retrouve à chaque ouverture.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:monako/core/profiles/presets.dart';
import 'package:monako/data/local_store.dart';
import 'package:monako/data/repository.dart';
import 'package:monako/data/sync_service.dart';
import 'package:monako/data/user_settings.dart';
import 'package:monako/services/profile_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('monako_home').path));

  test('essais libres, retour à mon profil, restauré au démarrage', () async {
    final store = LocalStore();
    await store.open(inMemory: true);
    await store.clearAll();
    final repo = NotesRepository(store, SyncService(null, store));
    await repo.updateSettings(const UserSettings().copyWith(
      onboardingDone: true,
      homeProfileId: Presets.a1Id,
      activeProfileId: Presets.a1Id,
    ));
    final pc = ProfileController(repo);
    expect(pc.home.id, Presets.a1Id);
    expect(pc.isTrying, isFalse);

    // Essai d'un autre affichage: mon profil ne change pas.
    await pc.setActive(Presets.dId);
    expect(pc.profile.id, Presets.dId);
    expect(pc.home.id, Presets.a1Id);
    expect(pc.isTrying, isTrue);

    // Retour d'un toucher.
    await pc.backToHome();
    expect(pc.profile.id, Presets.a1Id);
    expect(pc.isTrying, isFalse);

    // Un essai en cours… puis l'app est rouverte: mon profil revient.
    await pc.setActive(Presets.cId);
    pc.dispose();
    final reopened = ProfileController(repo);
    await Future<void>.delayed(Duration.zero);
    expect(repo.settings.activeProfileId, Presets.a1Id);
    expect(reopened.profile.id, Presets.a1Id);

    // Choisir un nouveau profil comme « mon profil ».
    await reopened.setHome(Presets.bId);
    expect(reopened.home.id, Presets.bId);
    expect(reopened.isTrying, isFalse);
    reopened.dispose();
  });

  test('comptes existants: le profil en cours devient mon profil', () async {
    final store = LocalStore();
    await store.open(inMemory: true);
    await store.clearAll();
    final repo = NotesRepository(store, SyncService(null, store));
    await repo.updateSettings(const UserSettings()
        .copyWith(onboardingDone: true, activeProfileId: Presets.eId));
    final pc = ProfileController(repo);
    await Future<void>.delayed(Duration.zero);
    expect(repo.settings.homeProfileId, Presets.eId);
    expect(pc.home.id, Presets.eId);
    pc.dispose();
  });
}
