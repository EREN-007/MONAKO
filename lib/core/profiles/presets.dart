import 'dart:ui' show Color;

import '../color/hex.dart';
import '../roles.dart';
import 'visual_profile.dart';

/// Profils prédéfinis (section 6). Les encres d'accent, titres et
/// surlignages ont été calculés par `tool/generate_presets.dart` pour
/// atteindre la cible de contraste de chaque profil; le test
/// `test/contrast_test.dart` le vérifie à chaque version.
///
/// Ce sont des hypothèses de confort, pas des normes médicales.
class Presets {
  Presets._();

  static const standardId = 'preset_standard';
  static const a1Id = 'preset_a1';
  static const a2Id = 'preset_a2';
  static const bId = 'preset_b';
  static const cId = 'preset_c';
  static const dId = 'preset_d';
  static const eId = 'preset_e';

  static Map<InkRole, Color> _roles(Map<String, String> hex) => {
        for (final e in hex.entries) InkRole.parse(e.key): colorFromHex(e.value),
      };

  /// Palette standard noir sur blanc: profil de base (valeurs par défaut des
  /// rôles manquants) et palette de l'export « normal ».
  static final VisualProfile standard = VisualProfile(
    id: standardId,
    name: 'Standard',
    needs: const {},
    isPreset: true,
    roles: _roles(const {
      'paper': '#FFFFFF',
      'paper.line': '#C9CED6',
      'ink.primary': '#000000',
      'ink.secondary': '#4A4A4A',
      'ink.accent1': '#C62828',
      'ink.accent2': '#1565C0',
      'ink.accent3': '#2E7D32',
      'ink.accent4': '#6A1B9A',
      'highlight.1': '#FFEB3B',
      'highlight.2': '#A5D6A7',
      'highlight.3': '#F8BBD0',
      'highlight.4': '#90CAF9',
      'heading': '#0D2A4A',
    }),
    stroke: const ProfileStroke(highlightOpacity: 0.5),
  );

  /// A1. Lumière, sombre (cas du fondateur).
  static final VisualProfile a1 = VisualProfile(
    id: a1Id,
    name: 'Lumière, sombre',
    needs: const {VisionNeed.a},
    isPreset: true,
    roles: _roles(const {
      'paper': '#26272B',
      'paper.line': '#404043',
      'ink.primary': '#D9CFAF',
      'ink.secondary': '#BCB7A4',
      'ink.accent1': '#FEAB9E',
      'ink.accent2': '#9FC1FF',
      'ink.accent3': '#94CE95',
      'ink.accent4': '#D2B3F8',
      'highlight.1': '#534900',
      'highlight.2': '#225225',
      'highlight.3': '#6F3552',
      'highlight.4': '#054E74',
      'heading': '#E4C584',
    }),
    filters: const ProfileFilters(warmTint: 0.3, pdfBrightnessCap: 0.7),
    text: const ProfileText(baseSize: 18, lineHeight: 1.5),
    stroke: const ProfileStroke(highlightOpacity: 0.55),
  );

  /// A2. Lumière, sépia doux.
  static final VisualProfile a2 = VisualProfile(
    id: a2Id,
    name: 'Lumière, sépia doux',
    needs: const {VisionNeed.a},
    isPreset: true,
    roles: _roles(const {
      'paper': '#E8DCC0',
      'paper.line': '#BEB8AB',
      'ink.primary': '#3A3226',
      'ink.secondary': '#47423B',
      'ink.accent1': '#731E17',
      'ink.accent2': '#183A7C',
      'ink.accent3': '#00480E',
      'ink.accent4': '#502B72',
      'highlight.1': '#EBDB7A',
      'highlight.2': '#A6EEA8',
      'highlight.3': '#FFC6E0',
      'highlight.4': '#B4E0FF',
      'heading': '#15365D',
    }),
    filters: const ProfileFilters(warmTint: 0.2, pdfBrightnessCap: 0.9),
    text: const ProfileText(baseSize: 17, lineHeight: 1.5),
  );

