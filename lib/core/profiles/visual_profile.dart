import 'dart:ui' show Color;

import '../color/hex.dart';
import '../roles.dart';
import 'contrast_targets.dart';

/// Besoins d'affichage (section 2). L'élève choisit un besoin, jamais un
/// diagnostic.
enum VisionNeed {
  a('A'),
  b('B'),
  c('C'),
  d('D'),
  e('E');

  const VisionNeed(this.code);
  final String code;

  static VisionNeed? fromCode(String code) {
    for (final n in values) {
      if (n.code == code.toUpperCase()) return n;
    }
    return null;
  }
}

/// Filtres globaux appliqués sur toute la page (section 5).
class ProfileFilters {
  const ProfileFilters({
    this.warmTint = 0,
    this.pdfBrightnessCap = 1,
    this.glareReduction = 0,
    this.haloReduction = 0,
  });

  /// Teinte chaude (réduction du bleu), 0 à 1.
  final double warmTint;

  /// Plafond de luminosité du fond des PDF et images, 0 à 1.
  final double pdfBrightnessCap;

  /// Atténuation de l'éblouissement des zones très claires, 0 à 1.
  final double glareReduction;

  /// Halo réduit: épaissit légèrement les traits et l'interligne, 0 à 1.
  final double haloReduction;

  ProfileFilters copyWith({
    double? warmTint,
    double? pdfBrightnessCap,
    double? glareReduction,
    double? haloReduction,
  }) =>
      ProfileFilters(
        warmTint: warmTint ?? this.warmTint,
        pdfBrightnessCap: pdfBrightnessCap ?? this.pdfBrightnessCap,
        glareReduction: glareReduction ?? this.glareReduction,
        haloReduction: haloReduction ?? this.haloReduction,
      );

  Map<String, dynamic> toJson() => {
        'warmTint': warmTint,
        'pdfBrightnessCap': pdfBrightnessCap,
        'glareReduction': glareReduction,
        'haloReduction': haloReduction,
      };

  factory ProfileFilters.fromJson(Map<String, dynamic>? j) => ProfileFilters(
        warmTint: _d(j?['warmTint'], 0),
        pdfBrightnessCap: _d(j?['pdfBrightnessCap'], 1),
        glareReduction: _d(j?['glareReduction'], 0),
        haloReduction: _d(j?['haloReduction'], 0),
      );
}

/// Police d'affichage des notes et de l'interface.
enum ProfileFont {
  system('system'),

  /// Police lisible, sans empattement et à grandes ouvertures
  /// (Atkinson Hyperlegible, embarquée).
  legible('legible'),

  /// Police pensée pour la dyslexie (OpenDyslexic, embarquée).
  dyslexic('dyslexic');

  const ProfileFont(this.key);
  final String key;

  String? get family => switch (this) {
        ProfileFont.system => null,
        ProfileFont.legible => 'AtkinsonHyperlegible',
        ProfileFont.dyslexic => 'OpenDyslexic',
      };

  static ProfileFont parse(String? v) => ProfileFont.values.firstWhere(
        (f) => f.key == v,
        orElse: () => ProfileFont.system,
      );
}

class ProfileText {
  const ProfileText({
    this.baseSize = 16,
    this.font = ProfileFont.system,
    this.lineHeight = 1.4,
    this.wordSpacing = 0,
    this.defaultZoom = 1,
  });

  /// Taille de texte de base en points, 14 à 40 (section 6).
  final double baseSize;
  final ProfileFont font;
  final double lineHeight;

  /// Espace supplémentaire entre les mots, en fraction de la taille (0.1 = +10 %).
  final double wordSpacing;

  /// Zoom par défaut de l'éditeur (1.5 = 150 %).
  final double defaultZoom;

  static const double minSize = 14, maxSize = 40, referenceSize = 16;

  /// Multiplicateur appliqué aux blocs de texte enregistrés en taille de
  /// référence (16 pt).
  double get sizeMultiplier => baseSize / referenceSize;

  ProfileText copyWith({
    double? baseSize,
    ProfileFont? font,
    double? lineHeight,
    double? wordSpacing,
    double? defaultZoom,
  }) =>
      ProfileText(
        baseSize: baseSize ?? this.baseSize,
        font: font ?? this.font,
        lineHeight: lineHeight ?? this.lineHeight,
        wordSpacing: wordSpacing ?? this.wordSpacing,
        defaultZoom: defaultZoom ?? this.defaultZoom,
      );

  Map<String, dynamic> toJson() => {
        'baseSize': baseSize,
        'font': font.key,
        'lineHeight': lineHeight,
        'wordSpacing': wordSpacing,
        'defaultZoom': defaultZoom,
      };

  factory ProfileText.fromJson(Map<String, dynamic>? j) => ProfileText(
        baseSize: _d(j?['baseSize'], 16).clamp(minSize, maxSize).toDouble(),
        font: ProfileFont.parse(j?['font'] as String?),
        lineHeight: _d(j?['lineHeight'], 1.4),
        wordSpacing: _d(j?['wordSpacing'], 0),
        defaultZoom: _d(j?['defaultZoom'], 1),
      );
}

class ProfileStroke {
  const ProfileStroke({
    this.widthMultiplier = 1,
    this.rolePatterns = false,
    this.highlightOpacity = 0.45,
  });

  final double widthMultiplier;

  /// Ajoute un motif (pointillé…) par encre d'accent, pour ne jamais porter
  /// le sens par la seule couleur.
  final bool rolePatterns;

