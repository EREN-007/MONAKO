import 'dart:typed_data';

import 'ocr_stub.dart' if (dart.library.io) 'ocr_mlkit.dart' as impl;

/// Reconnaissance de texte sur l'appareil (section 10, version 2).
///
/// Le texte reconnu forme un calque recherchable, lisible à voix haute et
/// affichable en vrai texte recoloré. Rien n'est envoyé à un serveur.
abstract class OcrService {
  /// Vrai si la plateforme offre l'OCR local (iOS / Android).
  bool get available;

  /// Reconnaît le texte d'une image PNG. Retourne null si l'OCR échoue
  /// (écriture illisible): l'élève garde alors l'image filtrée seulement.
  Future<String?> recognizePng(Uint8List png);

  factory OcrService() => impl.createOcrService();
}
