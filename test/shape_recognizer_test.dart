import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/ink/pressure.dart';
import 'package:monako/core/ink/shape_recognizer.dart';

List<Offset> wobble(List<Offset> pts, double amp) => [
      for (var i = 0; i < pts.length; i++)
        pts[i] + Offset(amp * math.sin(i * 1.7), amp * math.cos(i * 2.3)),
    ];

List<Offset> path(List<Offset> corners, int perSide) => [
      for (var i = 0; i < corners.length - 1; i++)
        for (var k = 0; k < perSide; k++)
          Offset.lerp(corners[i], corners[i + 1], k / perSide)!,
      corners.last,
    ];

void main() {
  test('ligne tremblée -> ligne droite', () {
    final s = recognizeShape(wobble(path([const Offset(10, 10), const Offset(300, 120)], 40), 2));
    expect(s?.kind, ShapeKind.line);
  });

  test('cercle à main levée -> ellipse', () {
    final pts = [
      for (var i = 0; i <= 60; i++)
        Offset(200 + 80 * math.cos(i * math.pi / 30), 200 + 60 * math.sin(i * math.pi / 30)),
    ];
    expect(recognizeShape(wobble(pts, 3))?.kind, ShapeKind.ellipse);
  });

  test('rectangle à main levée -> rectangle', () {
    final pts = path(const [
      Offset(50, 50), Offset(250, 50), Offset(250, 180), Offset(50, 180), Offset(52, 55),
    ], 20);
    expect(recognizeShape(wobble(pts, 2))?.kind, ShapeKind.rectangle);
  });

  test('triangle à main levée -> triangle', () {
    final pts = path(const [
      Offset(150, 30), Offset(260, 220), Offset(40, 220), Offset(148, 36),
    ], 25);
    expect(recognizeShape(wobble(pts, 2))?.kind, ShapeKind.triangle);
  });

  test('gribouillis -> rien (reste à main levée)', () {
    final pts = [
      for (var i = 0; i < 80; i++) Offset(100 + 60 * math.sin(i * 0.9), 100 + i * 2.0 + 30 * math.cos(i * 1.3)),
    ];
    expect(recognizeShape(pts), isNull);
  });

  test('pression: un appui léger garde de l’encre, le lissage retire le grain', () {
    final f = PressureFilter();
    expect(f.apply(0)!, greaterThanOrEqualTo(0.3));
    f.reset();
    final values = [for (final raw in [0.5, 0.1, 0.9, 0.1, 0.9]) f.apply(raw)!];
    for (var i = 1; i < values.length; i++) {
      expect((values[i] - values[i - 1]).abs(), lessThan(0.35));
    }
    expect(PressureFilter().apply(null), isNull);
  });
}
