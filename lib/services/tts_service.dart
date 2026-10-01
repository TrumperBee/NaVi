import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Singleton TTS engine behind voice guidance.
///
/// [speak] is a no-op whenever voice guidance is disabled (the value is kept
/// in sync by `SettingsService.setVoiceGuidanceEnabled`). Output is debounced
/// so a burst of position updates collapses into a single utterance, and every
/// platform call is fault-tolerant so the app never crashes in tests or on a
/// device without a usable TTS engine.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  bool _voiceGuidanceEnabled = true;
  Timer? _debounceTimer;
  FlutterTts? _tts;
  bool _initialized = false;

  bool get voiceGuidanceEnabled => _voiceGuidanceEnabled;

  void setVoiceGuidance(bool enabled) {
    _voiceGuidanceEnabled = enabled;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      _tts = tts;
      debugPrint('[TTS] flutter_tts initialized');
    } catch (e) {
      debugPrint('[TTS] init failed: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_voiceGuidanceEnabled || text.isEmpty) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () async {
      if (!_voiceGuidanceEnabled) return;
      try {
        final tts = _tts ??= FlutterTts();
        await tts.speak(text);
      } catch (e) {
        debugPrint('[TTS] speak error: $e');
      }
    });
  }

  Future<void> stop() async {
    _debounceTimer?.cancel();
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
  }
}