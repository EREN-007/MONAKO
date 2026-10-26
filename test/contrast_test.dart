// Test unitaire de contraste (section 11): pour chaque profil et chaque
// paire de rôles (encre, accents, surlignages sur paper), le ratio doit être
// dans la plage de la section 5; le test échoue sinon.
import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/color/contrast.dart';
import 'package:monako/core/color/hex.dart';
import 'package:monako/core/profiles/presets.dart';
import 'package:monako/core/roles.dart';

void main() {
  group('WCAG', () {
    test('noir sur blanc = 21:1', () {
      expect(contrastRatio(colorFromHex('#000000'), colorFromHex('#FFFFFF')),
          closeTo(21, 0.001));
    });
    test('symétrique', () {
      final a = colorFromHex('#26272B'), b = colorFromHex('#D9CFAF');
      expect(contrastRatio(a, b), contrastRatio(b, a));
    });
  });

  test('il y a exactement 6 profils de besoin', () {
    expect(Presets.needProfiles, hasLength(6));
  });

  for (final p in Presets.needProfiles) {
    group('profil ${p.id}', () {
      final range = p.contrastRange;

      test('chaque rôle a une valeur', () {
        for (final r in InkRole.values) {
          expect(p.roles[r], isNotNull, reason: r.key);
        }
      });

      for (final r in InkRole.contrastChecked) {
        test('${r.key} sur paper dans $range', () {
          final ratio = contrastRatio(p.color(r), p.paper);
          expect(range.contains(ratio), isTrue,
              reason: '${r.key}: ${ratio.toStringAsFixed(2)}:1 hors $range');
        });
      }

      for (final r in InkRole.highlights) {
        test('ink.primary lisible sur ${r.key}', () {
          final bg = composite(
              p.color(r).withValues(alpha: p.stroke.highlightOpacity), p.paper);
          final ratio = contrastRatio(p.ink, bg);
          expect(ratio, greaterThanOrEqualTo(range.min),
              reason: '${ratio.toStringAsFixed(2)}:1 < ${range.min}');
        });
      }

      test('jamais de blanc pur en fond (profils A et B)', () {
        expect(colorToHex(p.paper), isNot('#FFFFFF'));
      });
    });
  }

  test('ratios de la fiche technique (section 6)', () {
    const expected = {
      Presets.a1Id: 9.6,
      Presets.a2Id: 9.3,
      Presets.bId: 16.9,
      Presets.dId: 14.8,
      Presets.eId: 9.6,
    };
    expected.forEach((id, ratio) {
      final p = Presets.byId(id)!;
      expect(contrastRatio(p.ink, p.paper), closeTo(ratio, 0.1), reason: id);
    });
    // C: « environ 14:1 »
    expect(contrastRatio(Presets.c.ink, Presets.c.paper), closeTo(14, 1));
  });
}
