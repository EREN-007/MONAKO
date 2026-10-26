import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/profiles/visual_profile.dart';
import '../../core/render/recolor_filter.dart';
import '../../data/models.dart';
import '../../services/asset_renderer.dart';

/// Logo Monako, recoloré par le profil actif avec le même filtre que les
/// PDF: l'identité visuelle elle-même est recolorable (section 12).
class MonakoLogo extends StatefulWidget {
  const MonakoLogo({
    super.key,
    required this.profile,
    this.size = 48,
    this.full = false,
  });

  final VisualProfile profile;
  final double size;

  /// Logo complet (cercle + nom) au lieu de l'icône.
  final bool full;

  @override
  State<MonakoLogo> createState() => _MonakoLogoState();
}

class _MonakoLogoState extends State<MonakoLogo> {
  static final Map<String, Future<ui.Image>> _cache = {};
  Future<ui.Image>? _image;

  String get _asset =>
      widget.full ? 'assets/branding/logo.png' : 'assets/branding/mark.png';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(MonakoLogo old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile || old.full != widget.full) _load();
  }

  void _load() {
    final key = '$_asset#${AssetRenderer.profileKey(widget.profile)}';
    final bundle = DefaultAssetBundle.of(context);
    _image = _cache[key] ??= _render(bundle, _asset, widget.profile);
  }

  static Future<ui.Image> _render(
      AssetBundle bundle, String asset, VisualProfile p) async {
    final data = await bundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: 256);
    final img = (await codec.getNextFrame()).image;
    final raw = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final out = await compute(
      recolorRgba,
      RecolorJob(
        rgba: raw.buffer.asUint8List(),
        width: img.width,
        height: img.height,
        paper: p.paper.toARGB32() & 0xFFFFFF,
        ink: p.ink.toARGB32() & 0xFFFFFF,
        mode: RecolorMode.full,
        images: ImageTreatment.recolored,
        brightnessCap: 1,
        textBoost: 0,
      ),
    );
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        out, img.width, img.height, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Monako',
        image: true,
        child: SizedBox.square(
          dimension: widget.size,
          child: FutureBuilder<ui.Image>(
            future: _image,
            builder: (context, snap) => snap.hasData
                ? RawImage(image: snap.data, fit: BoxFit.contain)
                : const SizedBox.shrink(),
          ),
        ),
      );
}
