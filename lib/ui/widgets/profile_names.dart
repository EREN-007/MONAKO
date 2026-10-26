import 'package:flutter/widgets.dart';

import '../../core/profiles/presets.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/roles.dart';
import '../../l10n/app_localizations.dart';

/// Nom affiché d'un profil (les profils prédéfinis sont traduits).
String profileDisplayName(BuildContext context, VisualProfile p) {
  final l = AppLocalizations.of(context);
  return switch (p.id) {
    Presets.standardId => l.presetStandard,
    Presets.a1Id => l.presetA1,
    Presets.a2Id => l.presetA2,
    Presets.bId => l.presetB,
    Presets.cId => l.presetC,
    Presets.dId => l.presetD,
    Presets.eId => l.presetE,
    _ => p.name,
  };
}

String needLabel(BuildContext context, VisionNeed n) {
  final l = AppLocalizations.of(context);
  return switch (n) {
    VisionNeed.a => l.needA,
    VisionNeed.b => l.needB,
    VisionNeed.c => l.needC,
    VisionNeed.d => l.needD,
    VisionNeed.e => l.needE,
  };
}

String profileNeedsLabel(BuildContext context, VisualProfile p) {
  if (p.needs.isEmpty) return AppLocalizations.of(context).needNone;
  final needs = p.needs.toList()..sort((a, b) => a.index.compareTo(b.index));
  return needs.map((n) => needLabel(context, n)).join(' + ');
}

/// Nom d'un rôle, pour les lecteurs d'écran et les infobulles: aucune
/// information n'est portée par la couleur seule.
String roleLabel(BuildContext context, InkRole r) {
  final l = AppLocalizations.of(context);
  return switch (r) {
    InkRole.paper => l.rolePaper,
    InkRole.paperLine => l.rolePaperLine,
    InkRole.inkPrimary => l.roleInkPrimary,
    InkRole.inkSecondary => l.roleInkSecondary,
    InkRole.accent1 => l.roleAccent(1),
    InkRole.accent2 => l.roleAccent(2),
    InkRole.accent3 => l.roleAccent(3),
    InkRole.accent4 => l.roleAccent(4),
    InkRole.highlight1 => l.roleHighlight(1),
    InkRole.highlight2 => l.roleHighlight(2),
    InkRole.highlight3 => l.roleHighlight(3),
    InkRole.highlight4 => l.roleHighlight(4),
    InkRole.heading => l.roleHeading,
  };
}

/// Repère court affiché sur chaque pastille de couleur.
String roleMark(InkRole r) => switch (r) {
      InkRole.inkPrimary => '•',
      InkRole.inkSecondary => '◦',
      InkRole.accent1 => '1',
      InkRole.accent2 => '2',
      InkRole.accent3 => '3',
      InkRole.accent4 => '4',
      InkRole.highlight1 => '1',
      InkRole.highlight2 => '2',
      InkRole.highlight3 => '3',
      InkRole.highlight4 => '4',
      InkRole.heading => 'T',
      _ => '',
    };
