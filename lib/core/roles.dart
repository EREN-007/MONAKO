/// Rôles de couleur sémantiques (fiche technique, section 4).
///
/// Aucun trait, texte ni surlignage n'est enregistré avec une couleur fixe:
/// il porte un rôle, et la couleur réelle est calculée à l'affichage à partir
/// du profil visuel actif.
enum InkRole {
  paper('paper'),
  paperLine('paper.line'),
  inkPrimary('ink.primary'),
  inkSecondary('ink.secondary'),
  accent1('ink.accent1'),
  accent2('ink.accent2'),
  accent3('ink.accent3'),
  accent4('ink.accent4'),
  highlight1('highlight.1'),
  highlight2('highlight.2'),
  highlight3('highlight.3'),
  highlight4('highlight.4'),
  heading('heading');

  const InkRole(this.key);

  /// Clé enregistrée dans les fichiers et la base (« ink.accent2 »…).
  final String key;

  static final Map<String, InkRole> _byKey = {
    for (final r in InkRole.values) r.key: r,
  };

  static InkRole? fromKey(String? key) => _byKey[key];

  static InkRole parse(String? key, {InkRole fallback = InkRole.inkPrimary}) =>
      _byKey[key] ?? fallback;

  bool get isHighlight => key.startsWith('highlight.');
  bool get isInk => key.startsWith('ink.') || this == InkRole.heading;

  /// Encres que l'élève peut choisir pour écrire.
  static const List<InkRole> writingInks = [
    inkPrimary,
    inkSecondary,
    accent1,
    accent2,
    accent3,
    accent4,
    heading,
  ];

  static const List<InkRole> highlights = [
    highlight1,
    highlight2,
    highlight3,
    highlight4,
  ];

  /// Rôles dont le contraste sur `paper` est vérifié (section 11).
  static const List<InkRole> contrastChecked = [
    inkPrimary,
    inkSecondary,
    accent1,
    accent2,
    accent3,
    accent4,
    heading,
  ];
}

/// Style du trait: le sens ne doit jamais reposer sur la teinte seule
/// (section 4, règle daltonisme).
enum StrokePattern {
  solid,
  dashed,
  dotted,
  dashDot;

  static StrokePattern parse(String? v) => StrokePattern.values.firstWhere(
        (p) => p.name == v,
        orElse: () => StrokePattern.solid,
      );
}

/// Motif associé par défaut à chaque encre d'accent quand le profil active
/// « styles de trait en plus de la teinte » (profil C).
StrokePattern patternForRole(InkRole role) => switch (role) {
      InkRole.accent2 => StrokePattern.dashed,
      InkRole.accent3 => StrokePattern.dotted,
      InkRole.accent4 => StrokePattern.dashDot,
      _ => StrokePattern.solid,
    };
