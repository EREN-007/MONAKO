import 'dart:ui' show Color;

Color colorFromHex(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length == 8 && hex.length == 9) {
    // Format CSS #RRGGBBAA -> AARRGGBB
    h = h.substring(6) + h.substring(0, 6);
  }
  return Color(int.parse(h, radix: 16));
}

/// Hex CSS : #RRGGBB, ou #RRGGBBAA si l'alpha n'est pas 1.
String colorToHex(Color c) {
  String two(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final rgb = '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
  return c.a >= 0.999 ? rgb : '$rgb${two(c.a).toUpperCase()}';
}
