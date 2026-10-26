import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

import '../core/color/hex.dart';
import '../core/profiles/visual_profile.dart';
import '../core/render/recolor_filter.dart';
import '../data/models.dart';
import '../data/repository.dart';

/// Pixels bruts d'une page rendue (avant recoloration).
class RawPage {
  RawPage(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width, height;
}

/// Rendu des PDF et images importés, avec recoloration par profil et cache
/// des pages recolorées (défilement fluide, section 10).
class AssetRenderer {
  AssetRenderer(this.repo);

  final NotesRepository repo;

  /// Largeur de rendu en pixels (la page logique fait 800 de large).
  static const renderWidth = 1600;

  final _raw = _Lru<String, Future<RawPage?>>(8);
  final _recolored = _Lru<String, Future<ui.Image?>>(16);
  final Map<String, Future<PdfDocument>> _docs = {};

  static String profileKey(VisualProfile p) =>
      '${colorToHex(p.paper)}${colorToHex(p.ink)}'
      '${p.filters.pdfBrightnessCap.toStringAsFixed(2)}'
      '${p.filters.glareReduction.toStringAsFixed(2)}';

  /// Image d'une page, recolorée selon [profile] et les réglages du
  /// document, ou l'original si [original] est vrai (« voir l'original »).
  Future<ui.Image?> pageImage(
    ImportedAsset asset,
    int pageNumber,
    VisualProfile profile, {
    bool original = false,
  }) {
    final settings = asset.filter;
    final key = original || settings.mode == RecolorMode.off
        ? '${asset.id}#$pageNumber#original'
        : '${asset.id}#$pageNumber#${profileKey(profile)}#${settings.cacheKey}';
    return _recolored.putIfAbsent(key, () async {
      final raw = await rawPage(asset, pageNumber);
      if (raw == null) return null;
      Uint8List pixels = raw.rgba;
      if (!original && settings.mode != RecolorMode.off) {
        final job = RecolorJob(
          rgba: raw.rgba,
          width: raw.width,
          height: raw.height,
          paper: profile.paper.toARGB32() & 0xFFFFFF,
          ink: profile.ink.toARGB32() & 0xFFFFFF,
          mode: settings.mode,
          images: settings.images,
          brightnessCap:
              settings.brightnessCap ?? profile.filters.pdfBrightnessCap,
          textBoost: settings.textContrast ?? 0.4,
          glareReduction: profile.filters.glareReduction,
        );
        pixels = await compute(recolorRgba, job);
      }
      return _toImage(pixels, raw.width, raw.height);
    });
  }

  Future<RawPage?> rawPage(ImportedAsset asset, int pageNumber) =>
      _raw.putIfAbsent('${asset.id}#$pageNumber', () async {
        final bytes = await repo.assetBytes(asset);
        if (bytes == null) return null;
        return asset.kind == AssetKind.pdf
            ? _renderPdfPage(asset.id, bytes, pageNumber)
            : _decodeImage(bytes);
      });

  Future<RawPage?> _renderPdfPage(
      String assetId, Uint8List bytes, int pageNumber) async {
    final doc = await (_docs[assetId] ??=
        PdfDocument.openData(Uint8List.fromList(bytes)));
    final page = await doc.getPage(pageNumber);
    try {
      final h = renderWidth * page.height / page.width;
      final img = await page.render(
        width: renderWidth.toDouble(),
        height: h,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (img == null) return null;
      return await _decodeImage(img.bytes);
    } finally {
      await page.close();
    }
  }

  static Future<RawPage?> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    var image = frame.image;
    if (image.width > renderWidth) {
      final codec2 = await ui.instantiateImageCodec(bytes,
          targetWidth: renderWidth);
      image = (await codec2.getNextFrame()).image;
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width, h = image.height;
    image.dispose();
    if (data == null) return null;
    return RawPage(data.buffer.asUint8List(), w, h);
  }

  static Future<ui.Image> _toImage(Uint8List rgba, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// Taille de chaque page d'un PDF (pour créer les pages de note).
  static Future<List<Size2>> pdfPageSizes(Uint8List bytes) async {
    final doc = await PdfDocument.openData(Uint8List.fromList(bytes));
    final sizes = <Size2>[];
    try {
      for (var i = 1; i <= doc.pagesCount; i++) {
        final p = await doc.getPage(i);
        sizes.add(Size2(p.width, p.height));
        await p.close();
      }
    } finally {
      await doc.close();
    }
    return sizes;
  }

  static Future<Size2> imageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final f = await codec.getNextFrame();
    final s = Size2(f.image.width.toDouble(), f.image.height.toDouble());
    f.image.dispose();
    return s;
  }

  void clear() {
    _raw.clear();
    _recolored.clear();
    for (final d in _docs.values) {
      d.then((doc) => doc.close()).ignore();
    }
    _docs.clear();
  }
}

class _Lru<K, V> {
  _Lru(this.capacity);
  final int capacity;
  final _map = <K, V>{};

  V putIfAbsent(K key, V Function() create) {
    final existing = _map.remove(key);
    if (existing != null) {
      _map[key] = existing;
      return existing;
    }
    final v = create();
    _map[key] = v;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
    return v;
  }

  void clear() => _map.clear();
}
