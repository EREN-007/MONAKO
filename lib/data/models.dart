import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import '../core/roles.dart';

/// Version du schéma des fichiers de note (section 9), pour migrer plus tard.
const int kSchemaVersion = 1;

/// Taille logique d'une page vierge (ratio A4).
const Size kDefaultPageSize = Size(800, 1131);

DateTime nowUtc() => DateTime.now().toUtc();

DateTime parseTime(Object? v) =>
    v == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : DateTime.parse(v as String).toUtc();

String timeToJson(DateTime t) => t.toUtc().toIso8601String();

double _d(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : (double.tryParse('$v') ?? fallback);

/// Champs communs à toutes les lignes synchronisées.
///
/// - [modifiedAt]: horodatage client, utilisé pour « la dernière
///   modification gagne » (garde côté serveur, voir les migrations).
/// - [deleted]: pierre tombale; une suppression est toujours explicite et
///   se propage, jamais un effacement silencieux.
abstract class SyncRow {
  String get id;
  DateTime get modifiedAt;
  bool get deleted;
  Map<String, dynamic> toRow();
}

class Folder implements SyncRow {
  Folder({
    required this.id,
    this.userId,
    required this.name,
    this.parentId,
    DateTime? modifiedAt,
    this.deleted = false,
  }) : modifiedAt = modifiedAt ?? nowUtc();

  @override
  final String id;
  final String? userId;
  final String name;
  final String? parentId;
  @override
  final DateTime modifiedAt;
  @override
  final bool deleted;

  Folder copyWith({String? name, String? parentId, bool? deleted}) => Folder(
        id: id,
        userId: userId,
        name: name ?? this.name,
        parentId: parentId ?? this.parentId,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, dynamic> toRow() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'parent_id': parentId,
        'modified_at': timeToJson(modifiedAt),
        'deleted': deleted,
      };

  factory Folder.fromRow(Map r) => Folder(
        id: r['id'] as String,
        userId: r['user_id'] as String?,
        name: (r['name'] as String?) ?? '',
        parentId: r['parent_id'] as String?,
        modifiedAt: parseTime(r['modified_at']),
        deleted: r['deleted'] == true,
      );
}

/// Cahier. Un profil peut lui être imposé ([linkedProfileId]).
class Notebook implements SyncRow {
  Notebook({
    required this.id,
    this.userId,
    required this.title,
    this.folderId,
    this.linkedProfileId,
    this.coverRole = 'ink.accent2',
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.deleted = false,
    this.schemaVersion = kSchemaVersion,
  })  : createdAt = createdAt ?? nowUtc(),
        modifiedAt = modifiedAt ?? nowUtc();

  @override
  final String id;

  /// Propriétaire. Null tant que la note n'a jamais été synchronisée.
  final String? userId;
  final String title;
  final String? folderId;
  final String? linkedProfileId;
  final String coverRole;
  final DateTime createdAt;
  @override
  final DateTime modifiedAt;
  @override
  final bool deleted;
  final int schemaVersion;

  Notebook copyWith({
    String? title,
    String? folderId,
    bool clearFolder = false,
    String? linkedProfileId,
    bool clearLinkedProfile = false,
    String? coverRole,
    bool? deleted,
    String? userId,
  }) =>
      Notebook(
        id: id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        linkedProfileId: clearLinkedProfile
            ? null
            : (linkedProfileId ?? this.linkedProfileId),
        coverRole: coverRole ?? this.coverRole,
        createdAt: createdAt,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, dynamic> toRow() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'folder_id': folderId,
        'linked_profile_id': linkedProfileId,
        'cover_role': coverRole,
        'created_at': timeToJson(createdAt),
        'modified_at': timeToJson(modifiedAt),
        'deleted': deleted,
        'schema_version': schemaVersion,
      };

  factory Notebook.fromRow(Map r) => Notebook(
        id: r['id'] as String,
        userId: r['user_id'] as String?,
        title: (r['title'] as String?) ?? '',
        folderId: r['folder_id'] as String?,
        linkedProfileId: r['linked_profile_id'] as String?,
        coverRole: (r['cover_role'] as String?) ?? 'ink.accent2',
        createdAt: parseTime(r['created_at']),
        modifiedAt: parseTime(r['modified_at']),
        deleted: r['deleted'] == true,
        schemaVersion: (r['schema_version'] as num?)?.toInt() ?? kSchemaVersion,
      );
}

/// Gabarit de page: les lignes sont dessinées avec le rôle `paper.line`,
/// jamais une couleur.
enum PageTemplate {
  blank,
  lined,
  grid,
  dotted;

  static PageTemplate parse(String? v) => PageTemplate.values
      .firstWhere((t) => t.name == v, orElse: () => PageTemplate.lined);
}

class NotePage implements SyncRow {
  NotePage({
    required this.id,
    required this.notebookId,
    this.userId,
    this.template = PageTemplate.lined,
    required this.position,
    this.width = 800,
    this.height = 1131,
    this.assetId,
    this.assetPage,
    this.ocrText,
    DateTime? modifiedAt,
    this.deleted = false,
    this.schemaVersion = kSchemaVersion,
  }) : modifiedAt = modifiedAt ?? nowUtc();

  @override
  final String id;
  final String notebookId;
  final String? userId;
  final PageTemplate template;

  /// Ordre dans le cahier (nombre réel pour insérer entre deux pages).
  final double position;
  final double width;
  final double height;

  /// PDF ou image importé affiché sous les annotations.
  final String? assetId;

  /// Numéro de page dans le PDF (1 = première).
  final int? assetPage;

  /// Calque de texte reconnu par OCR (recherche, lecture à voix haute).
  final String? ocrText;
  @override
  final DateTime modifiedAt;
  @override
  final bool deleted;
  final int schemaVersion;

  Size get size => Size(width, height);

  NotePage copyWith({
    PageTemplate? template,
    double? position,
    String? ocrText,
    bool? deleted,
  }) =>
      NotePage(
        id: id,
        notebookId: notebookId,
        userId: userId,
        template: template ?? this.template,
        position: position ?? this.position,
        width: width,
        height: height,
        assetId: assetId,
        assetPage: assetPage,
        ocrText: ocrText ?? this.ocrText,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, dynamic> toRow() => {
        'id': id,
        'notebook_id': notebookId,
        'user_id': userId,
        'template': template.name,
        'position': position,
        'width': width,
        'height': height,
        'asset_id': assetId,
        'asset_page': assetPage,
        'ocr_text': ocrText,
        'modified_at': timeToJson(modifiedAt),
        'deleted': deleted,
        'schema_version': schemaVersion,
      };

  factory NotePage.fromRow(Map r) => NotePage(
        id: r['id'] as String,
        notebookId: r['notebook_id'] as String,
        userId: r['user_id'] as String?,
        template: PageTemplate.parse(r['template'] as String?),
        position: _d(r['position']),
        width: _d(r['width'], 800),
        height: _d(r['height'], 1131),
        assetId: r['asset_id'] as String?,
        assetPage: (r['asset_page'] as num?)?.toInt(),
        ocrText: r['ocr_text'] as String?,
        modifiedAt: parseTime(r['modified_at']),
        deleted: r['deleted'] == true,
        schemaVersion: (r['schema_version'] as num?)?.toInt() ?? kSchemaVersion,
      );
}

/// Élément posé sur une page.
sealed class PageElement implements SyncRow {
  String get pageId;
  String get notebookId;
  Rect get bounds;
  PageElement markDeleted();
}

/// Trait d'encre ou de surligneur. Enregistré avec un rôle, jamais une
/// couleur (section 4):
/// `{"type": "stroke", "role": "ink.accent2", "width": 2.4, "points": [...]}`
class InkStroke implements PageElement {
  InkStroke({
    required this.id,
    required this.notebookId,
    required this.pageId,
    this.userId,
    required this.role,
    required this.width,
    required this.points,
    this.highlight = false,
    this.pattern = StrokePattern.solid,
    this.fixedColor,
    this.recolor = true,
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.deleted = false,
  })  : createdAt = createdAt ?? nowUtc(),
        modifiedAt = modifiedAt ?? nowUtc();

  @override
  final String id;
  @override
  final String notebookId;
  @override
  final String pageId;
  final String? userId;
  final InkRole role;

  /// Épaisseur de base (avant le multiplicateur du profil).
  final double width;

  /// Triplets (x, y, pression). Pression < 0 = inconnue (doigt, souris).
  final Float32List points;
  final bool highlight;
  final StrokePattern pattern;

  /// Couleur libre hors rôles (fixed: true), en hex. Recolorée par le
  /// moteur sauf si [recolor] est faux.
  final String? fixedColor;
  final bool recolor;
  final DateTime createdAt;
  @override
  final DateTime modifiedAt;
  @override
  final bool deleted;

  int get pointCount => points.length ~/ 3;
  Offset pointAt(int i) => Offset(points[i * 3], points[i * 3 + 1]);
  double pressureAt(int i) => points[i * 3 + 2];
  bool get hasPressure => pointCount > 0 && points[2] >= 0;

  Rect? _bounds;
  @override
  Rect get bounds => _bounds ??= _computeBounds();

  Rect _computeBounds() {
    if (pointCount == 0) return Rect.zero;
    var minX = points[0], maxX = points[0], minY = points[1], maxY = points[1];
    for (var i = 1; i < pointCount; i++) {
      final x = points[i * 3], y = points[i * 3 + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(width);
  }

  InkStroke copyWith({
    InkRole? role,
    Float32List? points,
    bool? deleted,
    String? id,
    StrokePattern? pattern,
  }) =>
      InkStroke(
        id: id ?? this.id,
        notebookId: notebookId,
        pageId: pageId,
        userId: userId,
        role: role ?? this.role,
        width: width,
        points: points ?? this.points,
        highlight: highlight,
        pattern: pattern ?? this.pattern,
        fixedColor: role != null ? null : fixedColor,
        recolor: recolor,
        createdAt: id != null ? nowUtc() : createdAt,
        deleted: deleted ?? this.deleted,
      );

  InkStroke translated(Offset delta) {
    final p = Float32List.fromList(points);
    for (var i = 0; i < pointCount; i++) {
      p[i * 3] += delta.dx;
      p[i * 3 + 1] += delta.dy;
    }
    return copyWith(points: p);
  }

  @override
  InkStroke markDeleted() => copyWith(deleted: true);

  String get table => highlight ? 'highlights' : 'strokes';

  /// Format compact binaire recommandé (section 9): Float32 little-endian
  /// encodé en base64.
  static String encodePoints(Float32List pts) =>
      base64Encode(pts.buffer.asUint8List(pts.offsetInBytes, pts.lengthInBytes));

  static Float32List decodePoints(Object? v) {
    if (v is String && v.isNotEmpty) {
      final bytes = base64Decode(v);
      return Float32List.fromList(
          bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4));
    }
    if (v is List) {
      // Format lisible de la fiche: [[x, y, p], ...]
      return Float32List.fromList([
        for (final p in v)
          for (var i = 0; i < 3; i++)
            (p is List && p.length > i) ? _d(p[i], -1) : -1.0,
      ]);
    }
    return Float32List(0);
  }

  @override
  Map<String, dynamic> toRow() => {
        'id': id,
        'notebook_id': notebookId,
        'page_id': pageId,
        'user_id': userId,
        'role': role.key,
        'width': width,
        'points': encodePoints(points),
        if (!highlight) 'pattern': pattern.name,
        if (!highlight) 'fixed_color': fixedColor,
        if (!highlight) 'recolor': recolor,
        if (highlight) 'target_type': 'free',
        'created_at': timeToJson(createdAt),
        'modified_at': timeToJson(modifiedAt),
        'deleted': deleted,
      };

  factory InkStroke.fromRow(Map r, {required bool highlight}) => InkStroke(
        id: r['id'] as String,
        notebookId: r['notebook_id'] as String,
        pageId: r['page_id'] as String,
        userId: r['user_id'] as String?,
        role: InkRole.parse(r['role'] as String?,
            fallback: highlight ? InkRole.highlight1 : InkRole.inkPrimary),
        width: _d(r['width'], 2.4),
        points: decodePoints(r['points']),
        highlight: highlight,
        pattern: StrokePattern.parse(r['pattern'] as String?),
        fixedColor: r['fixed_color'] as String?,
        recolor: r['recolor'] != false,
        createdAt: parseTime(r['created_at']),
        modifiedAt: parseTime(r['modified_at']),
        deleted: r['deleted'] == true,
      );

  /// Représentation lisible identique à l'exemple de la fiche.
  Map<String, dynamic> toSpecJson() => {
        'type': highlight ? 'highlight' : 'stroke',
        'role': role.key,
        'width': width,
        'points': [
          for (var i = 0; i < pointCount; i++)
            [points[i * 3], points[i * 3 + 1], points[i * 3 + 2]],
        ],
        if (fixedColor != null) 'fixed': true,
        if (fixedColor != null) 'color': fixedColor,
      };
}

/// Texte tapé au clavier.
class TextBlock implements PageElement {
  TextBlock({
    required this.id,
    required this.notebookId,
    required this.pageId,
    this.userId,
    required this.x,
    required this.y,
    this.width = 400,
    required this.text,
    this.role = InkRole.inkPrimary,
    this.size = 16,
    this.font = 'system',
    DateTime? modifiedAt,
    this.deleted = false,
  }) : modifiedAt = modifiedAt ?? nowUtc();

  @override
  final String id;
  @override
  final String notebookId;
  @override
  final String pageId;
  final String? userId;
  final double x, y, width;
  final String text;
  final InkRole role;

  /// Taille en points pour un profil de référence (16 pt); multipliée par
  /// le profil à l'affichage.
  final double size;
  final String font;
  @override
  final DateTime modifiedAt;
  @override
  final bool deleted;

  @override
  Rect get bounds {
    final lines = '\n'.allMatches(text).length + 1;
    return Rect.fromLTWH(x, y, width, lines * size * 1.6 + 8);
  }

  TextBlock copyWith({
    double? x,
    double? y,
    double? width,
    String? text,
    InkRole? role,
    double? size,
    bool? deleted,
  }) =>
      TextBlock(
        id: id,
        notebookId: notebookId,
        pageId: pageId,
        userId: userId,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        text: text ?? this.text,
        role: role ?? this.role,
        size: size ?? this.size,
        font: font,
        deleted: deleted ?? this.deleted,
      );

  @override
  TextBlock markDeleted() => copyWith(deleted: true);

  @override
  Map<String, dynamic> toRow() => {
        'id': id,
        'notebook_id': notebookId,
        'page_id': pageId,
        'user_id': userId,
        'x': x,
        'y': y,
        'width': width,
        'text': text,
        'role': role.key,
        'size': size,
        'font': font,
        'modified_at': timeToJson(modifiedAt),
        'deleted': deleted,
      };

  factory TextBlock.fromRow(Map r) => TextBlock(
        id: r['id'] as String,
        notebookId: r['notebook_id'] as String,
        pageId: r['page_id'] as String,
        userId: r['user_id'] as String?,
        x: _d(r['x']),
        y: _d(r['y']),
        width: _d(r['width'], 400),
        text: (r['text'] as String?) ?? '',
        role: InkRole.parse(r['role'] as String?),
        size: _d(r['size'], 16),
        font: (r['font'] as String?) ?? 'system',
        modifiedAt: parseTime(r['modified_at']),
        deleted: r['deleted'] == true,
      );
}

/// Mode de recoloration d'un document importé (section 10).
enum RecolorMode {
  full,
  backgroundOnly,
  off;

  static RecolorMode parse(String? v) => RecolorMode.values
      .firstWhere((m) => m.name == v, orElse: () => RecolorMode.full);
}

enum ImageTreatment {
  intact,
  dimmed,
  recolored;

  static ImageTreatment parse(String? v) => ImageTreatment.values
      .firstWhere((m) => m.name == v, orElse: () => ImageTreatment.intact);
}

/// Réglages du filtre, par document.
class RecolorSettings {
  const RecolorSettings({
    this.mode = RecolorMode.full,
    this.brightnessCap,
    this.images = ImageTreatment.intact,
    this.textContrast,
  });

  final RecolorMode mode;

  /// Plafond de luminosité; null = valeur du profil.
  final double? brightnessCap;

  /// « Ne pas inverser les images » est le réglage par défaut.
  final ImageTreatment images;

  /// Contraste du texte: null = auto, sinon renforcement manuel 0..1.
  final double? textContrast;

  RecolorSettings copyWith({
    RecolorMode? mode,
    double? brightnessCap,
    bool clearBrightnessCap = false,
    ImageTreatment? images,
    double? textContrast,
    bool clearTextContrast = false,
  }) =>
      RecolorSettings(
        mode: mode ?? this.mode,
        brightnessCap:
            clearBrightnessCap ? null : (brightnessCap ?? this.brightnessCap),
        images: images ?? this.images,
        textContrast:
            clearTextContrast ? null : (textContrast ?? this.textContrast),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'brightnessCap': brightnessCap,
        'images': images.name,
        'textContrast': textContrast,
      };

  factory RecolorSettings.fromJson(Map? j) => RecolorSettings(
        mode: RecolorMode.parse(j?['mode'] as String?),
        brightnessCap: (j?['brightnessCap'] as num?)?.toDouble(),
        images: ImageTreatment.parse(j?['images'] as String?),
        textContrast: (j?['textContrast'] as num?)?.toDouble(),
      );

  String get cacheKey =>
      '${mode.name}|${brightnessCap?.toStringAsFixed(2)}|${images.name}|${textContrast?.toStringAsFixed(2)}';
}

enum AssetKind {
  pdf,
  image;

  static AssetKind parse(String? v) =>
      v == 'image' ? AssetKind.image : AssetKind.pdf;
}

/// PDF ou image importé. L'original n'est jamais modifié.
class ImportedAsset implements SyncRow {
  ImportedAsset({
    required this.id,
    required this.notebookId,
    this.userId,
    required this.kind,
    required this.fileName,
    this.storagePath,
    this.pageCount = 1,
    this.filter = const RecolorSettings(),
    DateTime? modifiedAt,
    this.deleted = false,
  }) : modifiedAt = modifiedAt ?? nowUtc();

  @override
  final String id;
  final String notebookId;
  final String? userId;
  final AssetKind kind;
  final String fileName;

  /// Chemin dans le stockage Supabase (bucket `assets`), une fois envoyé.
  final String? storagePath;
  final int pageCount;
  final RecolorSettings filter;
  @override
  final DateTime modifiedAt;
  @override
  final bool deleted;

  ImportedAsset copyWith({
    RecolorSettings? filter,
    String? storagePath,
    String? userId,
    bool? deleted,
  }) =>
      ImportedAsset(
        id: id,
        notebookId: notebookId,
        userId: userId ?? this.userId,
        kind: kind,
        fileName: fileName,
        storagePath: storagePath ?? this.storagePath,
        pageCount: pageCount,
        filter: filter ?? this.filter,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, dynamic> toRow() => {
        'id': id,
        'notebook_id': notebookId,
        'user_id': userId,
        'kind': kind.name,
        'file_name': fileName,
        'storage_path': storagePath,
        'page_count': pageCount,
        'filter': filter.toJson(),
        'modified_at': timeToJson(modifiedAt),
        'deleted': deleted,
      };

  factory ImportedAsset.fromRow(Map r) => ImportedAsset(
        id: r['id'] as String,
        notebookId: r['notebook_id'] as String,
        userId: r['user_id'] as String?,
        kind: AssetKind.parse(r['kind'] as String?),
        fileName: (r['file_name'] as String?) ?? '',
        storagePath: r['storage_path'] as String?,
        pageCount: (r['page_count'] as num?)?.toInt() ?? 1,
        filter: RecolorSettings.fromJson(r['filter'] as Map?),
        modifiedAt: parseTime(r['modified_at']),
        deleted: r['deleted'] == true,
      );
}
