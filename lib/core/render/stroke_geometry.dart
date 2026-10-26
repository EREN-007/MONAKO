import 'dart:typed_data';
import 'dart:ui';

import 'package:perfect_freehand/perfect_freehand.dart';

import '../../data/models.dart';
import '../roles.dart';

/// Géométrie d'un trait, calculée une seule fois puis mise en cache.
///
/// La couleur n'en fait pas partie: au changement de profil, seule la
/// table rôle -> couleur change, aucun trait n'est recalculé (section 5).
class StrokeGeometry {
  StrokeGeometry(this.outline, this.centerline, this.baseWidth);

  /// Contour rempli (épaisseur variable selon la pression).
  final Path outline;

  /// Ligne médiane (motifs pointillés, épaississement).
  final Path centerline;
  final double baseWidth;
  final Map<StrokePattern, Path> _dashed = {};

  Path dashed(StrokePattern pattern) =>
      _dashed[pattern] ??= dashPath(centerline, pattern, baseWidth);
}

class StrokeGeometryCache {
  final Map<String, (Float32List, StrokeGeometry)> _cache = {};

  StrokeGeometry of(InkStroke s) {
    final hit = _cache[s.id];
    if (hit != null && identical(hit.$1, s.points)) return hit.$2;
    final g = build(s);
    _cache[s.id] = (s.points, g);
    return g;
  }

  void retainOnly(Iterable<String> ids) {
    final keep = ids.toSet();
    _cache.removeWhere((k, _) => !keep.contains(k));
  }

  int get length => _cache.length;

  static StrokeGeometry build(InkStroke s) {
    final n = s.pointCount;
    final pressure = s.hasPressure;
    final pts = <PointVector>[
      for (var i = 0; i < n; i++)
        PointVector(s.points[i * 3], s.points[i * 3 + 1],
            pressure ? s.points[i * 3 + 2] : null),
    ];
    return StrokeGeometry(
      outlinePath(pts, s.width, highlight: s.highlight, complete: true),
      centerlinePath(pts),
      s.width,
    );
  }

  static StrokeOptions options(double width,
          {required bool highlight, required bool complete, bool simulate = true}) =>
      StrokeOptions(
        size: width,
        thinning: highlight ? 0 : 0.55,
        smoothing: 0.5,
        streamline: highlight ? 0.6 : 0.45,
        simulatePressure: simulate,
        isComplete: complete,
      );

  static Path outlinePath(List<PointVector> pts, double width,
      {required bool highlight, required bool complete}) {
    final hasPressure = pts.isNotEmpty && pts.first.pressure != null;
    final outline = getStroke(
      pts,
      options: options(width,
          highlight: highlight, complete: complete, simulate: !hasPressure),
    );
    final path = Path();
    if (outline.isEmpty) return path;
    if (outline.length < 3) {
      path.addOval(Rect.fromCircle(center: outline.first, radius: width / 2));
      return path;
    }
    path.moveTo(outline[0].dx, outline[0].dy);
    for (var i = 1; i < outline.length - 1; i++) {
      final p0 = outline[i], p1 = outline[i + 1];
      path.quadraticBezierTo(p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    }
    path.close();
    return path;
  }

  static Path centerlinePath(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 1) {
      path.lineTo(pts.first.dx + 0.01, pts.first.dy);
      return path;
    }
    for (var i = 1; i < pts.length - 1; i++) {
      final p0 = pts[i], p1 = pts[i + 1];
      path.quadraticBezierTo(p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }
}

/// Découpe une ligne en motif (pointillé, tirets…) pour les élèves
/// daltoniens: le sens ne repose pas sur la seule teinte.
Path dashPath(Path source, StrokePattern pattern, double width) {
  final w = width < 1 ? 1.0 : width;
  final List<double> intervals = switch (pattern) {
    StrokePattern.solid => const [],
    StrokePattern.dashed => [w * 4, w * 2.5],
    StrokePattern.dotted => [w * 0.1, w * 2.2],
    StrokePattern.dashDot => [w * 4, w * 2, w * 0.1, w * 2],
  };
  if (intervals.isEmpty) return source;
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    var i = 0;
    var draw = true;
    while (d < metric.length) {
      final len = intervals[i % intervals.length];
      if (draw) out.addPath(metric.extractPath(d, d + len), Offset.zero);
      d += len;
      draw = !draw;
      i++;
    }
  }
  return out;
}
