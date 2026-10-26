import 'dart:math' as math;
import 'dart:ui' show Color;

import '../color/contrast.dart';
import '../color/oklch.dart';
import '../roles.dart';
import 'contrast_targets.dart';
import 'presets.dart';
import 'visual_profile.dart';

/// Conflit détecté pendant une fusion de profils.
enum FusionConflict {
  /// A et B: B demande plus de contraste que A ne le tolère; la plage de A,
  /// plus sûre pour la lumière, est retenue.
  contrastCappedByLight,

  /// Aucune plage commune entre les besoins (hors A).
  contrastNoOverlap,

  /// Deux fonds sombres/clairs contradictoires: le fond de A est retenu.
  backgroundChosen,
}

class FusionResult {
  const FusionResult(this.profile, this.conflicts);
  final VisualProfile profile;
  final List<FusionConflict> conflicts;
}

/// Ramène le contraste d'une couleur [color] sur [paper] dans [range] en ne
/// touchant que sa luminosité OKLCH.
Color clampToRange(Color paper, Color color, ContrastRange range,
    {double margin = 0.05}) {
  final r = contrastRatio(color, paper);
  if (range.contains(r)) return color;
  final target = r < range.min ? range.min + margin : range.max - margin;
  return solveForContrast(paper, Oklch.fromColor(color), target);
}

/// Fusion de plusieurs profils (section 5):
/// - fond et luminosité viennent du profil A (confort lumineux);
/// - les teintes viennent du profil C (palette daltonisme);
/// - contraste final = cible la plus élevée, plafonnée par la plage de A;
/// - les tailles, interlignes et épaisseurs prennent le maximum.
FusionResult fuseProfiles(List<VisualProfile> sources,
    {required String id, required String name}) {
  assert(sources.isNotEmpty);
  final needs = {for (final p in sources) ...p.needs};
  final range = ContrastRange.forNeeds(needs);
  final conflicts = <FusionConflict>[];
  if (range.conflict) {
    conflicts.add(needs.contains(VisionNeed.a)
        ? FusionConflict.contrastCappedByLight
        : FusionConflict.contrastNoOverlap);
  }

  VisualProfile? withNeed(VisionNeed n) {
    for (final p in sources) {
      if (p.needs.contains(n)) return p;
    }
    return null;
  }

  final light = withNeed(VisionNeed.a);
  final colorBlind = withNeed(VisionNeed.c);
  final base = light ?? withNeed(VisionNeed.b) ?? withNeed(VisionNeed.d) ??
      sources.first;
  final darkBases = sources.map((p) => isDarkColor(p.paper)).toSet();
  if (darkBases.length > 1) conflicts.add(FusionConflict.backgroundChosen);

  final paper = base.paper;
  final roles = <InkRole, Color>{...base.roles};
  final mid = range.max >= 21
      ? range.min + 1.5
      : (range.min + range.max) / 2;

  roles[InkRole.inkPrimary] = clampToRange(paper, base.ink, range);
  roles[InkRole.inkSecondary] =
      clampToRange(paper, base.color(InkRole.inkSecondary), range);
  roles[InkRole.heading] = clampToRange(paper, base.color(InkRole.heading), range);

  // Teintes: celles de C si présent, sinon celles du profil de base.
  final hueSource = colorBlind ?? base;
  for (final r in const [
    InkRole.accent1,
    InkRole.accent2,
    InkRole.accent3,
    InkRole.accent4,
  ]) {
    final hue = Oklch.fromColor(hueSource.color(r));
    var c = solveForContrast(paper, hue, mid);
    if (!range.contains(contrastRatio(c, paper))) {
      c = clampToRange(paper, c, range);
    }
    roles[r] = c;
  }
  // Surlignages: on garde ceux du fond retenu, la teinte venant de C.
  if (colorBlind != null && colorBlind != base) {
    for (final r in InkRole.highlights) {
      final hue = Oklch.fromColor(colorBlind.color(r));
      final bl = Oklch.fromColor(base.color(r));
      roles[r] = Oklch(bl.l, math.min(bl.c, hue.c), hue.h).toColor();
    }
  }

  double maxOf(double Function(VisualProfile) f) =>
      sources.map(f).reduce(math.max);

  final fused = VisualProfile(
    id: id,
    name: name,
    needs: needs,
    roles: roles,
    baseId: base.isPreset ? base.id : base.baseId,
    filters: ProfileFilters(
      warmTint: maxOf((p) => p.filters.warmTint),
      // Le plafond le plus bas est le plus doux pour la lumière.
      pdfBrightnessCap:
          sources.map((p) => p.filters.pdfBrightnessCap).reduce(math.min),
      glareReduction: maxOf((p) => p.filters.glareReduction),
      haloReduction: maxOf((p) => p.filters.haloReduction),
    ),
    text: ProfileText(
      baseSize: maxOf((p) => p.text.baseSize),
      font: sources
          .map((p) => p.text.font)
          .firstWhere((f) => f != ProfileFont.system,
              orElse: () => ProfileFont.system),
      lineHeight: maxOf((p) => p.text.lineHeight),
      wordSpacing: maxOf((p) => p.text.wordSpacing),
      defaultZoom: maxOf((p) => p.text.defaultZoom),
    ),
    stroke: ProfileStroke(
      widthMultiplier: maxOf((p) => p.stroke.widthMultiplier),
      rolePatterns: sources.any((p) => p.stroke.rolePatterns),
      highlightOpacity: base.stroke.highlightOpacity,
    ),
    simplifiedUi: sources.any((p) => p.simplifiedUi),
  );
  return FusionResult(fused, conflicts);
}

