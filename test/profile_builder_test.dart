// Le test guidé doit toujours produire un profil qui respecte sa plage de
// contraste (section 5), quelles que soient les réponses.
import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/color/contrast.dart';
import 'package:monako/core/color/oklch.dart';
import 'package:monako/core/profiles/profile_builder.dart';
import 'package:monako/core/profiles/visual_profile.dart';
import 'package:monako/core/roles.dart';

void main() {
  const papers = [
    Oklch(0.2, 0.0, 0),
    Oklch(0.27, 0.01, 280),
    Oklch(0.22, 0.03, 250),
    Oklch(0.9, 0.035, 85),
    Oklch(0.95, 0.025, 95),
    Oklch(0.88, 0.0, 0),
  ];

  for (final paper in papers) {
    for (final contrast in [7.0, 9.0, 12.0, 15.0]) {
      for (final confusion in [false, true]) {
        test('fond L=${paper.l} contraste $contrast daltonisme=$confusion', () {
          final a = CalibrationAnswers(
              paper: paper, contrast: contrast, colorConfusion: confusion);
          final p = buildCalibratedProfile(a, id: 'x', name: 'x');
          final range = p.contrastRange;
          for (final r in InkRole.contrastChecked) {
            final ratio = contrastRatio(p.color(r), p.paper);
            expect(range.contains(ratio), isTrue,
                reason: '${r.key} ${ratio.toStringAsFixed(2)} hors $range');
          }
          for (final r in InkRole.highlights) {
            final over = composite(
                p.color(r).withValues(alpha: p.stroke.highlightOpacity), p.paper);
            expect(contrastRatio(p.ink, over), greaterThanOrEqualTo(range.min));
          }
          expect(p.stroke.rolePatterns, confusion);
          if (confusion) expect(p.needs, contains(VisionNeed.c));
        });
      }
    }
  }

  test('besoins déduits sans diagnostic', () {
    const dark = CalibrationAnswers(paper: Oklch(0.22, 0, 0), contrast: 9);
    expect(dark.needs, contains(VisionNeed.a));
    const strong = CalibrationAnswers(paper: Oklch(0.2, 0, 0), contrast: 15);
    expect(strong.needs, {VisionNeed.b});
    const big = CalibrationAnswers(textSize: 28, lineHeight: 1.8);
    expect(big.needs, containsAll([VisionNeed.d, VisionNeed.e]));
    final p = buildCalibratedProfile(big, id: 'x', name: 'x');
    expect(p.simplifiedUi, isTrue);
    expect(p.text.baseSize, 28);
  });
}
