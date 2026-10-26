import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'ocr_service.dart';

OcrService createOcrService() => _MlKitOcr();

/// OCR sur l'appareil avec Google ML Kit (iOS et Android).
class _MlKitOcr implements OcrService {
  @override
  bool get available => Platform.isIOS || Platform.isAndroid;

  @override
  Future<String?> recognizePng(Uint8List png) async {
    if (!available) return null;
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/monako_ocr_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(png, flush: true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(file.path));
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
      if (await file.exists()) await file.delete();
    }
  }
}
