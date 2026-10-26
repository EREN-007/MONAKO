// Test de performance (sections 8 et 11): page de 5 000 traits.
// - ouverture (géométrie) en moins de 1 s;
// - changement de profil en moins de 100 ms (aucun trait recalculé).
// Seuils de la fiche, mesurés en mode test (JIT, sans GPU).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/profiles/palette.dart';
import 'package:monako/core/profiles/presets.dart';
import 'package:monako/core/render/page_painter.dart';
import 'package:monako/core/render/stroke_geometry.dart';
import 'package:monako/core/roles.dart';
import 'package:monako/data/models.dart';

List<InkStroke> makeStrokes(int n) {
  final rnd = math.Random(42);
  return [
    for (var i = 0; i < n; i++)
      InkStroke(
        id: 's$i',
        notebookId: 'n',
        pageId: 'p',
        role: InkRole.writingInks[i % InkRole.writingInks.length],
        width: 2.4,
        points: Float32List.fromList([
          for (var k = 0; k < 24; k++) ...[
            rnd.nextDouble() * 760 + 20 + k * 2,
            rnd.nextDouble() * 1000 + 40 + k,
            0.5 + rnd.nextDouble() * 0.3,
          ],
        ]),
      ),
  ];
}

void main() {
  test('5 000 traits: ouverture et changement de profil', () {
    final strokes = makeStrokes(5000);
    final cache = StrokeGeometryCache();

    final open = Stopwatch()..start();
    for (final s in strokes) {
      cache.of(s);
    }
    open.stop();

    void paintWith(ResolvedPalette p) {
      final rec = ui.PictureRecorder();
      paintStrokes(ui.Canvas(rec), p, strokes, cache);
      rec.endRecording().dispose();
    }

    paintWith(ResolvedPalette.of(Presets.standard)); // préchauffage
    final swap = Stopwatch()..start();
    final palette = ResolvedPalette.of(Presets.a1);
    paintWith(palette);
    swap.stop();

    // ignore: avoid_print
    print('ouverture: ${open.elapsedMilliseconds} ms, '
        'changement de profil: ${swap.elapsedMilliseconds} ms');
    expect(cache.length, 5000, reason: 'aucune géométrie recalculée');
    expect(open.elapsedMilliseconds, lessThan(1000));
    expect(swap.elapsedMilliseconds, lessThan(100));
  });

  test('le changement de profil ne touche pas la géométrie', () {
    final strokes = makeStrokes(10);
    final cache = StrokeGeometryCache();
    final before = [for (final s in strokes) cache.of(s)];
    final after = [for (final s in strokes) cache.of(s)];
    for (var i = 0; i < strokes.length; i++) {
      expect(identical(before[i], after[i]), isTrue);
    }
  });
}
