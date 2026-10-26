import 'dart:ui' show Color;

import 'oklch.dart';

/// Luminance relative WCAG 2.x :
/// L = 0.2126 R_lin + 0.7152 G_lin + 0.0722 B_lin
double relativeLuminance(Color c) =>
    0.2126 * srgbToLinear(c.r) +
    0.7152 * srgbToLinear(c.g) +
    0.0722 * srgbToLinear(c.b);

/// Ratio de contraste WCAG : C = (L_clair + 0.05) / (L_foncé + 0.05).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a), lb = relativeLuminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Compose [top] (avec son alpha) par-dessus [bottom] opaque.
Color composite(Color top, Color bottom) {
  final a = top.a;
  return Color.from(
    alpha: 1,
    red: top.r * a + bottom.r * (1 - a),
    green: top.g * a + bottom.g * (1 - a),
    blue: top.b * a + bottom.b * (1 - a),
  );
}

bool isDarkColor(Color c) => relativeLuminance(c) < 0.18;

/// Cherche, à teinte et chroma fixés, la luminosité OKLCH qui donne un
/// contraste aussi proche que possible de [target] contre [background].
/// La couleur est éclaircie sur fond sombre et assombrie sur fond clair.
Color solveForContrast(Color background, Oklch hue, double target) {
  final darkBg = isDarkColor(background);
  var lo = darkBg ? Oklch.fromColor(background).l : 0.0;
  var hi = darkBg ? 1.0 : Oklch.fromColor(background).l;
  Color best = hue.copyWith(l: darkBg ? hi : lo).toColor();
  for (var i = 0; i < 30; i++) {
    final mid = (lo + hi) / 2;
    final c = hue.copyWith(l: mid).toColor();
    final r = contrastRatio(c, background);
    best = c;
    // Sur fond sombre, plus L monte, plus le contraste monte.
    final tooLow = r < target;
    if (darkBg == tooLow) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return best;
}

/// Version qui garantit un contraste d'au moins [target] (arrondi vers le haut).
Color ensureMinContrast(Color background, Color color, double target) {
  if (contrastRatio(color, background) >= target) return color;
  final o = Oklch.fromColor(color);
  var c = solveForContrast(background, o, target + 0.02);
  if (contrastRatio(c, background) < target) {
    c = solveForContrast(background, o.copyWith(c: o.c * 0.5), target + 0.05);
  }
  return c;
}
