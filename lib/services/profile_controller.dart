import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/profiles/palette.dart';
import '../core/profiles/presets.dart';
import '../core/profiles/profile_tools.dart';
import '../core/profiles/visual_profile.dart';
import '../data/models.dart';
import '../data/repository.dart';

/// Profil visuel actif de l'élève et règles qui le choisissent:
/// profil choisi, profil imposé à un cahier, mode nuit automatique, filtre
/// chaud de fin de journée, aperçu en direct et geste de secours.
class ProfileController extends ChangeNotifier {
  ProfileController(this.repo) {
    repo.addListener(_onRepo);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _recompute());
    _recompute();
  }

  final NotesRepository repo;
  late final Timer _timer;
  DateTime Function() clock = DateTime.now;

  VisualProfile? _preview;
  bool _rescueOverride = false;
  VisualProfile? _effective;
  final _palettes = Expando<ResolvedPalette>();

  /// Profil appliqué à l'interface et aux notes sans profil imposé.
  VisualProfile get profile => _preview ?? _effective!;

  /// Table de rendu du profil courant (recalculée seulement s'il change).
  ResolvedPalette get palette => paletteOf(profile);

  ResolvedPalette paletteOf(VisualProfile p) =>
      _palettes[p] ??= ResolvedPalette.of(p);

  /// Profil choisi par l'élève (sans le mode nuit).
  VisualProfile get chosen =>
      repo.profileById(repo.settings.activeProfileId) ??
      repo.profileById(repo.settings.rescueProfileId) ??
      Presets.standard;

  VisualProfile get rescueProfile =>
      repo.profileById(repo.settings.rescueProfileId) ?? Presets.standard;

  bool get isNight {
    final s = repo.settings;
    if (!s.autoNight || s.nightProfileId == null) return false;
    final h = clock().hour;
    return s.nightStartHour <= s.nightEndHour
        ? h >= s.nightStartHour && h < s.nightEndHour
        : h >= s.nightStartHour || h < s.nightEndHour;
  }

  /// Teinte chaude progressive entre 18 h et 22 h (jusqu'à +30 %).
  double get eveningWarmth {
    if (!repo.settings.eveningWarmth) return 0;
    final now = clock();
    final h = now.hour + now.minute / 60;
    if (h < 18) return h < 6 ? 0.3 : 0;
    return ((h - 18) / 4).clamp(0.0, 1.0) * 0.3;
  }

  void _onRepo() => _recompute();

  void _recompute() {
    var p = chosen;
    if (!_rescueOverride && isNight) {
      p = repo.profileById(repo.settings.nightProfileId) ?? p;
    }
    p = withEveningWarmth(p, eveningWarmth);
    final changed = !_sameProfile(p, _effective);
    _effective = p;
    if (changed) notifyListeners();
  }

  static bool _sameProfile(VisualProfile a, VisualProfile? b) =>
      b != null &&
      a.id == b.id &&
      a.modifiedAt == b.modifiedAt &&
      a.filters.warmTint == b.filters.warmTint;

  /// Profil d'affichage d'un cahier: le profil imposé au cahier s'il existe
  /// (et qu'il appartient à l'élève), sinon le profil actif.
  VisualProfile profileFor(Notebook? n) {
    if (_preview != null || _rescueOverride || n?.linkedProfileId == null) {
      return profile;
    }
    final linked = repo.profileById(n!.linkedProfileId);
    return linked == null ? profile : withEveningWarmth(linked, eveningWarmth);
  }

  /// Change de profil (moins de 2 s, sans quitter la note), avec retour
  /// haptique léger pour confirmer sans regarder.
  Future<void> setActive(String id) async {
    _rescueOverride = false;
    _preview = null;
    HapticFeedback.lightImpact();
    await repo.updateSettings(repo.settings.copyWith(activeProfileId: id));
    _recompute();
    notifyListeners();
  }

  /// Geste de secours: revient au profil par défaut de l'élève si un
  /// réglage rend la page illisible.
  Future<void> rescue() async {
    _preview = null;
    _rescueOverride = true;
    HapticFeedback.mediumImpact();
    await repo.updateSettings(
        repo.settings.copyWith(activeProfileId: repo.settings.rescueProfileId));
    _recompute();
    notifyListeners();
  }

  /// Aperçu immédiat d'un réglage avant de l'appliquer.
  void preview(VisualProfile? p) {
    _preview = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer.cancel();
    repo.removeListener(_onRepo);
    super.dispose();
  }
}