  /// B. Faible contraste.
  static final VisualProfile b = VisualProfile(
    id: bId,
    name: 'Faible contraste',
    needs: const {VisionNeed.b},
    isPreset: true,
    roles: _roles(const {
      'paper': '#101010',
      'paper.line': '#303030',
      'ink.primary': '#FFF3B0',
      'ink.secondary': '#DAD3AD',
      'ink.accent1': '#FFCEC6',
      'ink.accent2': '#C6DAFF',
      'ink.accent3': '#A7E9A9',
      'ink.accent4': '#E5D1FF',
      'highlight.1': '#473E00',
      'highlight.2': '#16471A',
      'highlight.3': '#652C4A',
      'highlight.4': '#004265',
      'heading': '#F9E496',
    }),
    filters: const ProfileFilters(pdfBrightnessCap: 0.8),
    text: const ProfileText(baseSize: 18.4, lineHeight: 1.5),
    stroke: const ProfileStroke(widthMultiplier: 1.3, highlightOpacity: 0.6),
  );

  /// C. Couleurs (daltonisme): accents Okabe-Ito éclaircis à 7:1 minimum et
  /// styles de trait en plus de la teinte.
  static final VisualProfile c = VisualProfile(
    id: cId,
    name: 'Couleurs',
    needs: const {VisionNeed.c},
    isPreset: true,
    roles: _roles(const {
      'paper': '#1B1B1F',
      'paper.line': '#373739',
      'ink.primary': '#EDEDED',
      'ink.secondary': '#BCBCBC',
      'ink.accent1': '#FF9F6D',
      'ink.accent2': '#63C0F6',
      'ink.accent3': '#4FCB9E',
      'ink.accent4': '#F29CCB',
      'highlight.1': '#766B25',
      'highlight.2': '#477849',
      'highlight.3': '#915371',
      'highlight.4': '#327099',
      'heading': '#FEC572',
    }),
    filters: const ProfileFilters(pdfBrightnessCap: 0.85),
    stroke: const ProfileStroke(rolePatterns: true, highlightOpacity: 0.55),
  );

  /// D. Vision réduite.
  static final VisualProfile d = VisualProfile(
    id: dId,
    name: 'Vision réduite',
    needs: const {VisionNeed.d},
    isPreset: true,
    simplifiedUi: true,
    roles: _roles(const {
      'paper': '#0F1720',
      'paper.line': '#30353A',
      'ink.primary': '#FFE98A',
      'ink.secondary': '#D5C994',
      'ink.accent1': '#FFBFB5',
      'ink.accent2': '#B5D0FF',
      'ink.accent3': '#9DDE9E',
      'ink.accent4': '#DEC3FF',
      'highlight.1': '#504600',
      'highlight.2': '#1E4F22',
      'highlight.3': '#6E3451',
      'highlight.4': '#004A70',
      'heading': '#FFD67D',
    }),
    filters: const ProfileFilters(pdfBrightnessCap: 0.8),
    text: const ProfileText(baseSize: 22.4, lineHeight: 1.5, defaultZoom: 1.5),
    stroke: const ProfileStroke(widthMultiplier: 1.2, highlightOpacity: 0.6),
  );

  /// E. Flou et distorsion.
  static final VisualProfile e = VisualProfile(
    id: eId,
    name: 'Flou et distorsion',
    needs: const {VisionNeed.e},
    isPreset: true,
    roles: _roles(const {
      'paper': '#F3EEDD',
      'paper.line': '#CAC7BF',
      'ink.primary': '#3B3B3B',
      'ink.secondary': '#4A4A4A',
      'ink.accent1': '#81231B',
      'ink.accent2': '#1C418B',
      'ink.accent3': '#005111',
      'ink.accent4': '#593180',
      'highlight.1': '#EBDB7A',
      'highlight.2': '#A6EEA8',
      'highlight.3': '#FFC6E0',
      'highlight.4': '#B4E0FF',
      'heading': '#103C6F',
    }),
    filters: const ProfileFilters(haloReduction: 0.5, pdfBrightnessCap: 0.92),
    text: const ProfileText(lineHeight: 1.6, wordSpacing: 0.1),
    stroke: const ProfileStroke(widthMultiplier: 1.25),
  );

  /// Les 6 profils de besoin, dans l'ordre d'affichage.
  static final List<VisualProfile> needProfiles = [a1, a2, b, c, d, e];

  static final List<VisualProfile> all = [standard, ...needProfiles];

  static VisualProfile? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
