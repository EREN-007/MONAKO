import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Lecture à voix haute et dictée vocale (version 2).
class SpeechService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _speaking = false;
  bool _listening = false;
  bool? _sttReady;

  bool get speaking => _speaking;
  bool get listening => _listening;

  Future<void> speak(String text, {required String languageCode}) async {
    if (text.trim().isEmpty) return;
    await _tts.setLanguage(languageCode == 'fr' ? 'fr-CA' : 'en-CA');
    await _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() {
      _speaking = false;
      notifyListeners();
    });
    _speaking = true;
    notifyListeners();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _speaking = false;
    notifyListeners();
  }

  /// Dicte du texte; [onText] reçoit la transcription au fil de l'eau.
  Future<bool> startDictation({
    required String languageCode,
    required void Function(String text, bool done) onText,
  }) async {
    try {
      _sttReady ??= await _stt.initialize(onStatus: (s) {
        final l = s == 'listening';
        if (l != _listening) {
          _listening = l;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Dictée indisponible: $e');
      _sttReady = false;
    }
    if (_sttReady != true) return false;
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: languageCode == 'fr' ? 'fr_CA' : 'en_CA',
        partialResults: true,
      ),
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
    );
    _listening = true;
    notifyListeners();
    return true;
  }

  Future<void> stopDictation() async {
    await _stt.stop();
    _listening = false;
    notifyListeners();
  }
}
