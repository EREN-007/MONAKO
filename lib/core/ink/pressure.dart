import 'dart:math' as math;

/// Adoucit la pression du stylet pendant un trait.
///
/// 1. Courbe: un appui léger garde au moins ~30 % de l'épaisseur, pour que
///    le trait ne « manque jamais d'encre ».
/// 2. Lissage exponentiel: supprime le grain des capteurs (variations
///    brusques d'un point à l'autre).
class PressureFilter {
  PressureFilter({this.floor = 0.3, this.gamma = 0.65, this.smoothing = 0.55});

  final double floor;
  final double gamma;

  /// Part de l'ancienne valeur gardée à chaque point (0 = aucun lissage).
  final double smoothing;
  double? _last;

  void reset() => _last = null;

  /// [raw] entre 0 et 1, ou null si l'appareil ne mesure pas la pression.
  double? apply(double? raw) {
    if (raw == null) return null;
    final curved = floor + (1 - floor) * math.pow(raw.clamp(0.0, 1.0), gamma);
    final last = _last;
    final v = last == null ? curved : last * smoothing + curved * (1 - smoothing);
    _last = v;
    return v;
  }
}