/// Réglage plus doux proposé par le bouton « ce profil me fatigue »
/// (section 11): contraste réduit de 10 % (sans sortir de la plage),
/// teinte chaude +10 %, fond un peu moins lumineux s'il est clair.
VisualProfile softerProfile(VisualProfile p) {
  final range = p.contrastRange;
  var paper = p.paper;
  final po = Oklch.fromColor(paper);
  if (!isDarkColor(paper)) {
    paper = po.copyWith(l: math.max(0.6, po.l - 0.04)).toColor();
  }
  final roles = <InkRole, Color>{...p.roles, InkRole.paper: paper};
  for (final r in InkRole.contrastChecked) {
    final current = contrastRatio(p.color(r), paper);
    final target = math.max(range.min + 0.05, current * 0.9);
    roles[r] = solveForContrast(paper, Oklch.fromColor(p.color(r)), target);
  }
  return p.copyWith(
    roles: roles,
    filters: p.filters.copyWith(
      warmTint: math.min(0.6, p.filters.warmTint + 0.1),
      pdfBrightnessCap: math.max(0.5, p.filters.pdfBrightnessCap - 0.05),
    ),
  );
}

/// Corrige automatiquement tous les rôles vérifiés pour qu'ils entrent dans
/// la plage du profil (bouton « corriger » de l'outil de réglage).
VisualProfile fitProfileToRange(VisualProfile p) {
  final range = p.contrastRange;
  final roles = <InkRole, Color>{...p.roles};
  for (final r in InkRole.contrastChecked) {
    roles[r] = clampToRange(p.paper, p.color(r), range);
  }
  return p.copyWith(roles: roles);
}

/// Profil pour la nuit: on part du profil donné et on ajoute de la teinte
/// chaude (mode nuit automatique, version 2).
VisualProfile withEveningWarmth(VisualProfile p, double extraWarmth) {
  if (extraWarmth <= 0) return p;
  return p.copyWith(
    modifiedAt: p.modifiedAt,
    filters: p.filters.copyWith(
      warmTint: math.min(0.8, p.filters.warmTint + extraWarmth),
    ),
  );
}

/// Profil de base utilisé pour compléter les rôles manquants.
VisualProfile baseProfileFor(String? baseId) =>
    Presets.byId(baseId) ?? Presets.standard;

/// Curseur rapide « luminosité du fond » (0 = très sombre, 1 = très clair).
/// L'encre garde son contraste en changeant de côté si nécessaire.
VisualProfile adjustPaperLightness(VisualProfile p, double lightness) {
  final po = Oklch.fromColor(p.paper);
  final paper = po.copyWith(l: lightness.clamp(0.08, 0.97)).toColor();
  final roles = <InkRole, Color>{...p.roles, InkRole.paper: paper};
  final range = p.contrastRange;
  for (final r in InkRole.contrastChecked) {
    final before = contrastRatio(p.color(r), p.paper);
    final target = before.clamp(range.min, range.max).toDouble();
    roles[r] = solveForContrast(paper, Oklch.fromColor(p.color(r)), target);
  }
  final line = Oklch.fromColor(p.color(InkRole.paperLine));
  roles[InkRole.paperLine] = solveForContrast(paper, line, 1.45);
  return p.copyWith(roles: roles);
}

/// Curseur rapide « contraste »: ratio visé pour l'encre principale; les
/// autres encres suivent proportionnellement.
VisualProfile adjustContrast(VisualProfile p, double target) {
  final current = contrastRatio(p.ink, p.paper);
  final factor = target / current;
  final roles = <InkRole, Color>{...p.roles};
  for (final r in InkRole.contrastChecked) {
    final c = contrastRatio(p.color(r), p.paper);
    final t = r == InkRole.inkPrimary ? target : (c * factor).clamp(1.5, 21.0);
    roles[r] = solveForContrast(p.paper, Oklch.fromColor(p.color(r)), t);
  }
  return p.copyWith(roles: roles);
}
