import 'dart:math' as math;
import 'dart:typed_data';

import '../../data/models.dart';
import '../color/oklch.dart';

/// Travail de recoloration d'une page de PDF ou d'une image (section 10).
/// Objet simple, envoyable à un isolat.
class RecolorJob {
  RecolorJob({
    required this.rgba,
    required this.width,
    required this.height,
    required this.paper,
    required this.ink,
    required this.mode,
    required this.images,
    required this.brightnessCap,
    this.textBoost = 0.4,
    this.glareReduction = 0,
    this.whitePoint = 0.95,
  });

  final Uint8List rgba;
  final int width, height;

  /// Couleurs `paper` et `ink.primary` du profil, en 0xRRGGBB.
  final int paper, ink;
  final RecolorMode mode;
  final ImageTreatment images;

  /// Luminosité OKLab maximale autorisée (0..1).
  final double brightnessCap;

  /// Renforcement du texte (0 = aucun). Auto = 0.4.
  final double textBoost;
  final double glareReduction;

  /// Luminosité à partir de laquelle un pixel est considéré comme le fond
  /// (papier scanné légèrement gris, blanc cassé).
  final double whitePoint;
}

const int _block = 16;

/// Filtre « intelligent »:
/// 1. le fond dominant (blanc ou presque) devient `paper`;
/// 2. le texte foncé devient `ink.primary`;
/// 3. les autres couleurs sont converties par luminosité en OKLCH, en
///    gardant la teinte et en limitant la saturation;
/// 4. les photos et schémas détectés restent intacts par défaut.
///
/// L'image d'origine n'est jamais modifiée: une nouvelle image est rendue.
Uint8List recolorRgba(RecolorJob job) {
  final src = job.rgba;
  final out = Uint8List.fromList(src);
  if (job.mode == RecolorMode.off) return out;

  final paperLab = _labOf(job.paper);
  final inkLab = _labOf(job.ink);
  final cap = job.brightnessCap.clamp(0.2, 1.0);
  final exponent = 1 + 2 * job.textBoost.clamp(0.0, 1.0);
  final white = job.whitePoint.clamp(0.5, 1.0);

  final imageMask = job.images == ImageTreatment.recolored
      ? null
      : detectImageBlocks(src, job.width, job.height);
  final bw = (job.width + _block - 1) ~/ _block;

  // Voie rapide: les gris (la grande majorité des pixels d'un cours).
  final grayLut = Int32List(256);
  for (var v = 0; v < 256; v++) {
    final l = srgbToOklab(v / 255, v / 255, v / 255)[0];
    grayLut[v] = _mapPixel(l, 0, 0, job.mode, paperLab, inkLab, cap, exponent, white);
  }
  final colorCache = <int, int>{};

  for (var y = 0; y < job.height; y++) {
    final rowBlock = (y ~/ _block) * bw;
    for (var x = 0; x < job.width; x++) {
      final i = (y * job.width + x) * 4;
      final r = src[i], g = src[i + 1], b = src[i + 2];
      if (imageMask != null && imageMask[rowBlock + x ~/ _block] == 1) {
        if (job.images == ImageTreatment.dimmed) {
          final f = cap * (1 - 0.3 * job.glareReduction);
          out[i] = (r * f).round();
          out[i + 1] = (g * f).round();
          out[i + 2] = (b * f).round();
        }
        continue;
      }
      final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
      int rgb;
      if (mx - mn <= 10) {
        rgb = grayLut[(r + g + b) ~/ 3];
      } else {
        final key = (r << 16) | (g << 8) | b;
        rgb = colorCache[key] ??= () {
          final lab = srgbToOklab(r / 255, g / 255, b / 255);
          return _mapPixel(lab[0], lab[1], lab[2], job.mode, paperLab, inkLab,
              cap, exponent, white);
        }();
      }
      out[i] = (rgb >> 16) & 0xFF;
      out[i + 1] = (rgb >> 8) & 0xFF;
      out[i + 2] = rgb & 0xFF;
    }
  }
  return out;
}

int _mapPixel(double l, double a, double b, RecolorMode mode,
    List<double> paper, List<double> ink, double cap, double exponent,
    double white) {
  final chroma = math.sqrt(a * a + b * b);
  double ol, oa, ob;
  if (mode == RecolorMode.backgroundOnly) {
    // Seulement le fond quasi blanc: fondu progressif vers `paper`.
    if (l > 0.82 && chroma < 0.05) {
      final t = ((l - 0.82) / 0.13).clamp(0.0, 1.0);
      ol = l + (paper[0] - l) * t;
      oa = a + (paper[1] - a) * t;
      ob = b + (paper[2] - b) * t;
    } else {
      ol = l;
      oa = a;
      ob = b;
    }
  } else {
    // Axe blanc -> noir standard projeté sur l'axe paper -> ink du profil.
    final t = math.pow((l / white).clamp(0.0, 1.0), exponent).toDouble();
    ol = ink[0] + (paper[0] - ink[0]) * t;
    if (chroma < 0.03) {
      oa = ink[1] + (paper[1] - ink[1]) * t;
      ob = ink[2] + (paper[2] - ink[2]) * t;
    } else {
      // Couleur: teinte gardée, saturation limitée.
      final c = math.min(chroma, 0.12);
      oa = a / chroma * c;
      ob = b / chroma * c;
    }
  }
  if (ol > cap) ol = cap;
  final rgb = oklabToSrgb(ol, oa, ob);
  int ch(double v) => (v.clamp(0.0, 1.0) * 255).round();
  return (ch(rgb[0]) << 16) | (ch(rgb[1]) << 8) | ch(rgb[2]);
}

List<double> _labOf(int rgb) => srgbToOklab(
    ((rgb >> 16) & 0xFF) / 255, ((rgb >> 8) & 0xFF) / 255, (rgb & 0xFF) / 255);

/// Détection des photos et schémas par blocs de 16 px: un bloc de texte a
/// peu de couleurs distinctes (fond, encre, anticrénelage), une photo en a
/// beaucoup. Retourne 1 par bloc « image ».
Uint8List detectImageBlocks(Uint8List rgba, int width, int height) {
  final bw = (width + _block - 1) ~/ _block;
  final bh = (height + _block - 1) ~/ _block;
  final raw = Uint8List(bw * bh);
  final seen = <int>{};
  for (var by = 0; by < bh; by++) {
    for (var bx = 0; bx < bw; bx++) {
      seen.clear();
      var mid = 0, total = 0;
      for (var y = by * _block; y < math.min(height, (by + 1) * _block); y += 2) {
        for (var x = bx * _block; x < math.min(width, (bx + 1) * _block); x += 2) {
          final i = (y * width + x) * 4;
          final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
          seen.add(((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4));
          final lum = (r * 3 + g * 6 + b) ~/ 10;
          if (lum > 40 && lum < 215) mid++;
          total++;
        }
      }
      final photoLike = seen.length > 20 || (total > 0 && mid / total > 0.6);
      raw[by * bw + bx] = photoLike ? 1 : 0;
    }
  }
  // Lissage: un bloc isolé (texte dense) n'est pas une image; un bloc
  // entouré d'images en est une.
  final out = Uint8List(bw * bh);
  for (var by = 0; by < bh; by++) {
    for (var bx = 0; bx < bw; bx++) {
      var n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final x = bx + dx, y = by + dy;
          if (x >= 0 && y >= 0 && x < bw && y < bh && raw[y * bw + x] == 1) n++;
        }
      }
      final self = raw[by * bw + bx] == 1;
      out[by * bw + bx] = (self && n >= 2) || n >= 5 ? 1 : 0;
    }
  }
  return out;
}
