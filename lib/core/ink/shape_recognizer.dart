import 'dart:math' as math;
import 'dart:ui';

/// Formes reconnues par l'outil Formes et par « dessiner puis maintenir ».
enum ShapeKind { line, rectangle, ellipse, triangle }

class RecognizedShape {
  RecognizedShape(this.kind, this.points);
  final ShapeKind kind;

  /// Contour régulier, densifié (un point tous les ~6 px).
  final List<Offset> points;
}

/// Reconnaît une forme dans un tracé à main levée. Retourne null si le
/// tracé ne ressemble à aucune forme (il reste alors à main levée).
RecognizedShape? recognizeShape(List<Offset> pts) {
  if (pts.length < 4) return null;
  final bounds = _bounds(pts);
  final diag = math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height);
  if (diag < 12) return null;

  var length = 0.0;
  for (var i = 1; i < pts.length; i++) {
    length += (pts[i] - pts[i - 1]).distance;
  }
  final gap = (pts.first - pts.last).distance;
  final closed = gap < math.max(0.22 * diag, 0.12 * length);

  if (!closed) {
    // Ligne: tous les points près de la corde début -> fin.
    final a = pts.first, b = pts.last;
    final chord = (b - a).distance;
    if (chord < 10) return null;
    var maxDev = 0.0;
    for (final p in pts) {
      maxDev = math.max(maxDev, _segmentDistance(p, a, b));
    }
    if (maxDev / chord < 0.09) {
      return RecognizedShape(ShapeKind.line, _densify([a, b]));
    }
    return null;
  }

  final candidates = <(double, RecognizedShape)>[];

  // Ellipse inscrite dans la boîte englobante.
  final c = bounds.center;
  final rx = math.max(bounds.width / 2, 1.0), ry = math.max(bounds.height / 2, 1.0);
  var errE = 0.0;
  for (final p in pts) {
    final dx = (p.dx - c.dx) / rx, dy = (p.dy - c.dy) / ry;
    errE += (math.sqrt(dx * dx + dy * dy) - 1).abs();
  }
  errE /= pts.length;
  candidates.add((
    errE / 0.13,
    RecognizedShape(ShapeKind.ellipse, [
      for (var i = 0; i <= 72; i++)
        Offset(c.dx + rx * math.cos(i * math.pi / 36), c.dy + ry * math.sin(i * math.pi / 36)),
    ]),
  ));

  // Rectangle: distance au bord le plus proche de la boîte.
  var errR = 0.0;
  for (final p in pts) {
    final d = [
      (p.dx - bounds.left).abs(),
      (p.dx - bounds.right).abs(),
      (p.dy - bounds.top).abs(),
      (p.dy - bounds.bottom).abs(),
    ].reduce(math.min);
    errR += d / diag;
  }
  errR /= pts.length;
  candidates.add((
    errR / 0.045,
    RecognizedShape(ShapeKind.rectangle, _densify([
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomRight,
      bounds.bottomLeft,
      bounds.topLeft,
    ])),
  ));

  // Triangle: trois sommets les plus éloignés.
  final centroid = pts.reduce((a, b) => a + b) / pts.length.toDouble();
  final p1 = _farthest(pts, (p) => (p - centroid).distance);
  final p2 = _farthest(pts, (p) => (p - p1).distance);
  final p3 = _farthest(pts, (p) => _segmentDistance(p, p1, p2));
  if (_segmentDistance(p3, p1, p2) > 0.15 * diag) {
    var errT = 0.0;
    for (final p in pts) {
      errT += [
        _segmentDistance(p, p1, p2),
        _segmentDistance(p, p2, p3),
        _segmentDistance(p, p3, p1),
      ].reduce(math.min) / diag;
    }
    errT /= pts.length;
    candidates.add((
      errT / 0.04,
      RecognizedShape(ShapeKind.triangle, _densify([p1, p2, p3, p1])),
    ));
  }

  candidates.sort((a, b) => a.$1.compareTo(b.$1));
  final best = candidates.first;
  return best.$1 <= 1 ? best.$2 : null;
}

Rect _bounds(List<Offset> pts) {
  var l = pts.first.dx, r = l, t = pts.first.dy, b = t;
  for (final p in pts) {
    l = math.min(l, p.dx);
    r = math.max(r, p.dx);
    t = math.min(t, p.dy);
    b = math.max(b, p.dy);
  }
  return Rect.fromLTRB(l, t, r, b);
}

Offset _farthest(List<Offset> pts, double Function(Offset) score) {
  var best = pts.first, bestScore = -1.0;
  for (final p in pts) {
    final s = score(p);
    if (s > bestScore) {
      bestScore = s;
      best = p;
    }
  }
  return best;
}

double _segmentDistance(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.distanceSquared;
  if (len2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

List<Offset> _densify(List<Offset> corners, {double step = 6}) {
  final out = <Offset>[corners.first];
  for (var i = 1; i < corners.length; i++) {
    final a = corners[i - 1], b = corners[i];
    final n = math.max(1, ((b - a).distance / step).ceil());
    for (var k = 1; k <= n; k++) {
      out.add(Offset.lerp(a, b, k / n)!);
    }
  }
  return out;
}
