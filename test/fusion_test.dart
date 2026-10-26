import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/color/contrast.dart';
import 'package:monako/core/color/oklch.dart';
import 'package:monako/core/profiles/contrast_targets.dart';
import 'package:monako/core/profiles/presets.dart';
import 'package:monako/core/profiles/profile_tools.dart';
import 'package:monako/core/profiles/visual_profile.dart';
import 'package:monako/core/roles.dart';

void main() {
  test('plages: A + C = 7 à 10', () {
    final r = ContrastRange.forNeeds({VisionNeed.a, VisionNeed.c});
    expect(r.min, 7);
    expect(r.max, 10);
    expect(r.conflict, isFalse);
  });

  test('plages: A + B en conflit -> plage de A (la plus sûre)', () {
    final r = ContrastRange.forNeeds({VisionNeed.a, VisionNeed.b});
    expect(r.conflict, isTrue);
    expect(r.min, 7);
    expect(r.max, 10);
  });

  test('fusion A1 + C: fond de A, teintes de C, contraste dans la plage', () {
    final f = fuseProfiles([Presets.a1, Presets.c], id: 'f', name: 'A + C');
    final p = f.profile;
    expect(p.paper, Presets.a1.paper);
    expect(p.needs, {VisionNeed.a, VisionNeed.c});
    expect(p.stroke.rolePatterns, isTrue);
    for (final r in InkRole.contrastChecked) {
      final ratio = contrastRatio(p.color(r), p.paper);
      expect(p.contrastRange.contains(ratio), isTrue,
          reason: '${r.key} ${ratio.toStringAsFixed(2)}');
    }
    final hue = Oklch.fromColor(p.color(InkRole.accent1)).h;
    final okabe = Oklch.fromColor(Presets.c.color(InkRole.accent1)).h;
    expect((hue - okabe).abs(), lessThan(8));
  });

  test('fusion A + B signale le conflit', () {
    final f = fuseProfiles([Presets.a1, Presets.b], id: 'f', name: 'A + B');
    expect(f.conflicts, contains(FusionConflict.contrastCappedByLight));
    final ratio = contrastRatio(f.profile.ink, f.profile.paper);
    expect(ratio, lessThanOrEqualTo(10.05));
  });

  test('« ce profil me fatigue »: moins de contraste, plus chaud, reste dans la plage', () {
    final p = Presets.a1;
    final s = softerProfile(p);
    expect(contrastRatio(s.ink, s.paper), lessThan(contrastRatio(p.ink, p.paper)));
    expect(s.filters.warmTint, greaterThan(p.filters.warmTint));
    expect(contrastRatio(s.ink, s.paper), greaterThanOrEqualTo(p.contrastRange.min));
  });

  test('correction automatique ramène tout dans la plage', () {
    final bad = Presets.a1.withRole(InkRole.inkPrimary, const Oklch(0.99, 0, 0).toColor());
    final fixed = fitProfileToRange(bad);
    for (final r in InkRole.contrastChecked) {
      expect(fixed.contrastRange.contains(contrastRatio(fixed.color(r), fixed.paper)), isTrue);
    }
  });

  test('profil JSON (section 9): rôles manquants complétés par le profil de base', () {
    final p = VisualProfile.fromJson({
      'id': 'prof_a1',
      'name': 'Lumière sombre',
      'needs': ['A'],
      'roles': {
        'paper': '#26272B',
        'ink.primary': '#D9CFAF',
        'ink.accent1': '#E5B567',
        'highlight.1': '#5A5530',
      },
      'filters': {'warmTint': 0.3, 'pdfBrightnessCap': 0.7},
      'text': {'baseSize': 18, 'font': 'system', 'lineHeight': 1.5},
      'stroke': {'widthMultiplier': 1.0},
    }, base: Presets.a1);
    for (final r in InkRole.values) {
      expect(p.roles[r], isNotNull);
    }
    expect(p.filters.warmTint, 0.3);
    expect(p.text.baseSize, 18);
    expect(p.color(InkRole.accent2), Presets.a1.color(InkRole.accent2));
  });
}
