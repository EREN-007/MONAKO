import 'dart:typed_data';

import 'ocr_service.dart';

OcrService createOcrService() => _UnavailableOcr();

class _UnavailableOcr implements OcrService {
  @override
  bool get available => false;

  @override
  Future<String?> recognizePng(Uint8List png) async => null;
}
