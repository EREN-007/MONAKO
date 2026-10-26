import 'dart:ui' show Color, lerpDouble;

import '../color/contrast.dart';
import '../color/oklch.dart';
import '../roles.dart';
import 'visual_profile.dart';

/// Table de rendu résolue: un rôle = une couleur (section 5, étape 1).
///
/// Le moteur de rendu ne fait qu'une recherche par index pour chaque trait:
/// changer de profil revient à échanger cette table.
class ResolvedPalette {
  ResolvedPalette._(
    this.colors, {
    required this.highlightOpacity,
    required this.widthMultiplier,
    required this.rolePatterns,
    required this.minContrast,
  });

  factory ResolvedPalette.of(VisualProfile p) => ResolvedPalette._(
        List.unmodifiable([for (final r in InkRole.values) p.roles[r]!]),
        highlightOpacity: p.stroke.highlightOpacity,
        widthMultiplier: p.stroke.widthMultiplier *
            (1 + 0.1 * p.filters.haloReduction),
        rolePatterns: p.stroke.rolePatterns,
        minContrast: p.contrastRange.min,
      );

  final List<Color> colors;
  final double highlightOpacity;
  final double widthMultiplier;
  final bool rolePatterns;
  final double minContrast;

  final Map<int, Color> _fixedCache = {};

  Color operator [](InkRole role) => colors[role.index];
  Color get paper => colors[InkRole.paper.index];
  Color get ink => colors[InkRole.inkPrimary.index];
  bool get isDark => isDarkColor(paper);

  Color highlight(InkRole role) =>
      colors[role.index].withValues(alpha: highlightOpacity);

  /// Couleur libre (fixed: true): recolorée par une couleur proche de même
  /// luminosité relative dans le profil (section 4). La luminosité est
  /// projetée de l'axe blanc→noir standard vers l'axe paper→ink du profil;
  /// la teinte est gardée, la saturation limitée.
  Color recolorFixed(Color fixed) {
    return _fixedCache.putIfAbsent(fixed.toARGB32(), () {
      final o = Oklch.fromColor(fixed);
      final pl = Oklch.fromColor(paper).l, il = Oklch.fromColor(ink).l;
      final l = lerpDouble(il, pl, o.l)!;
      final mapped = Oklch(l, o.c.clamp(0, 0.12), o.h).toColor();
      return ensureMinContrast(paper, mapped, minContrast);
    });
  }

  /// Interpolation pour le fondu de 200 ms au changement de profil.
  static ResolvedPalette lerp(ResolvedPalette a, ResolvedPalette b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return ResolvedPalette._(
      [
        for (var i = 0; i < a.colors.length; i++)
          Color.lerp(a.colors[i], b.colors[i], t)!,
      ],
      highlightOpacity: lerpDouble(a.highlightOpacity, b.highlightOpacity, t)!,
      widthMultiplier: lerpDouble(a.widthMultiplier, b.widthMultiplier, t)!,
      rolePatterns: t < 0.5 ? a.rolePatterns : b.rolePatterns,
      minContrast: b.minContrast,
    );
  }
}
