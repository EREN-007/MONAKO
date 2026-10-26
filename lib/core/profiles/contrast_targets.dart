import 'visual_profile.dart';

/// Plage de contraste texte/fond cible d'un profil (section 5).
///
/// Hypothèses de départ, à valider avec un optométriste.
class ContrastRange {
  const ContrastRange(this.min, this.max, {this.conflict = false});

  final double min;
  final double max;

  /// Vrai quand plusieurs besoins fusionnés se contredisent: la plage
  /// retenue est alors la plus sûre (celle de A, confort lumineux).
  final bool conflict;

  static const standard = ContrastRange(4.5, 21);

  static const Map<VisionNeed, ContrastRange> byNeed = {
    VisionNeed.a: ContrastRange(7, 10),
    VisionNeed.b: ContrastRange(12, 18),
    VisionNeed.c: ContrastRange(7, 21),
    VisionNeed.d: ContrastRange(10, 15),
    VisionNeed.e: ContrastRange(7, 12),
  };

  bool contains(double ratio) => ratio >= min - 0.005 && ratio <= max + 0.005;

  /// Fusion de plusieurs besoins (section 5): le contraste final est la
  /// valeur la plus élevée des cibles, plafonnée par la plage de A.
  factory ContrastRange.forNeeds(Set<VisionNeed> needs) {
    if (needs.isEmpty) return standard;
    final ranges = needs.map((n) => byNeed[n]!).toList();
    final highestMin = ranges.map((r) => r.min).reduce((a, b) => a > b ? a : b);
    final lowestMax = ranges.map((r) => r.max).reduce((a, b) => a < b ? a : b);
    if (needs.contains(VisionNeed.a)) {
      final a = byNeed[VisionNeed.a]!;
      if (highestMin > a.max) {
        // Contradiction (ex. A + B): on garde le réglage le plus sûr, A.
        return ContrastRange(a.min, a.max, conflict: true);
      }
      return ContrastRange(highestMin, lowestMax < a.max ? lowestMax : a.max);
    }
    if (highestMin > lowestMax) {
      return ContrastRange(lowestMax, lowestMax, conflict: true);
    }
    return ContrastRange(highestMin, lowestMax);
  }

  @override
  String toString() => '${min.toStringAsFixed(1)}:1 – ${max.toStringAsFixed(1)}:1';
}
