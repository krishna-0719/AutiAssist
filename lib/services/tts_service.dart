import 'package:flutter_tts/flutter_tts.dart';

import '../utils/app_logger.dart';

/// Text-to-Speech service for the child device.
/// Speaks "I want [label]" when a symbol is tapped.
class TtsService {
  TtsService._();

  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  /// Initialize TTS engine with autism-friendly settings.
  static Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5); // Slower, clearer for children
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
    AppLogger.info('TTS initialized', tag: 'TTS');
  }

  /// Speak the given text. Silently fails if TTS unavailable.
  static Future<void> speak(String text) async {
    try {
      if (!_initialized) await init();
      await _tts.speak(text);
    } catch (e) {
      AppLogger.error('TTS speak failed', error: e, tag: 'TTS');
    }
  }

  /// Stop any ongoing speech.
  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Dispose TTS engine.
  static Future<void> dispose() async {
    await _tts.stop();
  }
}
