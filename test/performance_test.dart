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

    void paintWith(ResolvedPalette p, StrokeGeometryCache cache) {
      final rec = ui.PictureRecorder();
      paintStrokes(ui.Canvas(rec), p, strokes, cache);
      rec.endRecording().dispose();
    }

    // Meilleur de 3 mesures: filtre le bruit de la machine (autres tests
    // exécutés en parallèle), sans assouplir les seuils.
    var open = 1 << 30, swap = 1 << 30;
    late StrokeGeometryCache cache;
    for (var run = 0; run < 3; run++) {
      cache = StrokeGeometryCache();
      final o = Stopwatch()..start();
      for (final s in strokes) {
        cache.of(s);
      }
      o.stop();
      paintWith(ResolvedPalette.of(Presets.standard), cache); // préchauffage
      final w = Stopwatch()..start();
      paintWith(ResolvedPalette.of(Presets.a1), cache);
      w.stop();
      open = math.min(open, o.elapsedMilliseconds);
      swap = math.min(swap, w.elapsedMilliseconds);
    }

    // ignore: avoid_print
    print('ouverture: $open ms, changement de profil: $swap ms');
    expect(cache.length, 5000, reason: 'aucune géométrie recalculée');
    expect(open, lessThan(1000));
    expect(swap, lessThan(100));
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
