// Test de rendu (section 11): capture de référence de chaque profil sur une
// page échantillon, comparée à chaque version.
// Mettre à jour après un changement voulu: flutter test --update-goldens
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/profiles/palette.dart';
import 'package:monako/core/profiles/presets.dart';
import 'package:monako/core/render/page_painter.dart';
import 'package:monako/core/render/stroke_geometry.dart';
import 'package:monako/core/roles.dart';
import 'package:monako/data/models.dart';

InkStroke _wave(String id, InkRole role, double y, {bool highlight = false}) =>
    InkStroke(
      id: id,
      notebookId: 'n',
      pageId: 'p',
      role: role,
      width: highlight ? 18 : 3,
      highlight: highlight,
      points: Float32List.fromList([
        for (var x = 30.0; x <= 370; x += 10)
          ...[x, y + (highlight ? 0 : 6 * ((x ~/ 10) % 4 - 1.5)), 0.6],
      ]),
    );

void main() {
  final strokes = [
    _wave('a', InkRole.inkPrimary, 60),
    _wave('b', InkRole.inkSecondary, 95),
    _wave('c', InkRole.accent1, 130),
    _wave('d', InkRole.accent2, 165),
    _wave('e', InkRole.accent3, 200),
    _wave('f', InkRole.accent4, 235),
    _wave('g', InkRole.heading, 270),
  ];
  final highlights = [
    _wave('h1', InkRole.highlight1, 60, highlight: true),
    _wave('h2', InkRole.highlight2, 130, highlight: true),
    _wave('h3', InkRole.highlight3, 200, highlight: true),
    _wave('h4', InkRole.highlight4, 270, highlight: true),
  ];

  for (final profile in Presets.all) {
    testWidgets('rendu ${profile.id}', (tester) async {
      final palette = ResolvedPalette.of(profile);
      final cache = StrokeGeometryCache();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: 400,
              height: 320,
              child: Stack(children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: PageBackgroundPainter(
                        palette: palette, template: PageTemplate.lined),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: InkPainter(
                      palette: palette,
                      strokes: strokes,
                      highlights: highlights,
                      cache: cache,
                      version: 0,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ));
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/page_${profile.id}.png'),
      );
    });
  }
}
