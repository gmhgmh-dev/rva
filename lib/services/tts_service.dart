import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_assistant_state_machine.dart';

/// Service responsible for speech synthesis using `flutter_tts` in Latvian ("lv-LV").
/// Includes safety fallbacks, queued announcements, and a stream for UI display.
class TtsService {
  final FlutterTts _flutterTts;
  final StreamController<String> _spokenTextController = StreamController<String>.broadcast();
  final List<String> _speechQueue = <String>[];
  bool _isSpeaking = false;
  bool _isInitialized = false;

  TtsService({FlutterTts? flutterTts}) : _flutterTts = flutterTts ?? FlutterTts();

  Stream<String> get spokenTextStream => _spokenTextController.stream;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // Configure Latvian language
      await _flutterTts.setLanguage("lv-LV");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _processQueue();
      });

      _flutterTts.setErrorHandler((dynamic message) {
        debugPrint('TTS Error: $message');
        _isSpeaking = false;
        _processQueue();
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS init error (mock or unsupported platform): $e');
    }
  }

  /// Speaks the given text or enqueues it if already speaking.
  Future<void> speak(String text) async {
    _spokenTextController.add(text);
    _speechQueue.add(text);
    if (!_isSpeaking) {
      _processQueue();
    }
  }

  /// Speaks dynamic street and speed limit announcement:
  /// "Atrodaties uz [street_name]. Atļautais ātrums [max_speed] kilometri stundā."
  Future<void> speakStreetInfo(String? streetName, int maxSpeed) async {
    final text = VoiceAssistantStateMachine.formatStreetAnnouncement(
      streetName: streetName,
      maxSpeed: maxSpeed,
    );
    await speak(text);
  }

  /// Speaks living street zone entry:
  /// "Iebraucāt dzīvojamā zonā. Maksimālais ātrums 20 kilometri stundā."
  Future<void> speakLivingStreetZone() async {
    await speak(VoiceAssistantStateMachine.formatLivingStreetAnnouncement());
  }

  Future<void> _processQueue() async {
    if (_speechQueue.isEmpty) {
      _isSpeaking = false;
      return;
    }

    _isSpeaking = true;
    final text = _speechQueue.removeAt(0);

    try {
      if (!_isInitialized) {
        await init();
      }
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking text: $e');
      _isSpeaking = false;
      _processQueue();
    }
  }

  Future<void> stop() async {
    _speechQueue.clear();
    _isSpeaking = false;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  void dispose() {
    _speechQueue.clear();
    _spokenTextController.close();
  }
}
