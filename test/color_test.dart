import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/color/contrast.dart';
import 'package:monako/core/color/hex.dart';
import 'package:monako/core/color/oklch.dart';

void main() {
  test('OKLCH aller-retour', () {
    for (final hex in ['#26272B', '#D9CFAF', '#E69F00', '#56B4E9', '#7F7F7F']) {
      final c = colorFromHex(hex);
      expect(colorToHex(Oklch.fromColor(c).toColor()), hex);
    }
  });

  test('blanc: L = 1, noir: L = 0', () {
    expect(Oklch.fromColor(colorFromHex('#FFFFFF')).l, closeTo(1, 1e-3));
    expect(Oklch.fromColor(colorFromHex('#000000')).l, closeTo(0, 1e-3));
  });

  test('hors gamut: chroma réduit, luminosité gardée', () {
    final c = const Oklch(0.7, 0.4, 145).toColor();
    expect(Oklch.fromColor(c).l, closeTo(0.7, 0.01));
  });

  test('solveForContrast atteint la cible sur fond sombre et clair', () {
    for (final bg in ['#26272B', '#F3EEDD']) {
      final paper = colorFromHex(bg);
      final c = solveForContrast(paper, const Oklch(0.5, 0.1, 30), 8);
      expect(contrastRatio(c, paper), closeTo(8, 0.05), reason: bg);
    }
  });

  test('hex avec alpha', () {
    final c = colorFromHex('#FF000080');
    expect(c.a, closeTo(0.5, 0.01));
    expect(colorToHex(c), '#FF000080');
  });
}