  /// Transparence des surlignages: limitée pour ne pas réduire le contraste
  /// du texte (section 6).
  final double highlightOpacity;

  ProfileStroke copyWith({
    double? widthMultiplier,
    bool? rolePatterns,
    double? highlightOpacity,
  }) =>
      ProfileStroke(
        widthMultiplier: widthMultiplier ?? this.widthMultiplier,
        rolePatterns: rolePatterns ?? this.rolePatterns,
        highlightOpacity: highlightOpacity ?? this.highlightOpacity,
      );

  Map<String, dynamic> toJson() => {
        'widthMultiplier': widthMultiplier,
        'rolePatterns': rolePatterns,
        'highlightOpacity': highlightOpacity,
      };

  factory ProfileStroke.fromJson(Map<String, dynamic>? j) => ProfileStroke(
        widthMultiplier: _d(j?['widthMultiplier'], 1),
        rolePatterns: j?['rolePatterns'] == true,
        highlightOpacity: _d(j?['highlightOpacity'], 0.45),
      );
}

/// Profil visuel: une table rôle -> couleur + filtres + tailles + police.
///
/// Correspond à l'entité VisualProfile (section 9). Données sensibles:
/// stockées uniquement dans le compte privé de l'utilisateur.
class VisualProfile {
  VisualProfile({
    required this.id,
    required this.name,
    required this.needs,
    required Map<InkRole, Color> roles,
    this.filters = const ProfileFilters(),
    this.text = const ProfileText(),
    this.stroke = const ProfileStroke(),
    this.simplifiedUi = false,
    this.isPreset = false,
    this.baseId,
    DateTime? modifiedAt,
    this.deleted = false,
  })  : roles = Map.unmodifiable(roles),
        modifiedAt = modifiedAt ?? DateTime.now().toUtc();

  final String id;
  final String name;
  final Set<VisionNeed> needs;
  final Map<InkRole, Color> roles;
  final ProfileFilters filters;
  final ProfileText text;
  final ProfileStroke stroke;

  /// Interface simplifiée (profil D).
  final bool simplifiedUi;
  final bool isPreset;

  /// Profil prédéfini dont celui-ci est dérivé.
  final String? baseId;
  final DateTime modifiedAt;
  final bool deleted;

  Color color(InkRole role) => roles[role]!;
  Color get paper => roles[InkRole.paper]!;
  Color get ink => roles[InkRole.inkPrimary]!;

  ContrastRange get contrastRange => ContrastRange.forNeeds(needs);

  VisualProfile copyWith({
    String? id,
    String? name,
    Set<VisionNeed>? needs,
    Map<InkRole, Color>? roles,
    ProfileFilters? filters,
    ProfileText? text,
    ProfileStroke? stroke,
    bool? simplifiedUi,
    bool? isPreset,
    String? baseId,
    DateTime? modifiedAt,
    bool? deleted,
  }) =>
      VisualProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        needs: needs ?? this.needs,
        roles: roles ?? this.roles,
        filters: filters ?? this.filters,
        text: text ?? this.text,
        stroke: stroke ?? this.stroke,
        simplifiedUi: simplifiedUi ?? this.simplifiedUi,
        isPreset: isPreset ?? this.isPreset,
        baseId: baseId ?? this.baseId,
        modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
        deleted: deleted ?? this.deleted,
      );

  VisualProfile withRole(InkRole role, Color color) =>
      copyWith(roles: {...roles, role: color});

  /// Format d'échange, identique à l'exemple de la section 9.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'needs': needs.map((n) => n.code).toList()..sort(),
        'roles': {
          for (final e in roles.entries) e.key.key: colorToHex(e.value),
        },
        'filters': filters.toJson(),
        'text': text.toJson(),
        'stroke': stroke.toJson(),
        'simplifiedUi': simplifiedUi,
        if (baseId != null) 'baseId': baseId,
      };

  /// Lit un profil. Chaque rôle manquant prend la valeur du profil de base
  /// [base] (règle de données, section 9).
  factory VisualProfile.fromJson(
    Map<String, dynamic> j, {
    required VisualProfile base,
    DateTime? modifiedAt,
    bool deleted = false,
  }) {
    final rawRoles = (j['roles'] as Map?)?.cast<String, dynamic>() ?? {};
    final roles = <InkRole, Color>{...base.roles};
    rawRoles.forEach((k, v) {
      final role = InkRole.fromKey(k);
      if (role != null && v is String) {
        try {
          roles[role] = colorFromHex(v);
        } on FormatException {
          // valeur illisible: on garde celle du profil de base
        }
      }
    });
    final needs = ((j['needs'] as List?) ?? const [])
        .map((e) => VisionNeed.fromCode(e.toString()))
        .whereType<VisionNeed>()
        .toSet();
    return VisualProfile(
      id: j['id'] as String,
      name: (j['name'] as String?) ?? '',
      needs: needs,
      roles: roles,
      filters: ProfileFilters.fromJson(
          (j['filters'] as Map?)?.cast<String, dynamic>()),
      text: ProfileText.fromJson((j['text'] as Map?)?.cast<String, dynamic>()),
      stroke: ProfileStroke.fromJson(
          (j['stroke'] as Map?)?.cast<String, dynamic>()),
      simplifiedUi: j['simplifiedUi'] == true,
      baseId: j['baseId'] as String?,
      modifiedAt: modifiedAt,
      deleted: deleted,
    );
  }
}

double _d(Object? v, double fallback) =>
    v is num ? v.toDouble() : (double.tryParse('$v') ?? fallback);
