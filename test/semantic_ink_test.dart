// Critères d'acceptation du MVP (section 12):
// « Une note écrite avec le rôle ink.accent2 s'affiche dans la couleur du
//   profil actif, sans modifier le fichier. »
// « Une note ouverte par un autre élève avec un profil différent s'affiche
//   dans ses couleurs à lui. »
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/color/hex.dart';
import 'package:monako/core/profiles/palette.dart';
import 'package:monako/core/profiles/presets.dart';
import 'package:monako/core/render/page_painter.dart';
import 'package:monako/core/roles.dart';
import 'package:monako/data/models.dart';

void main() {
  final stroke = InkStroke(
    id: 's1',
    notebookId: 'n1',
    pageId: 'p1',
    role: InkRole.accent2,
    width: 2.4,
    points: Float32List.fromList([120.5, 80.1, 0.62, 121.0, 82.4, 0.66]),
  );

  test('le fichier enregistre le rôle, jamais une couleur', () {
    final row = stroke.toRow();
    expect(row['role'], 'ink.accent2');
    final text = jsonEncode(row);
    expect(RegExp(r'#[0-9A-Fa-f]{6}').hasMatch(text), isFalse);
    expect(row['fixed_color'], isNull);
  });

  test('format de la fiche (section 4)', () {
    final j = stroke.toSpecJson();
    expect(j['type'], 'stroke');
    expect(j['role'], 'ink.accent2');
    expect(j['width'], 2.4);
    expect((j['points'] as List).first[0], closeTo(120.5, 1e-4));
  });

  test('même fichier, couleurs différentes selon le profil', () {
    final row = jsonEncode(stroke.toRow());
    final standard = strokeColor(ResolvedPalette.of(Presets.standard), stroke);
    final a1 = strokeColor(ResolvedPalette.of(Presets.a1), stroke);
    expect(standard, Presets.standard.color(InkRole.accent2));
    expect(a1, Presets.a1.color(InkRole.accent2));
    expect(standard, isNot(a1));
    // Le fichier n'a pas changé.
    expect(jsonEncode(stroke.toRow()), row);
  });

  test('aller-retour des points en binaire compact', () {
    final row = stroke.toRow();
    final back = InkStroke.fromRow(row, highlight: false);
    expect(back.points, stroke.points);
    expect(back.role, InkRole.accent2);
  });

  test('lecture du format lisible [[x, y, p]]', () {
    final pts = InkStroke.decodePoints([
      [1, 2, 0.5],
      [3, 4, 0.6],
    ]);
    expect(pts.length, 6);
    expect(pts[3], 3);
  });

  test('couleur libre (fixed: true) recolorée à luminosité proche', () {
    final s = InkStroke(
      id: 's2',
      notebookId: 'n1',
      pageId: 'p1',
      role: InkRole.inkPrimary,
      width: 2,
      points: Float32List(0),
      fixedColor: '#000080',
    );
    final pal = ResolvedPalette.of(Presets.a1);
    final c = strokeColor(pal, s);
    // Un bleu marine foncé devient clair sur fond sombre, reste bleuté.
    expect(c, isNot(colorFromHex('#000080')));
    expect(c.b, greaterThan(c.r));
    // Recoloration désactivée pour ce trait: couleur d'origine.
    final raw = InkStroke.fromRow({...s.toRow(), 'recolor': false}, highlight: false);
    expect(strokeColor(pal, raw), colorFromHex('#000080'));
  });
}
