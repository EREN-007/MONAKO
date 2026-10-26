import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:share_plus/share_plus.dart';

import '../core/color/contrast.dart';
import '../core/color/hex.dart';
import '../core/profiles/palette.dart';
import '../core/profiles/presets.dart';
import '../core/profiles/visual_profile.dart';
import '../core/render/recolor_filter.dart';
import '../core/render/stroke_geometry.dart';
import '../core/roles.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'asset_renderer.dart';

/// Exports: PDF « normal » (rôles remplacés par la palette standard, noir
/// sur blanc, lisible partout), PDF dans le profil actif, données JSON,
/// profil pour la clinique.
class ExportService {
  ExportService(this.repo, this.renderer);

  final NotesRepository repo;
  final AssetRenderer renderer;

  pw.Font? _font, _fontBold;

  Future<void> _loadFonts() async {
    _font ??= pw.Font.ttf(
        await rootBundle.load('assets/fonts/AtkinsonHyperlegible-Regular.ttf'));
    _fontBold ??= pw.Font.ttf(
        await rootBundle.load('assets/fonts/AtkinsonHyperlegible-Bold.ttf'));
  }

  /// Construit le PDF d'un cahier. Sans [profile]: export normal.
  Future<Uint8List> notebookPdf(Notebook n, {VisualProfile? profile}) async {
    await _loadFonts();
    final p = profile ?? Presets.standard;
    final palette = ResolvedPalette.of(p);
    final doc = pw.Document(title: n.title, creator: 'Monako');
    for (final page in repo.pagesOf(n.id)) {
      final content = await repo.loadPage(page);
      pw.ImageProvider? background;
      final asset = repo.asset(page.assetId);
      if (asset != null && page.assetPage != null) {
        final raw = await renderer.rawPage(asset, page.assetPage!);
        if (raw != null) {
          var rgba = raw.rgba;
          if (profile != null && asset.filter.mode != RecolorMode.off) {
            rgba = await compute(
              recolorRgba,
              RecolorJob(
                rgba: raw.rgba,
                width: raw.width,
                height: raw.height,
                paper: p.paper.toARGB32() & 0xFFFFFF,
                ink: p.ink.toARGB32() & 0xFFFFFF,
                mode: asset.filter.mode,
                images: asset.filter.images,
                brightnessCap:
                    asset.filter.brightnessCap ?? p.filters.pdfBrightnessCap,
                textBoost: asset.filter.textContrast ?? 0.4,
              ),
            );
          }
          background = pw.RawImage(bytes: rgba, width: raw.width, height: raw.height);
        }
      }
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(page.width, page.height),
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(children: [
          pw.Positioned.fill(
            child: pw.CustomPaint(
              painter: (canvas, size) =>
                  _paintBackground(canvas, size, palette, page, background == null),
            ),
          ),
          if (background != null)
            pw.Positioned.fill(child: pw.Image(background, fit: pw.BoxFit.fill)),
          pw.Positioned.fill(
            child: pw.CustomPaint(
              painter: (canvas, size) =>
                  _paintInk(canvas, size, palette, content),
            ),
          ),
          for (final t in content.texts)
            pw.Positioned(
              left: t.x,
              top: t.y,
              child: pw.SizedBox(
                width: t.width,
                child: pw.Text(
                  t.text,
                  style: pw.TextStyle(
                    font: t.role == InkRole.heading ? _fontBold : _font,
                    fontSize: t.size * (profile?.text.sizeMultiplier ?? 1),
                    color: _pdfColor(palette[t.role]),
                    lineSpacing: t.size * 0.3,
                  ),
                ),
              ),
            ),
        ]),
      ));
    }
    return doc.save();
  }

  static PdfColor _pdfColor(Color c) => PdfColor(c.r, c.g, c.b, c.a);

  static void _paintBackground(PdfGraphics canvas, PdfPoint size,
      ResolvedPalette palette, NotePage page, bool withTemplate) {
    canvas
      ..setFillColor(_pdfColor(palette.paper))
      ..drawRect(0, 0, size.x, size.y)
      ..fillPath();
    if (!withTemplate) return;
    final h = size.y;
    const s = 32.0;
    canvas
      ..setStrokeColor(_pdfColor(palette[InkRole.paperLine]))
      ..setLineWidth(0.8);
    switch (page.template) {
      case PageTemplate.lined:
        for (var y = s * 3; y < h - s; y += s) {
          canvas
            ..moveTo(s, h - y)
            ..lineTo(size.x - s, h - y);
        }
        canvas
          ..moveTo(s * 2.5, h - s)
          ..lineTo(s * 2.5, s);
        canvas.strokePath();
      case PageTemplate.grid:
        for (var y = s; y < h; y += s) {
          canvas
            ..moveTo(0, h - y)
            ..lineTo(size.x, h - y);
        }
        for (var x = s; x < size.x; x += s) {
          canvas
            ..moveTo(x, 0)
            ..lineTo(x, h);
        }
        canvas.strokePath();
      case PageTemplate.dotted:
        canvas.setFillColor(_pdfColor(palette[InkRole.paperLine]));
        for (var y = s; y < h; y += s) {
          for (var x = s; x < size.x; x += s) {
            canvas.drawEllipse(x, h - y, 1.4, 1.4);
          }
        }
        canvas.fillPath();
      case PageTemplate.blank:
        break;
    }
  }

  static void _paintInk(PdfGraphics canvas, PdfPoint size,
      ResolvedPalette palette, PageContent content) {
    final h = size.y;
    void polygon(List<Offset> pts) {
      if (pts.length < 3) return;
      canvas.moveTo(pts.first.dx, h - pts.first.dy);
      for (final p in pts.skip(1)) {
        canvas.lineTo(p.dx, h - p.dy);
      }
      canvas.closePath();
    }

    List<Offset> outline(InkStroke s, double widthMultiplier) {
      final pts = <PointVector>[
        for (var i = 0; i < s.pointCount; i++)
          PointVector(s.points[i * 3], s.points[i * 3 + 1],
              s.hasPressure ? s.points[i * 3 + 2] : null),
      ];
      return getStroke(
        pts,
        options: StrokeGeometryCache.options(s.width * widthMultiplier,
            highlight: s.highlight, complete: true, simulate: !s.hasPressure),
      );
    }

    for (final hl in content.highlights) {
      canvas
        ..saveContext()
        ..setGraphicState(PdfGraphicState(opacity: palette.highlightOpacity))
        ..setFillColor(_pdfColor(palette[hl.role]));
      polygon(outline(hl, 1));
      canvas
        ..fillPath()
        ..restoreContext();
    }
    for (final s in content.strokes) {
      final c = s.fixedColor != null
          ? (s.recolor ? palette.recolorFixed(colorFromHex(s.fixedColor!)) : colorFromHex(s.fixedColor!))
          : palette[s.role];
      canvas.setFillColor(_pdfColor(c));
      polygon(outline(s, palette.widthMultiplier));
      canvas.fillPath();
    }
  }

  Future<void> shareBytes(Uint8List bytes, String fileName, String mime) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: fileName, mimeType: mime)],
      fileNameOverrides: [fileName],
    ));
  }

  Future<void> shareNotebookPdf(Notebook n, {VisualProfile? profile}) async {
    final bytes = await notebookPdf(n, profile: profile);
    final safe = n.title.replaceAll(RegExp(r'[^\w\- ]+'), '').trim();
    await shareBytes(bytes, '${safe.isEmpty ? 'monako' : safe}.pdf', 'application/pdf');
  }

  Future<void> shareAllData() async {
    final data = await repo.exportAllData();
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
    await shareBytes(bytes, 'monako-donnees.json', 'application/json');
  }

  /// Profil exporté (JSON) pour un camarade ou la clinique.
  Future<void> shareProfileJson(VisualProfile p) async {
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(p.toJson())));
    await shareBytes(bytes, 'profil-${p.id}.json', 'application/json');
  }

  /// Fiche lisible du profil pour l'optométriste (couleurs, ratios, filtres).
  Future<void> shareProfileSheet(VisualProfile p, {required Map<String, String> labels}) async {
    await _loadFonts();
    final doc = pw.Document(title: p.name, creator: 'Monako');
    final range = p.contrastRange;
    doc.addPage(pw.MultiPage(
      theme: pw.ThemeData.withFont(base: _font, bold: _fontBold),
      build: (ctx) => [
        pw.Header(level: 0, text: '${labels['title']}: ${p.name}'),
        pw.Text('${labels['needs']}: ${p.needs.map((n) => n.code).join(', ')}'),
        pw.Text('${labels['range']}: $range'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: [labels['role'], labels['color'], labels['ratio']],
          data: [
            for (final r in InkRole.values)
              [
                r.key,
                colorToHex(p.color(r)),
                r == InkRole.paper
                    ? '—'
                    : '${contrastRatio(p.color(r), p.paper).toStringAsFixed(2)}:1',
              ],
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text('${labels['filters']}: ${jsonEncode(p.filters.toJson())}'),
        pw.Text('${labels['text']}: ${jsonEncode(p.text.toJson())}'),
        pw.Text('${labels['stroke']}: ${jsonEncode(p.stroke.toJson())}'),
        pw.SizedBox(height: 16),
        pw.Text(labels['disclaimer'] ?? '',
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
      ],
    ));
    await shareBytes(await doc.save(), 'profil-${p.id}.pdf', 'application/pdf');
  }
}
