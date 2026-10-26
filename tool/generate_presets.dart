// Calcule les encres d'accent, titres et surlignages des profils prédéfinis
// pour atteindre la cible de contraste de chaque profil (section 6).
// Usage: flutter test tool/generate_presets.dart
// Les valeurs imprimées sont recopiées dans lib/core/profiles/presets.dart.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/color/contrast.dart';
import 'package:monako/core/color/hex.dart';
import 'package:monako/core/color/oklch.dart';

class Spec {
  Spec(this.id, this.paper, this.ink, this.target, this.hues, this.chroma,
      this.secondaryTarget, this.headingHue, this.headingTarget, this.hlOpacity,
      this.min);
  final String id, paper, ink;
  final double target, chroma, secondaryTarget, headingTarget, hlOpacity, min;
  final List<double> hues;
  final List<double> headingHue;
}

// Teintes OKLCH: rouge, bleu, vert, violet.
const std = [29.0, 262.0, 145.0, 305.0];
// Okabe-Ito: vermillon, bleu ciel, vert bleuté, pourpre rougeâtre.
final okabe = ['#D55E00', '#56B4E9', '#009E73', '#CC79A7']
    .map((h) => Oklch.fromColor(colorFromHex(h)))
    .toList();

void main() {
  test('generate', () {
    final specs = [
      Spec('a1', '#26272B', '#D9CFAF', 8.2, std, 0.10, 7.4, [85, 0.09], 9.0, 0.55, 7),
      Spec('a2', '#E8DCC0', '#3A3226', 8.0, std, 0.12, 7.3, [255, 0.08], 9.0, 0.45, 7),
      Spec('b', '#101010', '#FFF3B0', 13.5, std, 0.11, 12.6, [95, 0.10], 15.0, 0.6, 12),
      Spec('c', '#1B1B1F', '#EDEDED', 8.5, [], 0, 9.0, [75, 0.12], 11.0, 0.55, 7),
      Spec('d', '#0F1720', '#FFE98A', 11.5, std, 0.11, 10.8, [85, 0.12], 13.0, 0.6, 10),
      Spec('e', '#F3EEDD', '#3B3B3B', 8.3, std, 0.13, 7.6, [255, 0.10], 9.5, 0.45, 7),
    ];
    for (final s in specs) {
      final paper = colorFromHex(s.paper);
      final ink = colorFromHex(s.ink);
      final dark = isDarkColor(paper);
      final out = <String, String>{};
      out['ink.primary'] = s.ink;
      out['ratio'] = contrastRatio(ink, paper).toStringAsFixed(2);
      final inkO = Oklch.fromColor(ink);
      out['ink.secondary'] = colorToHex(solveForContrast(
          paper, inkO.copyWith(c: inkO.c * 0.6), s.secondaryTarget));
      final hues = s.id == 'c' ? okabe : s.hues.map((h) => Oklch(0.6, s.chroma, h)).toList();
      for (var i = 0; i < 4; i++) {
        out['ink.accent${i + 1}'] =
            colorToHex(solveForContrast(paper, hues[i], s.target));
      }
      out['heading'] = colorToHex(solveForContrast(
          paper, Oklch(0.6, s.headingHue[1], s.headingHue[0]), s.headingTarget));
      // Surlignages: jaune, vert, rose, bleu.
      final hlHues = [100.0, 145.0, 350.0, 240.0];
      final paperO = Oklch.fromColor(paper);
      for (var i = 0; i < 4; i++) {
        // Écart de luminosité maximal tel que l'encre principale garde le
        // contraste minimal + 0.4 sur le surlignage composé.
        double shift = 0.30;
        Color hl;
        while (true) {
          final l = dark ? paperO.l + shift : paperO.l - shift * 0.25;
          hl = Oklch(l.clamp(0, 1), dark ? 0.09 : 0.14, hlHues[i]).toColor();
          if (!dark) {
            // Sur fond clair, surligneur pastel: L élevée.
            hl = Oklch(0.93 - shift * 0.15, 0.12, hlHues[i]).toColor();
          }
          final comp = composite(hl.withValues(alpha: s.hlOpacity), paper);
          if (contrastRatio(ink, comp) >= s.min + 0.4 || shift < 0.02) break;
          shift -= 0.01;
        }
        out['highlight.${i + 1}'] = colorToHex(hl);
      }
      // Lignes du papier: faible contraste, visibles sans gêner.
      out['paper.line'] = colorToHex(solveForContrast(
          paper, paperO.copyWith(c: paperO.c * 0.5), 1.45));
      final ratios = <String>[];
      for (final k in out.keys.where((k) => k.startsWith('ink') || k == 'heading')) {
        ratios.add('$k=${contrastRatio(colorFromHex(out[k]!), paper).toStringAsFixed(2)}');
      }
      for (var i = 1; i <= 4; i++) {
        final comp = composite(
            colorFromHex(out['highlight.$i']!).withValues(alpha: s.hlOpacity), paper);
        ratios.add('hl$i=${contrastRatio(ink, comp).toStringAsFixed(2)}');
      }
      // ignore: avoid_print
      print('${s.id}: $out\n   $ratios');
    }
  });
}
