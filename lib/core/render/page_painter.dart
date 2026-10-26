import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../data/models.dart';
import '../color/hex.dart';
import '../profiles/palette.dart';
import '../roles.dart';
import 'stroke_geometry.dart';

/// Fond de page: `paper` + gabarit dessiné avec `paper.line` + document
/// importé (déjà recoloré).
class PageBackgroundPainter extends CustomPainter {
  PageBackgroundPainter({
    required this.palette,
    required this.template,
    this.image,
  });

  final ResolvedPalette palette;
  final PageTemplate template;
  final ui.Image? image;

  static const spacing = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.paper);
    final img = image;
    if (img != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: img,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
      return;
    }
    final line = Paint()
      ..color = palette[InkRole.paperLine]
      ..strokeWidth = 1;
    switch (template) {
      case PageTemplate.blank:
        break;
      case PageTemplate.lined:
        for (var y = spacing * 3; y < size.height - spacing; y += spacing) {
          canvas.drawLine(Offset(spacing, y), Offset(size.width - spacing, y), line);
        }
        // Marge
        canvas.drawLine(Offset(spacing * 2.5, spacing),
            Offset(spacing * 2.5, size.height - spacing), line);
      case PageTemplate.grid:
        for (var y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        for (var x = spacing; x < size.width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
      case PageTemplate.dotted:
        final dot = Paint()..color = palette[InkRole.paperLine];
        for (var y = spacing; y < size.height; y += spacing) {
          for (var x = spacing; x < size.width; x += spacing) {
            canvas.drawCircle(Offset(x, y), 1.6, dot);
          }
        }
    }
  }

  @override
  bool shouldRepaint(PageBackgroundPainter old) =>
      old.palette != palette || old.template != template || old.image != image;
}

/// Encre et surlignages. Chaque trait est dessiné avec la couleur de la
/// table (recherche par rôle). Changer de profil n'invalide aucune
/// géométrie: seule la table change.
class InkPainter extends CustomPainter {
  InkPainter({
    required this.palette,
    required this.strokes,
    required this.highlights,
    required this.cache,
    required this.version,
    this.hidden = const {},
  });

  final ResolvedPalette palette;
  final List<InkStroke> strokes;
  final List<InkStroke> highlights;
  final StrokeGeometryCache cache;

  /// Incrémenté à chaque modification du contenu de la page.
  final int version;

  /// Éléments masqués (en cours de déplacement).
  final Set<String> hidden;

  @override
  void paint(Canvas canvas, Size size) {
    paintHighlights(canvas, palette, highlights, cache, hidden: hidden);
    paintStrokes(canvas, palette, strokes, cache, hidden: hidden);
  }

  @override
  bool shouldRepaint(InkPainter old) =>
      old.version != version || old.palette != palette || old.hidden != hidden;
}

void paintHighlights(Canvas canvas, ResolvedPalette palette,
    List<InkStroke> highlights, StrokeGeometryCache cache,
    {Set<String> hidden = const {}}) {
  final paint = Paint()..isAntiAlias = true;
  for (final h in highlights) {
    if (hidden.contains(h.id)) continue;
    paint.color = palette.highlight(h.role);
    canvas.drawPath(cache.of(h).outline, paint);
  }
}

void paintStrokes(Canvas canvas, ResolvedPalette palette,
    List<InkStroke> strokes, StrokeGeometryCache cache,
    {Set<String> hidden = const {}}) {
  final fill = Paint()..isAntiAlias = true;
  final thicken = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final m = palette.widthMultiplier;
  for (final s in strokes) {
    if (hidden.contains(s.id)) continue;
    final color = strokeColor(palette, s);
    final g = cache.of(s);
    final pattern = s.pattern != StrokePattern.solid
        ? s.pattern
        : (palette.rolePatterns ? patternForRole(s.role) : StrokePattern.solid);
    if (pattern != StrokePattern.solid) {
      thicken
        ..color = color
        ..strokeWidth = s.width * m * 0.85;
      canvas.drawPath(g.dashed(pattern), thicken);
      continue;
    }
    fill.color = color;
    canvas.drawPath(g.outline, fill);
    if (m > 1.01) {
      // Épaissir sans recalculer: on trace le contour avec une largeur
      // égale au surplus voulu.
      thicken
        ..color = color
        ..strokeWidth = s.width * (m - 1);
      canvas.drawPath(g.outline, thicken);
    }
  }
}

/// Couleur réelle d'un trait dans le profil.
Color strokeColor(ResolvedPalette palette, InkStroke s) {
  final fixed = s.fixedColor;
  if (fixed == null) return palette[s.role];
  final c = colorFromHex(fixed);
  return s.recolor ? palette.recolorFixed(c) : c;
}
