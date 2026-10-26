import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monako/core/profiles/presets.dart';
import 'package:monako/core/render/recolor_filter.dart';
import 'package:monako/data/models.dart';

int rgbAt(Uint8List px, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
}

/// Page blanche 64x64 avec du texte noir en haut et une « photo »
/// (dégradé coloré) en bas.
Uint8List samplePage(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      int r = 255, g = 255, b = 255;
      if (y < 16 && x % 6 < 2) r = g = b = 0; // « texte »
      if (y >= 32) {
        r = (x * 4) & 0xFF;
        g = (y * 7 + x * 3) & 0xFF;
        b = (x * y) & 0xFF;
      }
      px[i] = r;
      px[i + 1] = g;
      px[i + 2] = b;
      px[i + 3] = 255;
    }
  }
  return px;
}

void main() {
  const w = 64, h = 64;
  final p = Presets.a1;
  final paper = p.paper.toARGB32() & 0xFFFFFF;
  final ink = p.ink.toARGB32() & 0xFFFFFF;

  RecolorJob job(Uint8List px, {RecolorMode mode = RecolorMode.full, ImageTreatment images = ImageTreatment.intact}) =>
      RecolorJob(
        rgba: px,
        width: w,
        height: h,
        paper: paper,
        ink: ink,
        mode: mode,
        images: images,
        brightnessCap: 1,
        textBoost: 0,
      );

  int dist(int a, int b) =>
      ((a >> 16) - (b >> 16)).abs() +
      (((a >> 8) & 0xFF) - ((b >> 8) & 0xFF)).abs() +
      ((a & 0xFF) - (b & 0xFF)).abs();

  test('le fond blanc devient paper, le texte noir devient ink.primary', () {
    final src = samplePage(w, h);
    final out = recolorRgba(job(src));
    expect(dist(rgbAt(out, w, 3, 20), paper), lessThan(6));
    expect(dist(rgbAt(out, w, 0, 4), ink), lessThan(6));
  });

  test('l’original n’est jamais modifié', () {
    final src = samplePage(w, h);
    final copy = Uint8List.fromList(src);
    recolorRgba(job(src));
    expect(src, copy);
  });

  test('les images restent intactes par défaut', () {
    final src = samplePage(w, h);
    final out = recolorRgba(job(src));
    expect(rgbAt(out, w, 40, 48), rgbAt(src, w, 40, 48));
  });

  test('images recolorées sur demande', () {
    final src = samplePage(w, h);
    final out = recolorRgba(job(src, images: ImageTreatment.recolored));
    expect(rgbAt(out, w, 40, 48), isNot(rgbAt(src, w, 40, 48)));
  });

  test('mode désactivé: copie identique', () {
    final src = samplePage(w, h);
    expect(recolorRgba(job(src, mode: RecolorMode.off)), src);
  });

  test('fond seulement: le texte garde sa couleur', () {
    final src = samplePage(w, h);
    final out = recolorRgba(job(src, mode: RecolorMode.backgroundOnly));
    expect(rgbAt(out, w, 0, 4), 0x000000);
    expect(dist(rgbAt(out, w, 3, 20), paper), lessThan(6));
  });

  test('plafond de luminosité: jamais plus clair que le plafond', () {
    final src = samplePage(w, h);
    final out = recolorRgba(RecolorJob(
      rgba: src,
      width: w,
      height: h,
      paper: 0xFFFFFF,
      ink: 0x000000,
      mode: RecolorMode.full,
      images: ImageTreatment.intact,
      brightnessCap: 0.8,
    ));
    expect(rgbAt(out, w, 3, 20), lessThan(0xF0F0F0));
  });
}
