import 'dart:math' as math;
import 'dart:ui' show Color;

/// Conversions sRGB <-> OKLab <-> OKLCH (Björn Ottosson).
///
/// La fiche technique (section 5) impose de calculer les couleurs en OKLCH
/// pour garder la luminosité perçue quand la teinte change.
class Oklch {
  const Oklch(this.l, this.c, this.h);

  /// Luminosité perçue, 0 (noir) à 1 (blanc).
  final double l;

  /// Chroma (saturation), 0 à ~0.37.
  final double c;

  /// Teinte en degrés, 0 à 360.
  final double h;

  Oklch copyWith({double? l, double? c, double? h}) =>
      Oklch(l ?? this.l, c ?? this.c, h ?? this.h);

  factory Oklch.fromColor(Color color) =>
      fromSrgb(color.r, color.g, color.b);

  static Oklch fromSrgb(double r, double g, double b) {
    final lab = srgbToOklab(r, g, b);
    final c = math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
    var h = math.atan2(lab[2], lab[1]) * 180 / math.pi;
    if (h < 0) h += 360;
    return Oklch(lab[0], c, h);
  }

  /// Convertit en couleur sRGB. Si la couleur sort du gamut, le chroma est
  /// réduit (en gardant L et H) jusqu'à rentrer dans le gamut.
  Color toColor({double alpha = 1}) {
    var lo = 0.0, hi = c;
    var rgb = _toSrgbUnclamped(l, hi, h);
    if (_inGamut(rgb)) return _color(rgb, alpha);
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      final test = _toSrgbUnclamped(l, mid, h);
      if (_inGamut(test)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    rgb = _toSrgbUnclamped(l, lo, h);
    return _color(rgb, alpha);
  }

  static List<double> _toSrgbUnclamped(double l, double c, double h) {
    final hr = h * math.pi / 180;
    return oklabToSrgb(l, c * math.cos(hr), c * math.sin(hr));
  }

  static bool _inGamut(List<double> rgb) =>
      rgb.every((v) => v >= -1e-4 && v <= 1 + 1e-4);

  static Color _color(List<double> rgb, double alpha) => Color.from(
        alpha: alpha,
        red: rgb[0].clamp(0.0, 1.0),
        green: rgb[1].clamp(0.0, 1.0),
        blue: rgb[2].clamp(0.0, 1.0),
      );

  @override
  String toString() =>
      'Oklch(${l.toStringAsFixed(3)}, ${c.toStringAsFixed(3)}, ${h.toStringAsFixed(1)})';
}

double srgbToLinear(double v) =>
    v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double linearToSrgb(double v) => v <= 0.0031308
    ? 12.92 * v
    : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

/// sRGB (0..1, gamma) -> OKLab [L, a, b].
List<double> srgbToOklab(double r, double g, double b) {
  final lr = srgbToLinear(r), lg = srgbToLinear(g), lb = srgbToLinear(b);
  final l = _cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
  final m = _cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
  final s = _cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}

/// OKLab -> sRGB (0..1, gamma), non borné.
List<double> oklabToSrgb(double lightness, double a, double b) {
  final l = lightness + 0.3963377774 * a + 0.2158037573 * b;
  final m = lightness - 0.1055613458 * a - 0.0638541728 * b;
  final s = lightness - 0.0894841775 * a - 1.2914855480 * b;
  final l3 = l * l * l, m3 = m * m * m, s3 = s * s * s;
  return [
    linearToSrgb(4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3),
    linearToSrgb(-1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3),
    linearToSrgb(-0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3),
  ];
}
