import 'dart:math' as math;
import 'dart:ui' show Color;

import '../color/contrast.dart';
import '../color/hex.dart';
import '../color/oklch.dart';
import '../roles.dart';
import 'contrast_targets.dart';
import 'visual_profile.dart';

/// Réponses du test guidé (« calibrer ma vue »). Aucune ne nomme une
/// maladie: l'élève choisit ce qui le soulage, le profil est calculé.
class CalibrationAnswers {
  const CalibrationAnswers({
    this.paper = const Oklch(0.9, 0.035, 85),
    this.contrast = 9,
    this.textSize = 16,
    this.colorConfusion = false,
    this.lineHeight = 1.4,
    this.wordSpacing = 0,
    this.font = ProfileFont.system,
    this.warmTint = 0,
    this.ink,
  });

  /// Fond choisi.
  final Oklch paper;

  /// Ratio de contraste texte/fond qui soulage le plus.
  final double contrast;

  /// Plus petite taille lue sans effort (pt), avec une marge de confort.
  final double textSize;

  /// Les encres de couleur se confondent.
  final bool colorConfusion;
  final double lineHeight;
  final double wordSpacing;
  final ProfileFont font;
  final double warmTint;

  /// Teinte d'encre choisie (null = crème sur fond sombre, brun sur clair).
  /// Sa luminosité est recalculée pour respecter le contraste.
  final Oklch? ink;

  bool get darkPaper => paper.l < 0.55;

  CalibrationAnswers copyWith({
    Oklch? paper,
    double? contrast,
    double? textSize,
    bool? colorConfusion,
    double? lineHeight,
    double? wordSpacing,
    ProfileFont? font,
    double? warmTint,
    Oklch? ink,
  }) =>
      CalibrationAnswers(
        paper: paper ?? this.paper,
        contrast: contrast ?? this.contrast,
        textSize: textSize ?? this.textSize,
        colorConfusion: colorConfusion ?? this.colorConfusion,
        lineHeight: lineHeight ?? this.lineHeight,
        wordSpacing: wordSpacing ?? this.wordSpacing,
        font: font ?? this.font,
        warmTint: warmTint ?? this.warmTint,
        ink: ink ?? this.ink,
      );

  /// Besoins déduits des choix (section 2), sans diagnostic.
  Set<VisionNeed> get needs => {
        // Lumière: fond sombre ou tamisé, teinte chaude, contraste doux.
        if (contrast <= 10 && (darkPaper || paper.l < 0.92 || warmTint >= 0.2)) VisionNeed.a,
        if (contrast >= 12) VisionNeed.b,
        if (colorConfusion) VisionNeed.c,
        if (textSize >= 22) VisionNeed.d,
        if (lineHeight >= 1.6 || wordSpacing >= 0.08) VisionNeed.e,
      };
}

// Teintes OKLCH des encres d'accent: rouge, bleu, vert, violet.
const _standardHues = [(29.0, 0.12), (262.0, 0.12), (145.0, 0.12), (305.0, 0.12)];

// Okabe-Ito (palette sûre pour le daltonisme): vermillon, bleu ciel,
// vert bleuté, pourpre rougeâtre.
final _okabeIto = ['#D55E00', '#56B4E9', '#009E73', '#CC79A7']
    .map((h) => Oklch.fromColor(colorFromHex(h)))
    .map((o) => (o.h, math.min(o.c, 0.14)))
    .toList();

/// Construit un profil complet à partir du test guidé. Chaque encre est
/// calculée en OKLCH pour respecter la plage de contraste du profil.
VisualProfile buildCalibratedProfile(
  CalibrationAnswers a, {
  required String id,
  required String name,
}) {
  final needs = a.needs;
  final range = ContrastRange.forNeeds(needs);
  final paper = a.paper.toColor();
  final dark = isDarkColor(paper);
  // Une petite marge au-dessus du minimum garde le texte lisible même sur
  // un surlignage.
  final span = range.max - range.min;
  final target = a.contrast
      .clamp(range.min + math.min(0.8, span / 2), range.max - math.min(0.1, span / 2))
      .toDouble();
  double inRange(double t) => t
      .clamp(range.min + math.min(0.15, span / 2), range.max - math.min(0.15, span / 2))
      .toDouble();

  Color solve(Oklch hue, double t) => solveForContrast(paper, hue, t);

  final ink = solve(
      a.ink ?? (dark ? const Oklch(0.85, 0.045, 90) : const Oklch(0.3, 0.02, 70)),
      target);
  final inkO = Oklch.fromColor(ink);
  final roles = <InkRole, Color>{
    InkRole.paper: paper,
    InkRole.inkPrimary: ink,
    InkRole.inkSecondary:
        solve(inkO.copyWith(c: inkO.c * 0.6), inRange(math.max(range.min + 0.3, target * 0.85))),
    InkRole.heading: solve(
        dark ? const Oklch(0.8, 0.1, 85) : const Oklch(0.35, 0.09, 255),
        inRange(target)),
    InkRole.paperLine: solve(a.paper.copyWith(c: a.paper.c * 0.5), 1.45),
  };
  final hues = a.colorConfusion ? _okabeIto : _standardHues;
  final accentTarget = inRange(math.max(range.min + 0.6, target * 0.88));
  for (var i = 0; i < 4; i++) {
    final (h, c) = hues[i];
    roles[InkRole.values[InkRole.accent1.index + i]] =
        solve(Oklch(0.6, c, h), accentTarget);
  }

  // Surlignages: visibles sur le fond, sans réduire la lisibilité du texte.
  final opacity = dark ? 0.55 : 0.45;
  const hlHues = [100.0, 145.0, 350.0, 240.0];
  for (var i = 0; i < 4; i++) {
    var shift = 0.3;
    Color hl;
    while (true) {
      hl = dark
          ? Oklch((a.paper.l + shift).clamp(0.0, 1.0), 0.09, hlHues[i]).toColor()
          : Oklch(0.93 - shift * 0.15, 0.12, hlHues[i]).toColor();
      final over = composite(hl.withValues(alpha: opacity), paper);
      if (contrastRatio(ink, over) >= range.min + 0.3 || shift < 0.02) break;
      shift -= 0.01;
    }
    roles[InkRole.values[InkRole.highlight1.index + i]] = hl;
  }

  return VisualProfile(
    id: id,
    name: name,
    needs: needs,
    roles: roles,
    filters: ProfileFilters(
      warmTint: a.warmTint,
      pdfBrightnessCap: dark ? 0.7 : math.min(1.0, a.paper.l + 0.04),
      glareReduction: needs.contains(VisionNeed.a) ? 0.3 : 0,
      haloReduction: needs.contains(VisionNeed.e) ? 0.5 : 0,
    ),
    text: ProfileText(
      baseSize: a.textSize.clamp(ProfileText.minSize, ProfileText.maxSize).toDouble(),
      font: a.font,
      lineHeight: a.lineHeight,
      wordSpacing: a.wordSpacing,
      defaultZoom: a.textSize >= 24 ? 1.3 : 1,
    ),
    stroke: ProfileStroke(
      widthMultiplier: a.contrast >= 12
          ? 1.25
          : (needs.contains(VisionNeed.e) ? 1.15 : 1),
      rolePatterns: a.colorConfusion,
      highlightOpacity: opacity,
    ),
    simplifiedUi: a.textSize >= 26,
  );
}
